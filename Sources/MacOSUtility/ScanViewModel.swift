import Foundation
import SwiftUI
import AppKit

enum FullDiskAccess {
    static func granted() -> Bool {
        let probe = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
        guard let h = try? FileHandle(forReadingFrom: probe) else { return false }
        defer { try? h.close() }
        return (try? h.read(upToCount: 1)) != nil
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var volumes: [VolumeResult] = []
    @Published var isScanning = false
    @Published var phase = ""
    @Published var fraction: Double = 0
    @Published var hasScanned = false
    @Published var fullDiskAccess = FullDiskAccess.granted()

    @Published var isBackingUp = false
    @Published var backupPhase = ""
    @Published var backupFraction: Double = 0
    @Published var lastBackup: BackupSummary?
    @Published var showBackupResult = false

    @Published var isDeleting = false
    @Published var deletePhase = ""
    @Published var deleteFraction: Double = 0
    @Published var deleteIndeterminate = false
    @Published var lastDelete: DeleteSummary?
    @Published var showDeleteResult = false
    @Published var showDeleteConfirm = false
    @Published private(set) var pendingItems: [ScanItem] = []
    @Published var lastAdmin: AdminDeleteResult?
    @Published var showAdminResult = false

    @Published var consoleLines: [String] = []
    @Published var showConsole = false

    @Published var selected: Set<UUID> = []

    func refreshAccess() {
        fullDiskAccess = FullDiskAccess.granted()
    }

    private let engine = ScanEngine()
    private let backupManager = BackupManager()
    private let deleteManager = DeleteManager()
    private let adminDeleter = AdminDeleter()
    private var task: Task<Void, Never>?
    private var backupTask: Task<Void, Never>?
    private var deleteTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var lastActivity = Date()
    private var lastWarn = Date()

    func appendConsole(_ line: String) {
        consoleLines.append(line)
        if consoleLines.count > 500 {
            consoleLines.removeFirst(consoleLines.count - 500)
        }
        lastActivity = Date()
    }

    func clearConsole() {
        consoleLines = []
    }

    private func startWatchdog(_ context: @escaping () -> String) {
        lastActivity = Date()
        lastWarn = Date()
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self else { return }
                let idle = Date().timeIntervalSince(self.lastActivity)
                let sinceWarn = Date().timeIntervalSince(self.lastWarn)
                if idle > 20, sinceWarn > 20 {
                    self.lastWarn = Date()
                    self.appendConsole("… still working — no output for \(Int(idle))s. \(context())")
                }
            }
        }
    }

    private func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    var isBusy: Bool { isScanning || isBackingUp || isDeleting }

    var pendingCount: Int { pendingItems.count }
    var pendingBytes: Int64 { pendingItems.reduce(0) { $0 + $1.size } }
    var pendingReviewCount: Int {
        volumes.flatMap { $0.categories }
            .filter { $0.safety == .review }
            .flatMap(\.items)
            .filter { item in pendingItems.contains { $0.id == item.id } }
            .count
    }

    var totalReclaimable: Int64 {
        volumes.reduce(0) { $0 + $1.totalSize }
    }

    var totalItems: Int {
        volumes.reduce(0) { $0 + $1.itemCount }
    }

    var allItems: [ScanItem] {
        volumes.flatMap { $0.categories.flatMap(\.items) }
    }

    var selectedItems: [ScanItem] {
        volumes.flatMap { $0.categories }
            .filter { selected.contains($0.id) }
            .flatMap(\.items)
    }

    func isSelected(_ c: CategoryResult) -> Bool { selected.contains(c.id) }

    func setSelected(_ c: CategoryResult, _ on: Bool) {
        if on { selected.insert(c.id) } else { selected.remove(c.id) }
    }

    func selectAll(_ cats: [CategoryResult]) {
        for c in cats { selected.insert(c.id) }
    }

    func deselectAll(_ cats: [CategoryResult]) {
        for c in cats { selected.remove(c.id) }
    }

    func startScan() {
        guard !isScanning else { return }
        refreshAccess()
        isScanning = true
        hasScanned = false
        volumes = []
        phase = "Starting…"
        fraction = 0

        task = Task {
            let result = await engine.scan { p in
                Task { @MainActor in
                    self.phase = p.phase
                    self.fraction = p.fraction
                }
            }
            self.volumes = result
            self.selected = Set(result.flatMap { $0.categories.map(\.id) })
            self.isScanning = false
            self.hasScanned = true
            self.phase = ""
            self.fraction = 1
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isScanning = false
    }

    func backupAll() {
        startBackup(items: allItems)
    }

    func backup(items: [ScanItem]) {
        startBackup(items: items)
    }

    private func startBackup(items: [ScanItem]) {
        guard !isBackingUp, !isScanning, !items.isEmpty else { return }
        isBackingUp = true
        backupFraction = 0
        backupPhase = "Starting…"

        backupTask = Task {
            let summary = await backupManager.run(items: items) { frac, phase in
                Task { @MainActor in
                    self.backupFraction = frac
                    self.backupPhase = phase
                }
            }
            self.lastBackup = summary
            self.isBackingUp = false
            self.backupPhase = ""
            self.showBackupResult = true
            NSWorkspace.shared.activateFileViewerSelecting([summary.destination])
        }
    }

    func cancelBackup() {
        backupTask?.cancel()
        backupTask = nil
        isBackingUp = false
    }

    func requestDeleteAll() {
        requestDelete(items: allItems)
    }

    func requestDelete(items: [ScanItem]) {
        guard !items.isEmpty, !isBusy else { return }
        pendingItems = items
        showDeleteConfirm = true
    }

    func performDelete(mode: DeleteMode) {
        let items = pendingItems
        pendingItems = []
        guard !items.isEmpty else { return }
        isDeleting = true
        deleteIndeterminate = false
        deleteFraction = 0
        deletePhase = "Starting…"

        deleteTask = Task {
            let summary = await deleteManager.run(items: items, mode: mode) { frac, phase in
                Task { @MainActor in
                    self.deleteFraction = frac
                    self.deletePhase = phase
                }
            }
            self.lastDelete = summary
            self.isDeleting = false
            self.deletePhase = ""
            self.showDeleteResult = true
            self.startScan()
        }
    }

    func cancelDelete() {
        deletePhase = "Cancelling…"
        appendConsole("⏹ Cancel requested — stopping current operation…")
        adminDeleter.cancel()
        deleteTask?.cancel()
        deleteTask = nil
        stopWatchdog()
        isDeleting = false
        deleteIndeterminate = false
    }

    var failedPaths: [String] { lastDelete?.failures ?? [] }

    func performAdminDelete() {
        let paths = pendingItems.map { $0.url.path }
        pendingItems = []
        runAdminDelete(paths: paths)
    }

    func retryFailedAsAdmin() {
        runAdminDelete(paths: failedPaths)
    }

    private func runAdminDelete(paths: [String]) {
        guard !paths.isEmpty, !isBusy else { return }
        isDeleting = true
        deleteIndeterminate = true
        deleteFraction = 0
        deletePhase = "Starting…"
        showConsole = true
        appendConsole("──────── Administrator cleanup ────────")
        startWatchdog { [weak self] in self?.deletePhase ?? "" }

        deleteTask = Task {
            let result = await adminDeleter.run(paths: paths) { line in
                Task { @MainActor in self.appendConsole(line) }
            } phase: { p in
                Task { @MainActor in
                    self.deletePhase = p
                    self.lastActivity = Date()
                }
            }
            self.stopWatchdog()
            self.appendConsole("──────── Done: removed \(result.removed), failed \(result.failed.count), needs Full Disk Access \(result.needsFullDiskAccess.count) ────────")
            self.lastAdmin = result
            self.isDeleting = false
            self.deleteIndeterminate = false
            self.deletePhase = ""
            self.showAdminResult = true
            if !result.cancelled {
                self.startScan()
            }
        }
    }
}
