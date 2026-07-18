import Foundation

public struct DockFolder: Identifiable, Hashable {
    public let label: String
    public let url: URL

    public var id: String { url.path }

    public init(label: String, url: URL) {
        self.label = label
        self.url = url
    }
}

public enum DockPrefs {
    public static func folders() -> [DockFolder] {
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

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["export", "com.apple.dock", "-"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }
}
