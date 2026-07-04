import Foundation
import AppKit

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
        let script = """
        #!/bin/sh
        /usr/bin/mdutil -P / 2>&1 || true
        """
        let out = try runPrivileged(script)
        if out.range(of: "must be root", options: .caseInsensitive) != nil {
            throw SpotlightError.failed("Reading the Spotlight configuration needs administrator rights.")
        }
        return parseExclusions(out)
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

    static func normalize(_ path: String) -> String {
        var p = URL(fileURLWithPath: path).standardizedFileURL.path
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    private static func parseExclusions(_ output: String) -> [String] {
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
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func quotedValue(_ line: String) -> String? {
        guard let first = line.firstIndex(of: "\""),
              let last = line.lastIndex(of: "\""),
              first < last else { return nil }
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

    private static func shq(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runPrivileged(_ script: String) throws -> String {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("macosutility-\(UUID().uuidString).sh")
        try script.write(to: tmp, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tmp.path)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let osa = Process()
        osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osa.arguments = ["-e", "do shell script \"/bin/sh \" & quoted form of \(appleQuote(tmp.path)) with administrator privileges"]

        let outPipe = Pipe()
        let errPipe = Pipe()
        osa.standardOutput = outPipe
        osa.standardError = errPipe
        try osa.run()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        osa.waitUntilExit()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""

        if osa.terminationStatus != 0 {
            if err.contains("-128") || err.localizedCaseInsensitiveContains("cancel") {
                throw SpotlightError.cancelled
            }
            throw SpotlightError.failed(err.isEmpty ? "osascript exited \(osa.terminationStatus)" : err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return out
    }

    private static func appleQuote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
