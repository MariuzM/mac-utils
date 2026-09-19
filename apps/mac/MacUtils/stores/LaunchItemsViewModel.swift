import Foundation
import SwiftUI

@MainActor
final class LaunchItemsViewModel: ObservableObject {
    @Published private(set) var items: [LaunchItem] = []
    @Published private(set) var extensions: [FinderExtension] = []
    @Published private(set) var loaded = false
    @Published private(set) var isWorking = false
    @Published var search = ""
    @Published var lastError: String?
    @Published var showError = false

    var visibleGroups: [(scope: LaunchScope, items: [LaunchItem])] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return LaunchScope.allCases.compactMap { scope in
            let matches = items.filter { item in
                guard item.scope == scope else { return false }
                guard !query.isEmpty else { return true }
                return item.label.lowercased().contains(query)
                    || (item.program?.lowercased().contains(query) ?? false)
            }
            return matches.isEmpty ? nil : (scope, matches)
        }
    }

    var visibleExtensions: [FinderExtension] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return extensions }
        return extensions.filter {
            $0.bundleID.lowercased().contains(query) || $0.parentAppName.lowercased().contains(query)
        }
    }

    var enabledCount: Int {
        items.filter { !$0.isDisabled }.count
    }

    func loadIfNeeded() {
        guard !loaded else { return }
        refresh()
    }

    func refresh() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            let (items, extensions) = await Task.detached(priority: .userInitiated) {
                (LaunchItemCatalog.loadItems(), LaunchItemCatalog.loadFinderExtensions())
            }.value
            self.items = items
            self.extensions = extensions
            loaded = true
            isWorking = false
        }
    }

    func setEnabled(_ enabled: Bool, item: LaunchItem) {
        perform { try LaunchItemCatalog.setEnabled(enabled, item: item) }
    }

    func setEnabled(_ enabled: Bool, extension ext: FinderExtension) {
        perform { try LaunchItemCatalog.setEnabled(enabled, extension: ext) }
    }

    private func perform(_ action: @escaping @Sendable () throws -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            let failure: Error? = await Task.detached(priority: .userInitiated) {
                do {
                    try action()
                    return nil
                } catch let e {
                    return e
                }
            }.value
            if let failure, !isCancellation(failure) {
                lastError = failure.localizedDescription
                showError = true
            }
            isWorking = false
            refresh()
        }
    }

    private func isCancellation(_ e: Error) -> Bool {
        if case LaunchItemError.cancelled = e { return true }
        return false
    }
}
