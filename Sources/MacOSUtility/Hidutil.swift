import Foundation

enum HidutilError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let output): return "hidutil failed: \(output)"
        }
    }
}

enum Hidutil {
    static func payload(for mappings: [KeyMapping]) -> String {
        let entries = mappings.map { m in
            "{\"HIDKeyboardModifierMappingSrc\":0x\(String(m.source.usage, radix: 16, uppercase: true)),\"HIDKeyboardModifierMappingDst\":0x\(String(m.destination.usage, radix: 16, uppercase: true))}"
        }
        return "{\"UserKeyMapping\":[\(entries.joined(separator: ","))]}"
    }

    static func apply(_ mappings: [KeyMapping]) throws {
        try run(["property", "--set", payload(for: mappings)])
    }

    static func reset() throws {
        try run(["property", "--set", "{\"UserKeyMapping\":[]}"])
    }

    static func launchDaemonPlist(for mappings: [KeyMapping], label: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/hidutil</string>
                <string>property</string>
                <string>--set</string>
                <string>\(payload(for: mappings).replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;"))</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }

    @discardableResult
    private static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw HidutilError.commandFailed(output)
        }
        return output
    }
}
