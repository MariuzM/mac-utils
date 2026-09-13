import Foundation

actor SiriController {
    private let system: any SiriSystem
    private let backupURL: URL
    private var busy = false

    init(system: any SiriSystem = LocalSiriSystem(), backupURL: URL? = nil) {
        self.system = system
        self.backupURL =
            backupURL
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Mac Utils/siri-restore.json")
    }

    func hasBackup() -> Bool { FileManager.default.fileExists(atPath: backupURL.path) }

    private var domain: String { "gui/\(system.userID)" }

    func inspect() async throws -> SiriSnapshot {
        let result = await system.command(["print-disabled", domain])
        guard result.succeeded else { throw failure("Read startup settings", result) }
        let overrides = Self.parseDisabled(result.stdout)
        var states: [SiriServiceState] = []
        for service in SiriService.catalog where system.installed(service) {
            let state = await system.command(["print", "\(domain)/\(service.id)"])
            guard state.succeeded || state.status == 113 else { throw failure("Check \(service.name)", state) }
            states.append(
                SiriServiceState(
                    service: service, disabled: overrides[service.id] == true,
                    running: Self.isRunning(state.stdout), loaded: state.succeeded))
        }
        let settingsOff = try SiriPreference.catalog.allSatisfy { preference in
            guard let data = try system.preference(preference),
                let object = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                let value = object["value"] as? NSNumber,
                CFGetTypeID(value) == CFBooleanGetTypeID()
            else { return false }
            return !value.boolValue
        }
        return SiriSnapshot(checkedAt: Date(), settingsOff: settingsOff, services: states)
    }

    func disable() async throws -> SiriOperation {
        guard !busy else { throw SiriError.failed("A Siri operation is already running.") }
        busy = true
        defer { busy = false }
        let before = try await inspect()
        guard !before.services.isEmpty else {
            throw SiriError.failed("No supported Siri services were found on this Mac.")
        }
        if hasBackup() {
            _ = try readBackup()
        } else {
            let backup = SiriBackup(
                version: 1, userID: system.userID, createdAt: Date(),
                preferences: try SiriPreference.catalog.map { .init(id: $0.id, value: try system.preference($0)) },
                services: before.services.map { .init(id: $0.id, disabled: $0.disabled, running: $0.running) })
            try FileManager.default.createDirectory(
                at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(backup).write(to: backupURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
        }

        var details: [String] = []
        let off = try PropertyListSerialization.data(fromPropertyList: ["value": false], format: .binary, options: 0)
        for preference in SiriPreference.catalog {
            do { try system.setPreference(preference, value: off) } catch let e {
                details.append(e.localizedDescription)
            }
        }
        for state in before.services {
            let target = "\(domain)/\(state.id)"
            let disabled = await system.command(["disable", target])
            guard disabled.succeeded else {
                details.append(failure("Disable \(state.service.name)", disabled).localizedDescription)
                continue
            }
            if state.loaded {
                let unloaded = await system.command(["bootout", target])
                if !unloaded.succeeded && unloaded.status != 113 {
                    do { try system.stop(state.service) } catch let e { details.append(e.localizedDescription) }
                }
            }
        }
        try await Task.sleep(for: .seconds(2))
        let after = try await inspect()
        if after.restartNeeded {
            details.append("Startup is blocked. Sign out and back in, then recheck the remaining services.")
        }
        if !after.fullyDisabled && !after.restartNeeded {
            details.append("Some controls could not be disabled. Review the status below and retry.")
        }
        return SiriOperation(snapshot: after, details: details)
    }

    func restore() async throws -> SiriOperation {
        guard !busy else { throw SiriError.failed("A Siri operation is already running.") }
        busy = true
        defer { busy = false }
        let backup = try readBackup()
        var details: [String] = []
        for saved in backup.preferences {
            guard let preference = SiriPreference.catalog.first(where: { $0.id == saved.id }) else { continue }
            do { try system.setPreference(preference, value: saved.value) } catch let e {
                details.append(e.localizedDescription)
            }
        }
        for saved in backup.services {
            guard let service = SiriService.catalog.first(where: { $0.id == saved.id }), system.installed(service)
            else { continue }
            let result = await system.command([saved.disabled ? "disable" : "enable", "\(domain)/\(service.id)"])
            if !result.succeeded { details.append(failure("Restore \(service.name)", result).localizedDescription) }
            if !saved.disabled && saved.running {
                let current = await system.command(["print", "\(domain)/\(service.id)"])
                let started = await system.command(
                    current.status == 113
                        ? ["bootstrap", domain, service.plistPath]
                        : ["kickstart", "\(domain)/\(service.id)"])
                if !started.succeeded { details.append("\(service.name) will need a new login session to restart.") }
            }
        }
        let snapshot = try await inspect()
        for saved in backup.preferences {
            guard let preference = SiriPreference.catalog.first(where: { $0.id == saved.id }) else { continue }
            if try system.preference(preference) != saved.value {
                details.append("Could not verify restoration of \(preference.key).")
            }
        }
        for saved in backup.services {
            if let state = snapshot.services.first(where: { $0.id == saved.id }), state.disabled != saved.disabled {
                details.append("Could not verify the original startup state for \(state.service.name).")
            }
        }
        if details.isEmpty { try FileManager.default.removeItem(at: backupURL) }
        return SiriOperation(snapshot: snapshot, details: details)
    }

    private func readBackup() throws -> SiriBackup {
        let saved = try JSONDecoder().decode(SiriBackup.self, from: Data(contentsOf: backupURL))
        guard saved.version == 1, saved.userID == system.userID,
            Set(saved.preferences.map(\.id)) == Set(SiriPreference.catalog.map(\.id)),
            saved.preferences.count == SiriPreference.catalog.count,
            Set(saved.services.map(\.id)).count == saved.services.count,
            !saved.services.isEmpty,
            saved.services.allSatisfy({ entry in SiriService.catalog.contains { $0.id == entry.id } })
        else {
            throw SiriError.failed(
                "The Siri restore snapshot is invalid or belongs to another user. It was left untouched.")
        }
        return saved
    }

    static func parseDisabled(_ text: String) -> [String: Bool] {
        var values: [String: Bool] = [:]
        for line in text.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(
                in: CharacterSet(charactersIn: "\""))
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if value == "disabled" { values[key] = true }
            if value == "enabled" { values[key] = false }
        }
        return values
    }

    static func isRunning(_ text: String) -> Bool {
        text.components(separatedBy: .newlines).contains {
            $0.trimmingCharacters(in: .whitespaces) == "state = running"
        }
    }

    private func failure(_ action: String, _ result: ShellResult) -> SiriError {
        let message = result.combined.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failed("\(action): \(message.isEmpty ? "exit \(result.status)" : String(message.prefix(500)))")
    }
}
