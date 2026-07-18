import Foundation

struct PinnedFolder: Codable, Identifiable, Hashable {
    let path: String

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

struct FolderEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

@MainActor
final class FolderStore: ObservableObject {
    static let enabledKey = "foldersMenuEnabled"

    @Published var folders: [PinnedFolder] = [] {
        didSet { save() }
    }

    @Published var dockOverrides: Set<String> = [] {
        didSet { saveDockOverrides() }
    }

    private let dockOverridesKey = "dockOverriddenFolders"

    func isDockOverridden(_ url: URL) -> Bool {
        dockOverrides.contains(url.standardizedFileURL.path)
    }

    func setDockOverride(_ url: URL, enabled: Bool) {
        let path = url.standardizedFileURL.path
        if enabled {
            dockOverrides.insert(path)
        } else {
            dockOverrides.remove(path)
        }
    }

    private func loadDockOverrides() {
        let stored = UserDefaults.standard.stringArray(forKey: dockOverridesKey) ?? []
        dockOverrides = Set(stored)
    }

    private func saveDockOverrides() {
        UserDefaults.standard.set(Array(dockOverrides), forKey: dockOverridesKey)
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Folders", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("folders.json")
    }()

    init() {
        load()
        loadDockOverrides()
    }

    private static var defaultFolders: [PinnedFolder] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Downloads", "Documents", "Desktop"]
            .map { home.appendingPathComponent($0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { PinnedFolder(path: $0.path) }
    }

    func pin(_ url: URL) {
        let folder = PinnedFolder(path: url.path)
        guard !folders.contains(folder) else { return }
        folders.append(folder)
    }

    func unpin(_ folder: PinnedFolder) {
        folders.removeAll { $0.id == folder.id }
    }

    func entries(of url: URL) -> [FolderEntry] {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .map { child in
                let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return FolderEntry(url: child, isDirectory: isDirectory)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PinnedFolder].self, from: data)
        else {
            folders = Self.defaultFolders
            return
        }
        folders = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        try? data.write(to: fileURL)
    }
}
