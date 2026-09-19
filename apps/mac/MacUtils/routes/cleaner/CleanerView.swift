import AppKit
import FolderKit
import SwiftUI

struct CleanerView: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(vm: vm)
            Divider()
            FullDiskAccessBanner(vm: vm)
            ScanIssuesView(issues: vm.scanIssues, omittedCount: vm.omittedIssueCount)
            Divider()
            content
            if vm.showConsole {
                Divider()
                ConsolePanel(vm: vm)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .onAppear { vm.refreshAccess() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vm.refreshAccess()
        }
        .alert("Backup finished", isPresented: $vm.showBackupResult, presenting: vm.lastBackup) { summary in
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([summary.destination])
            }
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text(backupMessage(summary))
        }
        .confirmationDialog(
            "Delete \(vm.pendingCount) items (\(ByteFormat.string(vm.pendingBytes)))?",
            isPresented: $vm.showDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Move to Trash") { vm.performDelete(mode: .trash) }
            Button("Delete as Administrator…") { vm.performAdminDelete() }
            Button("Delete Permanently", role: .destructive) { vm.performDelete(mode: .permanent) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Move to Trash is recoverable. Some items may require additional permission.\n"
                    + "Delete as Administrator (asks for your password) deletes permanently without using the Trash. It does not bypass macOS privacy or system protection."
                    + (vm.pendingReviewCount > 0
                        ? "\n\n\(vm.pendingReviewCount) of these are flagged “Review first.”" : ""))
        }
        .alert(
            vm.lastDelete?.mode == .trash ? "Moved to Trash" : "Deleted", isPresented: $vm.showDeleteResult,
            presenting: vm.lastDelete
        ) { summary in
            if !summary.retryablePaths.isEmpty {
                Button("Retry \(summary.retryablePaths.count) as administrator…", role: .destructive) {
                    vm.retryFailedAsAdmin()
                }
            }
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text(deleteMessage(summary))
        }
        .alert("Cleanup finished", isPresented: $vm.showAdminResult, presenting: vm.lastAdmin) { result in
            if !result.accessDeniedPaths.isEmpty {
                Button("Open Full Disk Access…") { FullDiskAccess.openSettings() }
            }
            Button("OK", role: .cancel) {}
        } message: { result in
            Text(adminMessage(result))
        }
    }

    private func backupMessage(_ s: BackupSummary) -> String {
        if let setupError = s.setupError { return setupError }
        var parts = ["\(s.copied) items (\(ByteFormat.string(s.bytes))) copied to\n\(s.destination.path)"]
        if s.cancelled { parts.append("Backup cancelled before all items were copied.") }
        if s.failed > 0 {
            let detail = s.failures.prefix(3).map { "\($0.path) — \($0.reason)" }.joined(separator: "\n")
            parts.append("\(s.failed) items could not be copied:\n\(detail)")
        }
        return parts.joined(separator: "\n\n")
    }

    private func deleteMessage(_ s: DeleteSummary) -> String {
        var parts = ["\(s.deleted) items (\(ByteFormat.string(s.bytes))) removed."]
        if s.mode == .trash { parts.append("Empty the Trash to reclaim space.") }
        if s.cancelled { parts.append("Cleanup cancelled before all items were processed.") }
        if !s.issues.isEmpty { parts.append(s.issues.prefix(5).map(\.description).joined(separator: "\n")) }
        if !s.retryablePaths.isEmpty {
            parts.append(
                "Administrator retry deletes permanently, without using the Trash. It cannot bypass macOS privacy or system protection."
            )
        }
        return parts.joined(separator: "\n\n")
    }

    private func adminMessage(_ r: AdminDeleteResult) -> String { r.message }

    @ViewBuilder
    private var content: some View {
        if vm.volumes.isEmpty && !vm.isScanning {
            EmptyState(hasScanned: vm.hasScanned) { vm.startScan() }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(vm.volumes) { volume in
                        VolumeSection(volume: volume, vm: vm)
                    }
                }
                .padding(20)
            }
        }
    }
}
