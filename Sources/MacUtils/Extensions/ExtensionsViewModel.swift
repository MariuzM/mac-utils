import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ExtensionsViewModel: ObservableObject {
    @Published private(set) var entries: [ExtensionEntry] = []
    @Published private(set) var loaded = false
    @Published private(set) var isWorking = false
    @Published var search = ""
    @Published var lastError: String?
    @Published var showError = false

    private var iconCache: [URL: NSImage] = [:]
    private var loadTask: Task<Void, Never>?

    deinit { loadTask?.cancel() }

    var visibleGroups: [(category: ExtensionCategory, entries: [ExtensionEntry])] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return ExtensionCategory.allCases.compactMap { category in
            let matches = entries.filter { entry in
                guard entry.category == category else { return false }
                guard !query.isEmpty else { return true }
                return entry.ext.contains(query)
                    || entry.typeDescription.lowercased().contains(query)
                    || (entry.defaultApp?.name.lowercased().contains(query) ?? false)
            }
            return matches.isEmpty ? nil : (category, matches)
        }
    }

    func loadIfNeeded() {
        guard !loaded && !isWorking else { return }
        refresh()
    }

    func refresh() {
        guard !isWorking else { return }
        isWorking = true
        loadTask?.cancel()
        loadTask = Task {
            let result = await Task.detached(priority: .userInitiated) {
                ExtensionCatalog.buildEntries()
            }.value
            entries = result
            loaded = true
            isWorking = false
        }
    }

    func setDefault(_ app: HandlerApp, for entry: ExtensionEntry) {
        guard let typeID = entry.typeID, let type = UTType(typeID) else { return }
        isWorking = true
        Task {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: app.url, toOpen: type)
                apply(app, toTypeID: typeID)
            } catch let e {
                lastError = e.localizedDescription
                showError = true
            }
            isWorking = false
        }
    }

    func chooseOtherApp(for entry: ExtensionEntry) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an app to open .\(entry.ext) files"
        panel.prompt = "Set Default"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setDefault(HandlerApp(url: url), for: entry)
    }

    func icon(for url: URL) -> NSImage {
        if let cached = iconCache[url] { return cached }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        iconCache[url] = image
        return image
    }

    private func apply(_ app: HandlerApp, toTypeID typeID: String) {
        for i in entries.indices where entries[i].typeID == typeID {
            entries[i].defaultApp = app
            if !entries[i].candidates.contains(app) {
                entries[i].candidates = (entries[i].candidates + [app])
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
    }
}
