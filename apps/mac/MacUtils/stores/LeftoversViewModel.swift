import AppKit
import Darwin
import Foundation
import SwiftUI

@MainActor
final class LeftoversViewModel: ObservableObject {
    @Published private(set) var groups: [LeftoverGroup] = []
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var phase = ""
    @Published var scanIssues: [FileIssue] = []
    @Published var omittedIssueCount = 0
    @Published var selected: Set<String> = []
    @Published var expanded: Set<String> = []
    @Published var showRemoveConfirm = false
    @Published var lastSummary: DeleteSummary?
    @Published var showSummary = false
    @Published var lastAdmin: AdminDeleteResult?
    @Published var showAdminResult = false
    @Published var pendingAdminPaths: [String] = []
    @Published var showAdminPrompt = false

    private let scanner = LeftoverScanner()
    private let deleter = DeleteManager()
    private let adminDeleter = AdminDeleter()
    private var scanTask: Task<Void, Never>?

    var allItems: [LeftoverItem] { groups.flatMap(\.items) }

    var selectedItems: [LeftoverItem] {
        allItems.filter { selected.contains($0.id) }
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var confirmedCount: Int {
        allItems.filter { $0.confidence == .confirmed }.count
    }

    var reviewCount: Int {
        allItems.filter { $0.confidence == .review }.count
    }

    var selectedNeedsAdmin: Bool {
        selectedItems.contains(where: \.needsAdmin)
    }

    var selectedReviewCount: Int {
        selectedItems.filter { $0.confidence == .review }.count
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        phase = "Starting…"
        scanIssues = []
        omittedIssueCount = 0
        scanTask?.cancel()
        scanTask = Task {
            let found = await scanner.scan { message in
                Task { @MainActor in self.phase = message }
            }
            guard !Task.isCancelled else {
                isScanning = false
                phase = "Scan cancelled"
                return
            }
            groups = found
            scanIssues = await scanner.scanIssues
            omittedIssueCount = await scanner.omittedIssueCount
            expanded = Set(found.filter { $0.confidence == .confirmed }.map(\.id))
            selected = Set(found.flatMap(\.items).filter { $0.confidence == .confirmed }.map(\.id))
            hasScanned = true
            isScanning = false
            phase = ""
        }
    }

    func toggle(_ item: LeftoverItem) {
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
    }

    func toggle(group: LeftoverGroup) {
        let ids = Set(group.items.map(\.id))
        if ids.isSubset(of: selected) {
            selected.subtract(ids)
        } else {
            selected.formUnion(ids)
        }
    }

    func isFullySelected(_ group: LeftoverGroup) -> Bool {
        let ids = Set(group.items.map(\.id))
        return !ids.isEmpty && ids.isSubset(of: selected)
    }

    func toggleExpanded(_ group: LeftoverGroup) {
        if expanded.contains(group.id) {
            expanded.remove(group.id)
        } else {
            expanded.insert(group.id)
        }
    }

    func selectConfirmedOnly() {
        selected = Set(allItems.filter { $0.confidence == .confirmed }.map(\.id))
    }

    func selectAll() {
        selected = Set(allItems.map(\.id))
    }

    func clearSelection() {
        selected.removeAll()
    }

    func removeSelected(mode: DeleteMode) {
        guard !isScanning else { return }
        let chosen = selectedItems
        let trashable = chosen.map(\.scanItem)

        guard !trashable.isEmpty else { return }

        isScanning = true
        Task {
            let summary = await deleter.run(items: trashable, mode: mode) { _, message in
                Task { @MainActor in self.phase = message }
            }
            lastSummary = summary
            pendingAdminPaths = summary.retryablePaths
            showSummary = true
            isScanning = false
            phase = ""
            pruneRemovedItems()
        }
    }

    func removePendingAsAdmin() {
        let paths = pendingAdminPaths
        guard !paths.isEmpty, !isScanning else { return }
        isScanning = true
        Task {
            let result = await adminDeleter.run(paths: paths) { _ in
            } phase: { message in
                Task { @MainActor in self.phase = message }
            }
            lastAdmin = result
            pendingAdminPaths = result.accessDeniedPaths
            showAdminResult = true
            isScanning = false
            phase = ""
            pruneRemovedItems()
        }
    }

    private func pruneRemovedItems() {
        groups = groups.compactMap { group in
            var updated = group
            updated.items.removeAll { item in
                var info = stat()
                return lstat(item.url.path, &info) != 0 && errno == ENOENT
            }
            return updated.items.isEmpty ? nil : updated
        }
        selected.formIntersection(Set(allItems.map(\.id)))
    }

    func reveal(_ item: LeftoverItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}
