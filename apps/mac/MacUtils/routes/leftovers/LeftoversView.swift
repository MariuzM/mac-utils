import SwiftUI

struct LeftoversView: View {
    @ObservedObject var vm: LeftoversViewModel

    var body: some View {
        PageScaffold(title: AppSection.leftovers.title, subtitle: subtitle) {
            if vm.isScanning {
                ProgressView().controlSize(.small)
            }
            if vm.hasScanned && !vm.groups.isEmpty {
                Menu("Select") {
                    Button("Confirmed orphans only") { vm.selectConfirmedOnly() }
                    Button("Everything found") { vm.selectAll() }
                    Divider()
                    Button("Nothing") { vm.clearSelection() }
                }
                .fixedSize()

                Button(role: .destructive) {
                    vm.showRemoveConfirm = true
                } label: {
                    Label("Remove \(vm.selectedItems.count)", systemImage: "trash")
                }
                .disabled(vm.selectedItems.isEmpty || vm.isScanning)
            }
            Button {
                vm.scan()
            } label: {
                Label(vm.hasScanned ? "Rescan" : "Scan", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isScanning)
        } banner: {
            ScanIssuesView(issues: vm.scanIssues, omittedCount: vm.omittedIssueCount)
        } content: {
            content
        }
        .confirmationDialog(
            "Remove \(vm.selectedItems.count) items (\(ByteFormat.string(vm.selectedBytes)))?",
            isPresented: $vm.showRemoveConfirm, titleVisibility: .visible
        ) {
            Button("Move to Trash") { vm.removeSelected(mode: .trash) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .alert("Removed", isPresented: $vm.showSummary, presenting: vm.lastSummary) { summary in
            if !vm.pendingAdminPaths.isEmpty {
                Button("Authorize and Remove \(vm.pendingAdminPaths.count)…") {
                    vm.showAdminPrompt = true
                }
            }
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text(summaryMessage(summary))
        }
        .confirmationDialog(
            "Remove \(vm.pendingAdminPaths.count) items as administrator?",
            isPresented: $vm.showAdminPrompt, titleVisibility: .visible
        ) {
            Button("Authorize and Remove…", role: .destructive) { vm.removePendingAsAdmin() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "These items were denied access. macOS will ask for your administrator password; this cannot bypass privacy or system protection.\n\nAdministrator removal deletes permanently — these items do not go to the Trash and cannot be put back."
            )
        }
        .alert("Finished", isPresented: $vm.showAdminResult, presenting: vm.lastAdmin) { result in
            if !result.accessDeniedPaths.isEmpty { Button("Open Full Disk Access") { FullDiskAccess.openSettings() } }
            Button("OK", role: .cancel) {}
        } message: { result in
            Text(result.message)
        }
    }

    private var subtitle: String {
        if vm.isScanning && !vm.phase.isEmpty { return vm.phase }
        guard vm.hasScanned else { return AppSection.leftovers.subtitle }
        guard !vm.groups.isEmpty else { return "Nothing left behind" }
        return
            "\(vm.confirmedCount) confirmed · \(vm.reviewCount) to review · \(ByteFormat.string(vm.selectedBytes)) selected"
    }

    private func summaryMessage(_ summary: DeleteSummary) -> String {
        var parts = ["\(summary.deleted) items (\(ByteFormat.string(summary.bytes))) moved to the Trash."]
        if !vm.pendingAdminPaths.isEmpty {
            parts.append(
                "\(vm.pendingAdminPaths.count) were denied access and can be retried as administrator. Authorize to remove them — note that this deletes permanently, not to the Trash."
            )
        }
        if !summary.issues.isEmpty { parts.append(summary.issues.prefix(5).map(\.description).joined(separator: "\n")) }
        return parts.joined(separator: "\n\n")
    }

    private var confirmMessage: String {
        var parts = ["Everything that can go to the Trash does, so you can put it back if an app misbehaves."]
        if vm.selectedReviewCount > 0 {
            parts.append(
                "\(vm.selectedReviewCount) of these are flagged “Review first” — they were matched by bundle identifier, which can be wrong for app extensions and suites."
            )
        }
        if vm.selectedNeedsAdmin {
            parts.append(
                "Some are root-owned. The app will try the Trash first and offer a separate administrator retry if access is denied."
            )
        }
        return parts.joined(separator: "\n\n")
    }

    @ViewBuilder
    private var content: some View {
        if vm.isScanning && vm.groups.isEmpty {
            LoadingStateView(message: vm.phase.isEmpty ? "Scanning…" : vm.phase)
        } else if !vm.hasScanned {
            EmptyStateView(
                "Find leftovers from uninstalled apps",
                symbol: "trash.slash",
                message:
                    "Startup items, privileged helpers, preference panes, kernel extensions, plug-ins, containers, preferences and cached data that no installed app claims."
            ) {
                Button {
                    vm.scan()
                } label: {
                    Label("Scan Now", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        } else if vm.groups.isEmpty {
            EmptyStateView(
                "No leftovers found",
                symbol: "checkmark.seal",
                message:
                    "No candidates were found in accessible locations. Some protected folders may not have been inspected."
            )
        } else {
            PageScroll {
                ForEach(vm.groups) { group in
                    LeftoverGroupSection(group: group, vm: vm)
                }
            }
        }
    }
}
