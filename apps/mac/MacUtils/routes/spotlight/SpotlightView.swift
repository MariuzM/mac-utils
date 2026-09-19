import AppKit
import SwiftUI

struct SpotlightView: View {
    @ObservedObject var vm: SpotlightViewModel

    var body: some View {
        PageScaffold(title: AppSection.spotlight.title, subtitle: subtitle) {
            if vm.isWorking {
                ProgressView().controlSize(.small)
            }
            if vm.loaded {
                IconButton(systemName: "arrow.clockwise", help: "Reload the list from the system") {
                    vm.refresh()
                }
                .disabled(vm.isWorking)

                Button {
                    vm.openSettings()
                } label: {
                    Label("Edit in System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
        } content: {
            content
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if vm.loaded && !vm.isWorking { vm.refreshIfExpectingChange() }
        }
        .alert("Couldn’t read Spotlight privacy", isPresented: $vm.showError, presenting: vm.lastError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var subtitle: String {
        if vm.isWorking && !vm.status.isEmpty { return vm.status }
        if !vm.loaded { return "Mirrors the System Settings › Spotlight › Privacy list" }
        if vm.folders.isEmpty { return "No folders excluded from Spotlight indexing" }
        return "\(vm.folders.count) folder\(vm.folders.count == 1 ? "" : "s") excluded from indexing"
    }

    @ViewBuilder
    private var content: some View {
        if !vm.loaded {
            EmptyStateView(
                "Spotlight Privacy",
                symbol: "magnifyingglass.circle",
                message:
                    "Shows the folders excluded from Spotlight in System Settings › Spotlight › Privacy. Reading this list is protected by macOS, so you’ll be asked for your password once."
            ) {
                Button {
                    vm.refresh()
                } label: {
                    Label("Load Current List", systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.isWorking)
            }
        } else if vm.folders.isEmpty {
            EmptyStateView(
                "No folders excluded",
                symbol: "magnifyingglass.circle",
                message:
                    "Nothing is currently excluded from Spotlight. Add folders in System Settings › Spotlight › Privacy and they’ll show up here."
            ) {
                Button {
                    vm.openSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        } else {
            PageScroll(spacing: 12) {
                Notice(
                    text:
                        "This is the live system list. To add or remove folders, edit it in System Settings — changes appear here automatically.",
                    symbol: "info.circle",
                    color: .secondary)
                ListCard {
                    ForEach(vm.folders) { folder in
                        SpotlightRow(folder: folder, vm: vm)
                        if folder.id != vm.folders.last?.id {
                            RowDivider(leading: 40)
                        }
                    }
                }
            }
        }
    }
}
