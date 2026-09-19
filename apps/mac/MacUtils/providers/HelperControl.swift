import AppKit
import FolderKit
import ServiceManagement

enum HelperError: LocalizedError {
    case notEmbedded
    case launchctlFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .notEmbedded:
            return "Open the bundled Mac Utils app to use Dock Folders."
        case .launchctlFailed(let status):
            return "launchctl could not register the helper (exit \(status))."
        }
    }
}

@MainActor
enum HelperControl {
    static var helperURL: URL? {
        let embedded = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LoginItems/FolderHelper.app")
        return FileManager.default.fileExists(atPath: embedded.path) ? embedded : nil
    }

    static var helperReportedTrusted: Bool {
        SharedConfig.defaults.bool(forKey: SharedConfig.helperTrustedKey)
    }

    static var instances: [NSRunningApplication] {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: SharedConfig.helperBundleID)
            .sorted { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
    }

    static var isRunning: Bool {
        !instances.isEmpty
    }

    @discardableResult
    static func terminateDuplicates() -> Int {
        let extras = instances.dropFirst()
        for app in extras { app.terminate() }
        return extras.count
    }

    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(SharedConfig.helperLabel).plist")
    }

    static var launchesAtLogin: Bool {
        loginService.status == .enabled || loginService.status == .requiresApproval
            || FileManager.default.fileExists(atPath: agentURL.path)
    }

    private static var loginService: SMAppService { .loginItem(identifier: SharedConfig.helperBundleID) }

    static var needsLoginApproval: Bool { loginService.status == .requiresApproval }

    static func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

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
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: label) {
                app.terminate()
            }
        }
    }

    static func start(completion: (@Sendable (Result<Void, Error>) -> Void)? = nil) {
        guard let helperURL else {
            completion?(.failure(HelperError.notEmbedded))
            return
        }
        terminateDuplicates()
        guard !isRunning else {
            completion?(.success(()))
            return
        }
        if launchesAtLogin,
            launchctl(["kickstart", "gui/\(getuid())/\(SharedConfig.helperLabel)"]) == 0
        {
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
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: SharedConfig.helperBundleID) {
            app.terminate()
        }
    }

    static func setLaunchAtLogin(_ enabled: Bool) throws {
        guard helperURL != nil else { throw HelperError.notEmbedded }
        if enabled {
            try loginService.register()
            migrateLegacyLoginItems()
            try removeLegacyAgent()
        } else {
            if loginService.status != .notRegistered { try loginService.unregister() }
            try removeLegacyAgent()
        }
    }

    private static func removeLegacyAgent() throws {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return }
        launchctl(["bootout", "gui/\(getuid())/\(SharedConfig.helperLabel)"])
        try FileManager.default.removeItem(at: agentURL)
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        Shell.run(SystemPaths.launchctl, arguments).status
    }
}
