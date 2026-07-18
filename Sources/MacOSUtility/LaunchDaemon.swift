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
    static let label = "dev.marius.macosutility.rekey"
    static let installPath = "/Library/LaunchDaemons/dev.marius.macosutility.rekey.plist"

    static let legacyLabels = ["mariuzm.rekey", "dev.marius.rekey"]

    private static func plistPath(for label: String) -> String {
        "/Library/LaunchDaemons/\(label).plist"
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installPath)
    }

    static var installedLegacyLabels: [String] {
        legacyLabels.filter { FileManager.default.fileExists(atPath: plistPath(for: $0)) }
    }

    static func isStale(for mappings: [KeyMapping]) -> Bool {
        guard let data = FileManager.default.contents(atPath: installPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let arguments = plist["ProgramArguments"] as? [String]
        else { return false }
        return arguments != Hidutil.launchDaemonArguments(for: mappings)
    }

    static func install(_ mappings: [KeyMapping]) throws {
        let content = try Hidutil.launchDaemonPlist(for: mappings, label: label)
        let stagingURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(label).plist")
        try content.write(to: stagingURL, options: .atomic)

        let steps = legacyRemovalSteps() + [
            "cp \(Shell.quote(stagingURL.path)) \(Shell.quote(installPath))",
            "chown root:wheel \(Shell.quote(installPath))",
            "chmod 644 \(Shell.quote(installPath))",
            "(launchctl bootout system/\(label) 2>/dev/null || true)",
            "launchctl bootstrap system \(Shell.quote(installPath))",
        ]
        try runPrivileged(steps.joined(separator: " && "))
    }

    static func uninstall() throws {
        let steps = legacyRemovalSteps() + [
            "(launchctl bootout system/\(label) 2>/dev/null || true)",
            "rm -f \(Shell.quote(installPath))",
        ]
        try runPrivileged(steps.joined(separator: " && "))
    }

    static func removeLegacyDaemons() throws {
        let steps = legacyRemovalSteps()
        guard !steps.isEmpty else { return }
        try runPrivileged(steps.joined(separator: " && "))
    }

    private static func legacyRemovalSteps() -> [String] {
        installedLegacyLabels.flatMap { legacy in
            [
                "(launchctl bootout system/\(legacy) 2>/dev/null || true)",
                "rm -f \(Shell.quote(plistPath(for: legacy)))",
            ]
        }
    }


    private static func runPrivileged(_ command: String) throws {
        let source = "do shell script \(Shell.appleScriptLiteral(command)) with administrator privileges"
        guard let script = NSAppleScript(source: source) else {
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
