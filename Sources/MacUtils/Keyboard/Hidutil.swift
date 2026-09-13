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

    static func launchDaemonArguments(for mappings: [KeyMapping]) -> [String] {
        [SystemPaths.hidutil, "property", "--set", payload(for: mappings)]
    }

    static func launchDaemonPlist(for mappings: [KeyMapping], label: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": launchDaemonArguments(for: mappings),
            "RunAtLoad": true,
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    @discardableResult
    private static func run(_ arguments: [String]) throws -> String {
        let result = Shell.run(SystemPaths.hidutil, arguments)
        guard result.succeeded else {
            throw HidutilError.commandFailed(result.combined.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result.stdout
    }
}
