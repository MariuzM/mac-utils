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

enum LaunchDaemon {
    static let label = "dev.marius.macutils.rekey"
    static let installPath = "/Library/LaunchDaemons/dev.marius.macutils.rekey.plist"

    static let legacyLabels = ["mariuzm.rekey", "dev.marius.rekey", "dev.marius.macosutility.rekey"]

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
        let stagingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: stagingDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }
        let stagingURL = stagingDirectory.appendingPathComponent("\(label).plist")
        try content.write(to: stagingURL, options: .atomic)

        let steps =
            legacyRemovalSteps() + [
                "cp \(Shell.quote(stagingURL.path)) \(Shell.quote(installPath))",
                "chown root:wheel \(Shell.quote(installPath))",
                "chmod 644 \(Shell.quote(installPath))",
                "(launchctl bootout system/\(label) 2>/dev/null || true)",
                "launchctl bootstrap system \(Shell.quote(installPath))",
            ]
        try runPrivileged(steps.joined(separator: " && "))
    }

    static func uninstall() throws {
        let steps =
            legacyRemovalSteps() + [
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
        let result = Shell.run(SystemPaths.osascript, ["-e", source], timeout: 180)
        guard result.succeeded else {
            if Shell.indicatesCancellation(result.combined) { throw LaunchDaemonError.cancelled }
            throw LaunchDaemonError.failed(
                result.combined.isEmpty ? "Authorization failed (\(result.status))." : result.combined)
        }
    }
}
