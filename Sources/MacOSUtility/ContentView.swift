import SwiftUI
import AppKit

enum AppTab: Hashable {
    case cleaner
    case spotlight
}

struct ContentView: View {
    @StateObject private var scanVM = ScanViewModel()
    @StateObject private var spotlightVM = SpotlightViewModel()
    @State private var tab: AppTab = .cleaner

    var body: some View {
        TabView(selection: $tab) {
            CleanerView(vm: scanVM)
                .tabItem { Label("Cleaner", systemImage: "sparkles") }
                .tag(AppTab.cleaner)
            SpotlightView(vm: spotlightVM)
                .tabItem { Label("Spotlight Privacy", systemImage: "magnifyingglass.circle") }
                .tag(AppTab.spotlight)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

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
        .frame(minWidth: 720, minHeight: 480)
        .onAppear { vm.refreshAccess() }
        .alert("Backup complete", isPresented: $vm.showBackupResult, presenting: vm.lastBackup) { summary in
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([summary.destination])
            }
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text("\(summary.copied) items (\(ByteFormat.string(summary.bytes))) copied to\n\(summary.destination.path)"
                 + (summary.failed > 0 ? "\n\n\(summary.failed) items could not be copied (likely permission-protected)." : ""))
        }
        .confirmationDialog("Delete \(vm.pendingCount) items (\(ByteFormat.string(vm.pendingBytes)))?",
                            isPresented: $vm.showDeleteConfirm, titleVisibility: .visible) {
            Button("Move to Trash") { vm.performDelete(mode: .trash) }
            Button("Delete as Administrator…") { vm.performAdminDelete() }
            Button("Delete Permanently", role: .destructive) { vm.performDelete(mode: .permanent) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Move to Trash is recoverable but can't remove root-owned system items.\n"
                 + "Delete as Administrator (asks for your password) removes those permanently and cleans simulator runtimes properly."
                 + (vm.pendingReviewCount > 0 ? "\n\n\(vm.pendingReviewCount) of these are flagged “Review first.”" : ""))
        }
        .alert(vm.lastDelete?.mode == .trash ? "Moved to Trash" : "Deleted", isPresented: $vm.showDeleteResult, presenting: vm.lastDelete) { summary in
            if summary.failed > 0 {
                Button("Remove \(summary.failed) protected items…") { vm.retryFailedAsAdmin() }
            }
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text("\(summary.deleted) items (\(ByteFormat.string(summary.bytes))) removed."
                 + (summary.mode == .trash ? "\nEmpty the Trash to reclaim the space." : "")
                 + (summary.failed > 0 ? "\n\n\(summary.failed) items are protected. This tries removing them the right way — as you (with Full Disk Access), as administrator, or via simctl for simulators." : ""))
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

    private func adminMessage(_ r: AdminDeleteResult) -> String {
        var parts = ["Removed \(r.removed) of \(r.attempted) items."]
        if r.cancelled { parts.append("Cancelled before finishing.") }
        if !r.needsFullDiskAccess.isEmpty {
            parts.append("\(r.needsFullDiskAccess.count) items are protected by macOS privacy. Grant this app Full Disk Access, then delete again — no password needed.")
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

struct HeaderBar: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("macOS Utility")
                    .font(.headline)
                if vm.hasScanned && !vm.isScanning {
                    Text("\(ByteFormat.string(vm.totalReclaimable)) reclaimable · \(vm.totalItems) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if vm.isDeleting {
                    Text(vm.deletePhase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if vm.isBackingUp {
                    Text(vm.backupPhase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if vm.isScanning {
                    Text(vm.phase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Preview mode — nothing is deleted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if vm.isScanning {
                ProgressView(value: vm.fraction)
                    .frame(width: 140)
                Button("Cancel") { vm.cancel() }
            } else if vm.isBackingUp {
                ProgressView(value: vm.backupFraction)
                    .frame(width: 140)
                Button("Cancel") { vm.cancelBackup() }
            } else if vm.isDeleting {
                if vm.deleteIndeterminate {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    ProgressView(value: vm.deleteFraction)
                        .frame(width: 140)
                }
                Button("Cancel") { vm.cancelDelete() }
            } else {
                if !vm.consoleLines.isEmpty && !vm.showConsole {
                    Button {
                        vm.showConsole = true
                    } label: {
                        Label("Console", systemImage: "terminal")
                    }
                    .help("Show the activity log")
                }
                if vm.hasScanned && vm.totalItems > 0 {
                    Button(role: .destructive) {
                        vm.requestDelete(items: vm.selectedItems)
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .tint(.red)
                    .disabled(vm.selectedItems.isEmpty)
                    .help("Remove the checked categories — asks whether to Trash or delete permanently")

                    Button {
                        vm.backup(items: vm.selectedItems)
                    } label: {
                        Label("Back Up Selected", systemImage: "arrow.down.doc")
                    }
                    .disabled(vm.selectedItems.isEmpty)
                    .help("Copy the checked categories to a folder on your Desktop, preserving original paths")
                }
                Button {
                    vm.startScan()
                } label: {
                    Label(vm.hasScanned ? "Rescan" : "Scan", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct ConsolePanel: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Console")
                    .font(.caption.weight(.semibold))
                if vm.isDeleting {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                Button("Clear") { vm.clearConsole() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    vm.showConsole = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide console")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(vm.consoleLines.enumerated()), id: \.offset) { i, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(i)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .onChange(of: vm.consoleLines.count) { _ in
                    if let last = vm.consoleLines.indices.last {
                        withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
        .frame(height: 190)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func color(for line: String) -> Color {
        if line.hasPrefix("✓") { return .green }
        if line.hasPrefix("✗") || line.hasPrefix("FAILED") { return .red }
        if line.hasPrefix("⚠︎") || line.localizedCaseInsensitiveContains("full disk access") { return .orange }
        if line.hasPrefix("…") || line.hasPrefix("→") || line.hasPrefix("──") || line.hasPrefix("⏹") { return .secondary }
        return .primary
    }
}

struct FullDiskAccessBanner: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Full Disk Access not granted")
                    .font(.callout.weight(.medium))
                Text("System and other-user locations at the root are skipped until you grant access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") { FullDiskAccess.openSettings() }
            Button {
                vm.refreshAccess()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Re-check after granting access")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }
}

struct VolumeSection: View {
    let volume: VolumeResult
    @ObservedObject var vm: ScanViewModel

    private var userCategories: [CategoryResult] {
        volume.categories.filter { !$0.isSystem }
    }

    private var systemCategories: [CategoryResult] {
        volume.categories.filter(\.isSystem)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: volume.isBoot ? "internaldrive.fill" : "externaldrive.fill")
                    .foregroundStyle(.tint)
                Text(volume.name)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(ByteFormat.string(volume.totalSize))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if volume.categories.isEmpty {
                Text("Nothing found on this volume.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !userCategories.isEmpty && !systemCategories.isEmpty {
                CategoryGroup(title: "User Files", categories: userCategories, vm: vm)
                CategoryGroup(title: "System Files", categories: systemCategories, vm: vm)
            } else {
                CategoryGroup(title: nil, categories: volume.categories, vm: vm)
            }
        }
    }
}

struct CategoryGroup: View {
    let title: String?
    let categories: [CategoryResult]
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check all") { vm.selectAll(categories) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Uncheck all") { vm.deselectAll(categories) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 0) {
                ForEach(categories) { category in
                    CategoryRow(category: category, vm: vm)
                    if category.id != categories.last?.id {
                        Divider()
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

struct CategoryRow: View {
    let category: CategoryResult
    @ObservedObject var vm: ScanViewModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { vm.isSelected(category) },
                    set: { vm.setSelected(category, $0) }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("Include this category in Delete Selected / Back Up Selected")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(category.title)
                                    .font(.body.weight(.medium))
                                SafetyBadge(safety: category.safety)
                            }
                            Text(category.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(ByteFormat.string(category.totalSize))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("\(category.items.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 34, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    vm.backup(items: category.items)
                } label: {
                    Image(systemName: "arrow.down.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(vm.isBusy)
                .help("Back up this category to the Desktop")

                Button {
                    vm.requestDelete(items: category.items)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .disabled(vm.isBusy)
                .help("Delete this category")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(category.items.prefix(200)) { item in
                        ItemRow(item: item)
                    }
                    if category.items.count > 200 {
                        Text("+ \(category.items.count - 200) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 38)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }
}

struct ItemRow: View {
    let item: ScanItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.url.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormat.string(item.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "arrow.forward.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 5)
    }
}

struct SafetyBadge: View {
    let safety: SafetyLevel

    private var color: Color {
        switch safety {
        case .safe: return .green
        case .caution: return .orange
        case .review: return .red
        }
    }

    var body: some View {
        Text(safety.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct EmptyState: View {
    let hasScanned: Bool
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(hasScanned ? "No removable files found" : "Scan your Mac for removable files")
                .font(.title3.weight(.semibold))
            Text("Caches, logs, trash, developer junk and temporary files across all mounted volumes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button(action: onScan) {
                Label("Scan Now", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
