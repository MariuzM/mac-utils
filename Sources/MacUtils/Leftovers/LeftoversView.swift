import AppKit
import SwiftUI

struct LeftoversView: View {
    @ObservedObject var vm: LeftoversViewModel

    var body: some View {
        VStack(spacing: 0) {
            LeftoversHeaderBar(vm: vm)
            Divider()
            ScanIssuesView(issues: vm.scanIssues, omittedCount: vm.omittedIssueCount)
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
            VStack(spacing: 14) {
                ProgressView()
                Text(vm.phase.isEmpty ? "Scanning…" : vm.phase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !vm.hasScanned {
            LeftoversEmptyState(vm: vm)
        } else if vm.groups.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text("No leftovers found")
                    .font(.title3.weight(.semibold))
                Text(
                    "No candidates were found in accessible locations. Some protected folders may not have been inspected."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(vm.groups) { group in
                        LeftoverGroupSection(group: group, vm: vm)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct LeftoversEmptyState: View {
    @ObservedObject var vm: LeftoversViewModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "trash.slash")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Find leftovers from uninstalled apps")
                .font(.title3.weight(.semibold))
            Text(
                "Startup items, privileged helpers, preference panes, kernel extensions, plug-ins, containers, preferences and cached data that no installed app claims."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)
            Button {
                vm.scan()
            } label: {
                Label("Scan Now", systemImage: "magnifyingglass")
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct LeftoversHeaderBar: View {
    @ObservedObject var vm: LeftoversViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Leftovers")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

            }
            .layoutPriority(1)

            Spacer(minLength: 12)

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

                Button {
                    vm.showRemoveConfirm = true
                } label: {
                    Text("Remove \(vm.selectedItems.count)")
                }
                .disabled(vm.selectedItems.isEmpty || vm.isScanning)
            }

            Button {
                vm.scan()
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
            }
            .disabled(vm.isScanning)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var subtitle: String {
        if vm.isScanning && !vm.phase.isEmpty { return vm.phase }
        guard vm.hasScanned else { return "Find files left behind by apps you removed" }
        guard !vm.groups.isEmpty else { return "Nothing left behind" }
        return
            "\(vm.confirmedCount) confirmed · \(vm.reviewCount) to review · \(ByteFormat.string(vm.selectedBytes)) selected"
    }
}

struct LeftoverGroupSection: View {
    let group: LeftoverGroup
    @ObservedObject var vm: LeftoversViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { vm.isFullySelected(group) },
                        set: { _ in vm.toggle(group: group) })
                )
                .toggleStyle(.checkbox)
                .labelsHidden()

                Image(systemName: group.icon)
                    .foregroundStyle(.tint)
                    .frame(width: 20)

                Text(group.title)
                    .font(.headline)

                Text("\(group.items.count)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)

                ConfidenceBadge(confidence: group.confidence)

                Spacer()

                Text(ByteFormat.string(group.totalSize))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    vm.toggleExpanded(group)
                } label: {
                    Image(systemName: vm.expanded.contains(group.id) ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Text(group.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if vm.expanded.contains(group.id) {
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        LeftoverRow(item: item, vm: vm)
                        if item.id != group.items.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
            }
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: LeftoverConfidence

    var body: some View {
        Text(confidence.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        confidence == .confirmed ? .green : .orange
    }
}

struct LeftoverRow: View {
    let item: LeftoverItem
    @ObservedObject var vm: LeftoversViewModel

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { vm.selected.contains(item.id) },
                    set: { _ in vm.toggle(item) })
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if item.needsAdmin {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("Root-owned — needs your administrator password")
                    }
                }
                Text(item.evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text(ByteFormat.string(item.size))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Button {
                vm.reveal(item)
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(item.url.path)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}
