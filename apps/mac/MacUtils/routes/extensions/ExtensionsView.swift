import SwiftUI

struct ExtensionsView: View {
    @ObservedObject var vm: ExtensionsViewModel

    var body: some View {
        PageScaffold(title: AppSection.extensions.title, subtitle: subtitle) {
            if vm.isWorking {
                ProgressView().controlSize(.small)
            }
            SearchField(prompt: "Search extensions or apps", text: $vm.search, width: 230)
            if vm.loaded {
                IconButton(systemName: "arrow.clockwise", help: "Reload the current handlers from the system") {
                    vm.refresh()
                }
                .disabled(vm.isWorking)
            }
        } content: {
            content
        }
        .onAppear { vm.loadIfNeeded() }
        .alert("Couldn’t change the default app", isPresented: $vm.showError, presenting: vm.lastError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var subtitle: String {
        if !vm.loaded { return AppSection.extensions.subtitle }
        return "\(vm.entries.count) extensions — types that share a handler change together (e.g. .jpg and .jpeg)"
    }

    @ViewBuilder
    private var content: some View {
        if !vm.loaded {
            LoadingStateView(message: "Reading file type handlers…")
        } else if vm.visibleGroups.isEmpty {
            EmptyStateView(
                "No matches", symbol: "magnifyingglass",
                message: "No extension, file type, or app matches “\(vm.search)”.")
        } else {
            PageScroll {
                ForEach(vm.visibleGroups, id: \.category) { group in
                    ExtensionGroupSection(category: group.category, entries: group.entries, vm: vm)
                }
            }
        }
    }
}
