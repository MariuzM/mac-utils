import AppKit
import Darwin
import Foundation
import SwiftUI

enum ProcessSortKey: String, CaseIterable, Identifiable, Hashable {
    case memory = "Memory"
    case cpu = "CPU"
    case name = "Name"

    var id: String { rawValue }
}

struct TerminationResult: Sendable {
    let requested: Int
    let refused: Int
    let stillRunning: [String]
}

enum ProcessTerminator {
    static func matching(_ expected: ProcessSample, in current: [ProcessSample]) -> ProcessSample? {
        current.first {
            $0.pid == expected.pid && $0.uid == expected.uid && $0.startDate == expected.startDate
                && $0.executablePath == expected.executablePath && !$0.isProtected
                && !expected.isProtected && expected.startDate != nil && !expected.executablePath.isEmpty
        }
    }

    static func terminate(_ expected: [ProcessSample], force: Bool) async -> TerminationResult {
        let current = await Task.detached(priority: .userInitiated) { ProcessCatalog.snapshot() }.value
        let allowed = expected.compactMap { matching($0, in: current) }
        let apps = NSWorkspace.shared.runningApplications
        var refused = expected.count - allowed.count
        for sample in allowed {
            let result: Bool
            if let app = apps.first(where: { $0.processIdentifier == sample.pid }) {
                result = force ? app.forceTerminate() : app.terminate()
            } else {
                result = kill(sample.pid, force ? SIGKILL : SIGTERM) == 0
            }
            if !result { refused += 1 }
        }
        try? await Task.sleep(for: .milliseconds(600))
        let after = await Task.detached(priority: .utility) { ProcessCatalog.snapshot() }.value
        let remaining = allowed.filter { matching($0, in: after) != nil }
        return TerminationResult(
            requested: expected.count,
            refused: min(expected.count, max(refused, expected.count - allowed.count + remaining.count)),
            stillRunning: remaining.map(\.name))
    }
}

@MainActor
final class PerformanceViewModel: ObservableObject {
    @Published private(set) var samples: [ProcessSample] = []
    @Published private(set) var suggestions: [ProcessSuggestion] = []
    @Published private(set) var loaded = false
    @Published var search = ""
    @Published var sortKey: ProcessSortKey = .memory
    @Published var showBackgroundOnly = false
    @Published var lastResult: TerminationResult?
    @Published var showResult = false
    @Published var pendingSuggestion: ProcessSuggestion?
    @Published var showQuitConfirm = false

    private var previousCPU: [pid_t: UInt64] = [:]
    private var lastSampledAt: Date?
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var generation = UUID()
    private var pendingSamples: [ProcessSample] = []
    @Published private(set) var isTerminating = false
    private var iconCache: [URL: NSImage] = [:]

    var totalReclaimable: UInt64 {
        let pids = Set(suggestions.flatMap(\.pids))
        return samples.filter { pids.contains($0.pid) }.reduce(0) { $0 + $1.residentBytes }
    }

    var visibleProcesses: [ProcessSample] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = samples.filter { sample in
            if showBackgroundOnly && sample.role == .app { return false }
            guard !query.isEmpty else { return true }
            return sample.name.lowercased().contains(query)
                || (sample.bundleID?.lowercased().contains(query) ?? false)
                || sample.executablePath.lowercased().contains(query)
        }
        switch sortKey {
        case .memory:
            return filtered.sorted { $0.residentBytes > $1.residentBytes }
        case .cpu:
            return filtered.sorted { $0.cpuPercent > $1.cpuPercent }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func start() {
        refresh()
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        generation = UUID()
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        guard refreshTask == nil else { return }
        let previous = previousCPU
        let elapsed = lastSampledAt.map { Date().timeIntervalSince($0) } ?? 0
        let token = UUID()
        generation = token
        refreshTask = Task {
            defer { if generation == token { refreshTask = nil } }
            let raw = await Task.detached(priority: .utility) {
                ProcessCatalog.snapshot()
            }.value
            guard !Task.isCancelled, generation == token else { return }
            let withCPU = ProcessCatalog.applyCPU(to: raw, previous: previous, elapsed: elapsed)
            previousCPU = Dictionary(
                withCPU.map { ($0.pid, $0.cpuNanos) }, uniquingKeysWith: { first, _ in first })
            lastSampledAt = Date()
            samples = withCPU
            suggestions = ProcessCatalog.suggestions(for: withCPU)
            loaded = true
        }
    }

    func confirm(_ suggestion: ProcessSuggestion) {
        pendingSamples = samples.filter { suggestion.pids.contains($0.pid) }
        pendingSuggestion = suggestion
        showQuitConfirm = true
    }

    func apply(_ suggestion: ProcessSuggestion, force: Bool) {
        guard pendingSuggestion?.id == suggestion.id else { return }
        terminate(pendingSamples, force: force)
        pendingSamples = []
        pendingSuggestion = nil
    }

    func quit(sample: ProcessSample, force: Bool) {
        guard !sample.isProtected else { return }
        terminate([sample], force: force)
    }

    private func terminate(_ selected: [ProcessSample], force: Bool) {
        guard !isTerminating, !selected.isEmpty else { return }
        isTerminating = true
        Task {
            lastResult = await ProcessTerminator.terminate(selected, force: force)
            isTerminating = false
            showResult = true
            refresh()
        }
    }

    func icon(for sample: ProcessSample) -> NSImage? {
        guard let url = sample.bundleURL else { return nil }
        if let cached = iconCache[url] { return cached }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        iconCache[url] = image
        return image
    }
}
