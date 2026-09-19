import Foundation

enum LaunchItemError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: "Authorization was cancelled."
        case .failed(let message): message
        }
    }
}

enum LaunchItemCatalog {
    static let pluginkit = "/usr/bin/pluginkit"

    static func loadItems() -> [LaunchItem] {
        var result: [LaunchItem] = []
        for scope in LaunchScope.allCases {
            let disabled = disabledLabels(domain: scope.domain)
            let files = (try? FileManager.default.contentsOfDirectory(atPath: scope.directory)) ?? []
            for file in files.sorted() where file.hasSuffix(".plist") {
                let path = scope.directory + "/" + file
                guard let data = FileManager.default.contents(atPath: path),
                    let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                        as? [String: Any],
                    let label = plist["Label"] as? String
                else { continue }
                let program = (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
                let keepsAlive = (plist["KeepAlive"] as? Bool) ?? (plist["KeepAlive"] is [String: Any])
                result.append(
                    LaunchItem(
                        label: label, plistPath: path, program: program,
                        runsAtLoad: plist["RunAtLoad"] as? Bool ?? false, keepsAlive: keepsAlive,
                        scope: scope, isDisabled: disabled.contains(label),
                        state: state(target: "\(scope.domain)/\(label)")))
            }
        }
        return result
    }

    static func loadFinderExtensions() -> [FinderExtension] {
        let result = Shell.run(pluginkit, ["-m", "-A", "-v", "-p", "com.apple.FinderSync"])
        guard result.succeeded else { return [] }
        return result.stdout.split(separator: "\n").compactMap(parseExtension)
            .sorted { $0.parentAppName.localizedCaseInsensitiveCompare($1.parentAppName) == .orderedAscending }
    }

    static func setEnabled(_ enabled: Bool, item: LaunchItem) throws {
        let launchctl = SystemPaths.launchctl
        let commands =
            enabled
            ? [
                [launchctl, "enable", item.target],
                [launchctl, "bootstrap", item.scope.domain, item.plistPath],
            ]
            : [
                [launchctl, "disable", item.target],
                [launchctl, "bootout", item.target],
            ]
        if item.scope.needsAdmin {
            let script =
                commands.map { $0.map(Shell.quote).joined(separator: " ") }.enumerated()
                .map { i, line in i == 0 ? line : "(\(line) 2>/dev/null || true)" }
                .joined(separator: " && ")
            try runPrivileged(script)
        } else {
            let first = Shell.run(commands[0][0], Array(commands[0].dropFirst()))
            guard first.succeeded else { throw LaunchItemError.failed(message(first)) }
            Shell.run(commands[1][0], Array(commands[1].dropFirst()))
        }
    }

    static func setEnabled(_ enabled: Bool, extension ext: FinderExtension) throws {
        let result = Shell.run(pluginkit, ["-e", enabled ? "use" : "ignore", "-i", ext.bundleID])
        guard result.succeeded else { throw LaunchItemError.failed(message(result)) }
    }

    static func disabledLabels(domain: String) -> Set<String> {
        let result = Shell.run(SystemPaths.launchctl, ["print-disabled", domain])
        var labels = Set<String>()
        for line in result.stdout.split(separator: "\n") {
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard value == "disabled" || value == "true" else { continue }
            labels.insert(parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "\" \t")))
        }
        return labels
    }

    static func state(target: String) -> LaunchItemState {
        let result = Shell.run(SystemPaths.launchctl, ["print", target], timeout: 10)
        guard result.succeeded else { return .notLoaded }
        var state: String?
        var pid: Int?
        for line in result.stdout.split(separator: "\n") where line.hasPrefix("\t") && !line.hasPrefix("\t\t") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if state == nil, trimmed.hasPrefix("state = ") { state = String(trimmed.dropFirst(8)) }
            if pid == nil, trimmed.hasPrefix("pid = ") { pid = Int(trimmed.dropFirst(6)) }
        }
        return state == "running" ? .running(pid: pid) : .loaded
    }

    static func parseExtension(_ line: Substring) -> FinderExtension? {
        let fields = line.components(separatedBy: "\t")
        guard fields.count >= 4, let first = fields.first, first.count > 4 else { return nil }
        let marker = first.first
        let identity = first.trimmingCharacters(in: CharacterSet(charactersIn: "+-=! "))
        guard let open = identity.lastIndex(of: "("), identity.hasSuffix(")") else { return nil }
        let election: ExtensionElection =
            switch marker {
            case "+": .enabled
            case "-": .disabled
            default: .systemDefault
            }
        return FinderExtension(
            bundleID: String(identity[..<open]),
            version: String(identity[identity.index(after: open)..<identity.index(before: identity.endIndex)]),
            path: fields[3], election: election)
    }

    private static func message(_ result: ShellResult) -> String {
        let text = result.combined.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "The command failed (exit \(result.status))." : text
    }

    private static func runPrivileged(_ command: String) throws {
        let source = "do shell script \(Shell.appleScriptLiteral(command)) with administrator privileges"
        let result = Shell.run(SystemPaths.osascript, ["-e", source], timeout: 180)
        guard result.succeeded else {
            if Shell.indicatesCancellation(result.combined) { throw LaunchItemError.cancelled }
            throw LaunchItemError.failed(message(result))
        }
    }
}
