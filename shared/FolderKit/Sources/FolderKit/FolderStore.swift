import AppKit
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

    @Published public private(set) var loadError: String?

    private let dockOverridesKey = "dockOverriddenFolders"
    private var suppressPersist = false
    private var unreadableOnDisk = false

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
        let folder = PinnedFolder(path: url.standardizedFileURL.path)
        guard !folders.contains(folder) else { return }
        folders.append(folder)
    }

    @discardableResult
    public func pinFromOpenPanel(activate: Bool = false) -> Int {
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return 0 }
        for url in panel.urls { pin(url) }
        return panel.urls.count
    }

    public func unpin(_ folder: PinnedFolder) {
        folders.removeAll { $0.id == folder.id }
    }

    public enum FolderListing {
        case entries([FolderEntry])
        case unreadable(String)
    }

    public func listing(of url: URL) -> FolderListing {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
            return .entries(sorted(contents))
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }

    public func entries(of url: URL) -> [FolderEntry] {
        if case .entries(let e) = listing(of: url) { return e }
        return []
    }

    private func sorted(_ contents: [URL]) -> [FolderEntry] {
        contents
            .map { child in
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                let isDirectory = values?.isDirectory == true && values?.isPackage != true
                return FolderEntry(url: child, isDirectory: isDirectory)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    private func withPersistSuppressed(_ body: () -> Void) {
        let previous = suppressPersist
        suppressPersist = true
        body()
        suppressPersist = previous
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            withPersistSuppressed { folders = Self.defaultFolders }
            loadError = nil
            unreadableOnDisk = false
            return
        }
        guard let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([PinnedFolder].self, from: data)
        else {
            withPersistSuppressed { folders = [] }
            unreadableOnDisk = true
            loadError =
                "Pinned folders could not be read. The existing file is left untouched — "
                + "fix or remove it rather than re-pinning, or your folders will be overwritten."
            return
        }
        withPersistSuppressed { folders = decoded }
        loadError = nil
        unreadableOnDisk = false
    }

    private func save() {
        guard !unreadableOnDisk else { return }
        guard !suppressPersist, let data = try? JSONEncoder().encode(folders) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            loadError = "Pinned folders could not be saved: \(error.localizedDescription)"
            return
        }
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
