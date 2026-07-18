import SwiftUI
import AppKit
import FolderKit

struct CleanerView: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(vm: vm)
            Divider()
            if !vm.fullDiskAccess {
                FullDiskAccessBanner(vm: vm)
                Divider()
            }
            content
            if vm.showConsole {
                Divider()
                ConsolePanel(vm: vm)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .onAppear { vm.refreshAccess() }
        .alert("Backup complete", isPresented: $vm.showBackupResult, presenting: vm.lastBackup) { summary in
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
                "Move to Trash is recoverable but can't remove root-owned system items.\n"
                    + "Delete as Administrator (asks for your password) removes those permanently and cleans simulator runtimes properly."
                    + (vm.pendingReviewCount > 0
                        ? "\n\n\(vm.pendingReviewCount) of these are flagged “Review first.”" : ""))
        }
        .alert(
            vm.lastDelete?.mode == .trash ? "Moved to Trash" : "Deleted", isPresented: $vm.showDeleteResult,
            presenting: vm.lastDelete
        ) { summary in
            if summary.failed > 0 {
                Button("Remove \(summary.failed) protected items…") { vm.retryFailedAsAdmin() }
            }
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text(
                "\(summary.deleted) items (\(ByteFormat.string(summary.bytes))) removed."
                    + (summary.mode == .trash ? "\nEmpty the Trash to reclaim the space." : "")
                    + (summary.failed > 0
                        ? "\n\n\(summary.failed) items are protected. This tries removing them the right way — as you (with Full Disk Access), as administrator, or via simctl for simulators."
                        : ""))
        }
        .alert("Cleanup finished", isPresented: $vm.showAdminResult, presenting: vm.lastAdmin) { result in
            if !result.needsFullDiskAccess.isEmpty {
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
        if s.failed > 0 {
            let detail = s.failures.prefix(3).map { "\($0.path) — \($0.reason)" }.joined(separator: "\n")
            parts.append("\(s.failed) items could not be copied:\n\(detail)")
        }
        return parts.joined(separator: "\n\n")
    }

    private func adminMessage(_ r: AdminDeleteResult) -> String {
        var parts = ["Removed \(r.removed) of \(r.attempted) items."]
        if !r.rejected.isEmpty {
            parts.append("\(r.rejected.count) item(s) were refused because they are protected system locations:\n"
                         + r.rejected.prefix(3).joined(separator: "\n"))
        }
        if r.cancelled { parts.append("Cancelled before finishing.") }
        if !r.needsFullDiskAccess.isEmpty {
            parts.append(
                "\(r.needsFullDiskAccess.count) items are protected by macOS privacy. Grant this app Full Disk Access, then delete again — no password needed."
            )
        }
        if !r.failed.isEmpty {
            parts.append("\(r.failed.count) items could not be removed (may be in use or SIP-protected).")
        }
        return parts.joined(separator: "\n\n")
    }

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
