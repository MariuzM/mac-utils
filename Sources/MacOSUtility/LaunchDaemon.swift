import Foundation

enum LaunchDaemonError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Authorization cancelled"
        case .failed(let message): return message
        }
    }
}

@MainActor
enum LaunchDaemon {
    static let label = "mariuzm.rekey"
    static let installPath = "/Library/LaunchDaemons/mariuzm.rekey.plist"

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installPath)
    }

    static func isStale(for mappings: [KeyMapping]) -> Bool {
        guard let installed = try? String(contentsOfFile: installPath, encoding: .utf8) else { return false }
        return installed != Hidutil.launchDaemonPlist(for: mappings, label: label)
    }

    static func install(_ mappings: [KeyMapping]) throws {
        let content = Hidutil.launchDaemonPlist(for: mappings, label: label)
        let stagingURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(label).plist")
        try content.write(to: stagingURL, atomically: true, encoding: .utf8)
        try runPrivileged("cp '\(stagingURL.path)' '\(installPath)' && chown root:wheel '\(installPath)' && chmod 644 '\(installPath)' && (launchctl bootout system/\(label) 2>/dev/null || true) && launchctl bootstrap system '\(installPath)'")
    }

    static func uninstall() throws {
        try runPrivileged("launchctl bootout system/\(label) 2>/dev/null || true; rm -f '\(installPath)'")
    }

    private static func runPrivileged(_ command: String) throws {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        guard let script = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges") else {
            throw LaunchDaemonError.failed("Could not build install script")
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            if errorInfo[NSAppleScript.errorNumber] as? Int == -128 {
                throw LaunchDaemonError.cancelled
            }
            throw LaunchDaemonError.failed(errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error")
        }
    }
}
