import AppKit
import Foundation

struct SpotlightFolder: Identifiable, Hashable {
    let path: String

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

enum SpotlightError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Authorization was cancelled."
        case .failed(let m): return m
        }
    }
}

enum SpotlightManager {
    static func loadExclusions() throws -> [String] {
        let out = try runPrivileged("/usr/bin/mdutil -P /")
        if out.range(of: "must be root", options: .caseInsensitive) != nil {
            throw SpotlightError.failed("Reading the Spotlight configuration needs administrator rights.")
        }
        return try parseExclusions(out)
    }

    static func openPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Spotlight-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.spotlight",
            "x-apple.systempreferences:com.apple.Siri-Settings.extension",
        ]
        for c in candidates {
            if let url = URL(string: c), NSWorkspace.shared.open(url) { return }
        }
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }

    static func parseExclusions(_ output: String) throws -> [String] {
        var result: [String] = []
        var inBlock = false
        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if !inBlock {
                if line.contains("Exclusions") && line.contains("[") { inBlock = true }
                continue
            }
            if line.hasPrefix("]") { break }
            if let path = quotedValue(line) ?? bareValue(line) {
                result.append(path)
            }
        }
        guard inBlock else {
            throw SpotlightError.failed("macOS returned an unrecognized privacy list. No exclusions were changed.")
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func quotedValue(_ line: String) -> String? {
        guard let first = line.firstIndex(of: "\""),
            let last = line.lastIndex(of: "\""),
            first < last
        else { return nil }
        let v = String(line[line.index(after: first)..<last])
        return v.hasPrefix("/") ? v : nil
    }

    private static func bareValue(_ line: String) -> String? {
        if let arrow = line.range(of: "=>") {
            let v = line[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
            return v.hasPrefix("/") ? v : nil
        }
        return line.hasPrefix("/") ? line : nil
    }

    private static func runPrivileged(_ command: String) throws -> String {
        let script = "do shell script \(Shell.appleScriptLiteral(command)) with administrator privileges"
        let result = Shell.run(SystemPaths.osascript, ["-e", script], timeout: 180)

        guard result.succeeded else {
            if Shell.indicatesCancellation(result.combined) {
                throw SpotlightError.cancelled
            }
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SpotlightError.failed(message.isEmpty ? "osascript exited \(result.status)" : message)
        }
        return result.stdout
    }

}
