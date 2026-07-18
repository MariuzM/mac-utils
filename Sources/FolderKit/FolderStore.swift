import Foundation

public struct PinnedFolder: Codable, Identifiable, Hashable {
    public let path: String

    public var id: String { path }
    public var url: URL { URL(fileURLWithPath: path) }
    public var name: String { url.lastPathComponent }

    public init(path: String) {
        self.path = path
    }
}

public struct FolderEntry: Identifiable, Hashable {
    public let url: URL
    public let isDirectory: Bool

    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }
}

@MainActor
public final class FolderStore: ObservableObject {
    public static let enabledKey = "foldersMenuEnabled"

    @Published public var folders: [PinnedFolder] = [] {
        didSet { save() }
    }

    @Published public var dockOverrides: Set<String> = [] {
        didSet { saveDockOverrides() }
    }

    private let dockOverridesKey = "dockOverriddenFolders"
    private var suppressPersist = false

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Folders", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("folders.json")
    }()

    public init() {
        load()
        loadDockOverrides()
    }

    public func isDockOverridden(_ url: URL) -> Bool {
        dockOverrides.contains(url.standardizedFileURL.path)
    }

    public func setDockOverride(_ url: URL, enabled: Bool) {
        let path = url.standardizedFileURL.path
        if enabled {
            dockOverrides.insert(path)
        } else {
            dockOverrides.remove(path)
        }
    }

    public func reloadFromDisk() {
        suppressPersist = true
        load()
        loadDockOverrides()
        suppressPersist = false
    }

    private static var defaultFolders: [PinnedFolder] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Downloads", "Documents", "Desktop"]
            .map { home.appendingPathComponent($0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { PinnedFolder(path: $0.path) }
    }

    public func pin(_ url: URL) {
        let folder = PinnedFolder(path: url.path)
        guard !folders.contains(folder) else { return }
        folders.append(folder)
    }

    public func unpin(_ folder: PinnedFolder) {
        folders.removeAll { $0.id == folder.id }
    }

    public func entries(of url: URL) -> [FolderEntry] {
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
        guard !suppressPersist, let data = try? JSONEncoder().encode(folders) else { return }
        try? data.write(to: fileURL)
        SharedConfig.postConfigChanged()
    }

    private func loadDockOverrides() {
        let stored = SharedConfig.defaults.stringArray(forKey: dockOverridesKey) ?? []
        dockOverrides = Set(stored)
    }

    private func saveDockOverrides() {
        guard !suppressPersist else { return }
        SharedConfig.defaults.set(Array(dockOverrides), forKey: dockOverridesKey)
        SharedConfig.postConfigChanged()
    }
}
