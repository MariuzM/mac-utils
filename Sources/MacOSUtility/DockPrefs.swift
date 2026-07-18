import FolderKit
import Foundation

struct DockFolder: Identifiable, Hashable {
    let label: String
    let url: URL

    var id: String { url.path }

    init(label: String, url: URL) {
        self.label = label
        self.url = url
    }
}

enum DockPrefs {
    static func folders() -> [DockFolder] {
        guard let plist = read() else { return [] }
        guard let others = plist["persistent-others"] as? [[String: Any]] else { return [] }

        return others.compactMap { entry in
            guard entry["tile-type"] as? String == "directory-tile",
                  let data = entry["tile-data"] as? [String: Any],
                  let fileData = data["file-data"] as? [String: Any],
                  let raw = fileData["_CFURLString"] as? String,
                  let url = URL(string: raw)
            else { return nil }

            let label = data["file-label"] as? String ?? url.lastPathComponent
            return DockFolder(label: label, url: url.standardizedFileURL)
        }
    }

    private static func read() -> [String: Any]? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        if let data = try? Data(contentsOf: path),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            return plist
        }

        guard let data = Shell.runData(SystemPaths.defaults, ["export", "com.apple.dock", "-"]) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }
}
