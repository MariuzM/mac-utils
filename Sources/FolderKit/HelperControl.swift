import AppKit

public enum HelperControl {
    public static var helperURL: URL? {
        let embedded = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LoginItems/FolderHelper.app")
        return FileManager.default.fileExists(atPath: embedded.path) ? embedded : nil
    }

    public static var isTrusted: Bool {
        SharedConfig.defaults.bool(forKey: SharedConfig.helperTrustedKey)
    }

    public static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: SharedConfig.helperBundleID).isEmpty
    }

    public static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(SharedConfig.helperLabel).plist")
    }

    public static var launchesAtLogin: Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    private static let legacyLabels = ["mariuzm.macosutility.folderhelper"]

    public static func migrateLegacyLoginItems() {
        for label in legacyLabels {
            let plist = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/\(label).plist")
            guard FileManager.default.fileExists(atPath: plist.path) else { continue }
            launchctl(["bootout", "gui/\(getuid())/\(label)"])
            try? FileManager.default.removeItem(at: plist)
        }

        NSRunningApplication
            .runningApplications(withBundleIdentifier: "mariuzm.macosutility.folderhelper")
            .forEach { $0.terminate() }
    }

    @discardableResult
    public static func start() -> Bool {
        guard let helperURL, !isRunning else { return isRunning }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: helperURL, configuration: configuration)
        return true
    }

    public static func stop() {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: SharedConfig.helperBundleID)
            .forEach { $0.terminate() }
    }

    public static func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try installAgent()
        } else {
            try removeAgent()
        }
    }

    private static func installAgent() throws {
        guard let helperURL else { return }
        let executable = helperURL.appendingPathComponent("Contents/MacOS/FolderHelper").path

        let plist: [String: Any] = [
            "Label": SharedConfig.helperLabel,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]

        let directory = agentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentURL)

        launchctl(["bootout", "gui/\(getuid())/\(SharedConfig.helperLabel)"])
        launchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
    }

    private static func removeAgent() throws {
        launchctl(["bootout", "gui/\(getuid())/\(SharedConfig.helperLabel)"])
        try? FileManager.default.removeItem(at: agentURL)
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return -1 }
        task.waitUntilExit()
        return task.terminationStatus
    }
}
