import AppKit
import SwiftUI

struct LaunchScopeSection: View {
    let scope: LaunchScope
    let items: [LaunchItem]
    @ObservedObject var vm: LaunchItemsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(scope.rawValue, symbol: scope.icon, count: items.count) {
                if scope.needsAdmin {
                    Text("Needs administrator access")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ListCard {
                ForEach(items) { item in
                    LaunchItemRow(item: item, vm: vm)
                    if item.id != items.last?.id {
                        RowDivider()
                    }
                }
            }
        }
    }
}

struct LaunchItemRow: View {
    let item: LaunchItem
    @ObservedObject var vm: LaunchItemsViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.program ?? item.plistPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if item.keepsAlive {
                StatusBadge(title: "Keep alive", color: .orange, showsDot: false)
            }
            if item.runsAtLoad {
                StatusBadge(title: "At login", color: .blue, showsDot: false)
            }
            StatusBadge(title: item.state.label, color: item.state.isRunning ? .green : .secondary)
            Menu {
                Button("Reveal Plist in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.plistPath)])
                }
                if let program = item.program {
                    Button("Reveal Program in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: program)])
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            Toggle(
                "",
                isOn: Binding(
                    get: { !item.isDisabled },
                    set: { vm.setEnabled($0, item: item) }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .disabled(vm.isWorking)
            .help(item.isDisabled ? "Allow launchd to start this job" : "Stop this job and keep it from starting")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

struct FinderExtensionSection: View {
    let extensions: [FinderExtension]
    @ObservedObject var vm: LaunchItemsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Finder Extensions", symbol: "puzzlepiece.extension", count: extensions.count)
            ListCard {
                ForEach(extensions) { ext in
                    FinderExtensionRow(ext: ext, vm: vm)
                    if ext.id != extensions.last?.id {
                        RowDivider()
                    }
                }
            }
        }
    }
}

struct FinderExtensionRow: View {
    let ext: FinderExtension
    @ObservedObject var vm: LaunchItemsViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ext.parentAppName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(ext.bundleID) · \(ext.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if ext.election == .systemDefault {
                StatusBadge(title: "System default", color: .secondary, showsDot: false)
            }
            Toggle(
                "",
                isOn: Binding(
                    get: { !ext.isDisabled },
                    set: { vm.setEnabled($0, extension: ext) }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .disabled(vm.isWorking)
            .help(ext.isDisabled ? "Let Finder load this extension" : "Keep Finder from loading this extension")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}
