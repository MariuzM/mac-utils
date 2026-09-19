import SwiftUI

struct LaunchItemsView: View {
    @ObservedObject var vm: LaunchItemsViewModel

    var body: some View {
        PageScaffold(title: AppSection.launchItems.title, subtitle: subtitle) {
            if vm.isWorking {
                ProgressView().controlSize(.small)
            }
            SearchField(prompt: "Search labels or programs", text: $vm.search, width: 230)
            if vm.loaded {
                IconButton(systemName: "arrow.clockwise", help: "Reload launch items from the system") {
                    vm.refresh()
                }
                .disabled(vm.isWorking)
            }
        } content: {
            content
        }
        .onAppear { vm.loadIfNeeded() }
        .alert("Couldn’t change the launch item", isPresented: $vm.showError, presenting: vm.lastError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var subtitle: String {
        guard vm.loaded else { return AppSection.launchItems.subtitle }
        return "\(vm.items.count) jobs · \(vm.enabledCount) allowed — a disabled job stays off after restarts and app updates"
    }

    @ViewBuilder
    private var content: some View {
        if !vm.loaded {
            LoadingStateView(message: "Reading launch items…")
        } else if vm.visibleGroups.isEmpty && vm.visibleExtensions.isEmpty {
            EmptyStateView(
                "No matches", symbol: "magnifyingglass",
                message: "No launch item or extension matches “\(vm.search)”.")
        } else {
            PageScroll {
                ForEach(vm.visibleGroups, id: \.scope) { group in
                    LaunchScopeSection(scope: group.scope, items: group.items, vm: vm)
                }
                if !vm.visibleExtensions.isEmpty {
                    FinderExtensionSection(extensions: vm.visibleExtensions, vm: vm)
                }
            }
        }
    }
}
