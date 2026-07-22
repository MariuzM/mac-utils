import FolderKit
import AppKit

enum HelperError: LocalizedError {
    case notEmbedded
    case launchctlFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .notEmbedded:
            return "The helper is not embedded in this build — run `make build`."
        case .launchctlFailed(let status):
            return "launchctl could not register the helper (exit \(status))."
        }
    }
}

enum HelperControl {
    static var helperURL: URL? {
        let embedded = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LoginItems/FolderHelper.app")
        return FileManager.default.fileExists(atPath: embedded.path) ? embedded : nil
    }

    static var helperReportedTrusted: Bool {
        SharedConfig.defaults.bool(forKey: SharedConfig.helperTrustedKey)
    }

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: SharedConfig.helperBundleID).isEmpty
    }

    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(SharedConfig.helperLabel).plist")
    }

    static var launchesAtLogin: Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    private static let legacyLabels = [
        "mariuzm.macosutility.folderhelper", "dev.marius.rekey.folderhelper",
        "dev.marius.macosutility.folderhelper",
    ]

    static func migrateLegacyLoginItems() {
        for label in legacyLabels {
            let plist = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/\(label).plist")
            if FileManager.default.fileExists(atPath: plist.path) {
                launchctl(["bootout", "gui/\(getuid())/\(label)"])
                try? FileManager.default.removeItem(at: plist)
            }
            NSRunningApplication
                .runningApplications(withBundleIdentifier: label)
                .forEach { $0.terminate() }
        }
    }

    static func start(completion: (@Sendable (Result<Void, Error>) -> Void)? = nil) {
        guard let helperURL else {
            completion?(.failure(HelperError.notEmbedded))
            return
        }
        guard !isRunning else {
            completion?(.success(()))
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: helperURL, configuration: configuration) { _, error in
            completion?(error.map { .failure($0) } ?? .success(()))
        }
    }

    static func stop() {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: SharedConfig.helperBundleID)
            .forEach { $0.terminate() }
    }

    static func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try installAgent()
        } else {
            try removeAgent()
        }
    }

    private static func installAgent() throws {
        guard let helperURL else { throw HelperError.notEmbedded }
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
        let status = launchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
        guard status == 0 else {
            try? FileManager.default.removeItem(at: agentURL)
            throw HelperError.launchctlFailed(status)
        }
    }

    private static func removeAgent() throws {
        launchctl(["bootout", "gui/\(getuid())/\(SharedConfig.helperLabel)"])
        if FileManager.default.fileExists(atPath: agentURL.path) {
            try FileManager.default.removeItem(at: agentURL)
        }
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        Shell.run(SystemPaths.launchctl, arguments).status
    }
}
