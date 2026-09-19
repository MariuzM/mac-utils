import Foundation

@MainActor
final class MappingStore: ObservableObject {
    @Published var mappings: [KeyMapping] = []
    @Published var status: String?
    @Published private(set) var isWorking = false
    @Published var startupEnabled = false
    @Published var startupStale = false
    @Published var hasLegacyDaemon = false

    private var unreadableOnDisk = false

    func commit() {
        save()
        refreshStartupState()
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Rekey", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mappings.json")
    }()

    init() {
        load()
        refreshStartupState()
    }

    private static let defaultMappings: [KeyMapping] = [
        ("F5", "Brightness Down"),
        ("F6", "Brightness Up"),
        ("F10", "Mute"),
        ("F11", "Volume Down"),
        ("F12", "Volume Up"),
    ].compactMap { sourceName, destinationName in
        guard let source = Keys.sources.first(where: { $0.name == sourceName }),
            let destination = Keys.destinations.first(where: { $0.name == destinationName })
        else { return nil }
        return KeyMapping(source: source, destination: destination)
    }

    func add() {
        let used = Set(mappings.map(\.source.usage))
        let source = Keys.sources.first { !used.contains($0.usage) } ?? Keys.sources[0]
        let destination = Keys.destinations.first { $0.usage != source.usage } ?? Keys.destinations[0]
        mappings.append(KeyMapping(source: source, destination: destination))
        commit()
    }

    func remove(_ mapping: KeyMapping) {
        mappings.removeAll { $0.id == mapping.id }
        commit()
    }

    var duplicateSources: [String] {
        Dictionary(grouping: mappings, by: \.source.usage)
            .filter { $0.value.count > 1 }
            .compactMap { $0.value.first?.source.name }
            .sorted()
    }

    var selfMappings: [String] {
        mappings.filter { $0.source.usage == $0.destination.usage }.map(\.source.name).sorted()
    }

    var conflictWarning: String? {
        var parts: [String] = []
        if !duplicateSources.isEmpty {
            parts.append(
                "Choose a unique source for each mapping: \(duplicateSources.joined(separator: ", "))")
        }
        if !selfMappings.isEmpty {
            parts.append("Keys mapped to themselves: \(selfMappings.joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    func apply() {
        guard conflictWarning == nil else {
            status = conflictWarning
            return
        }
        let values = mappings
        perform {
            try Hidutil.apply(values)
            return "Applied \(values.count) mappings"
        }
    }

    func resetSystemMappings() {
        perform {
            try Hidutil.reset()
            return "System mappings cleared"
        }
    }

    func setStartup(_ enabled: Bool) {
        guard !enabled || conflictWarning == nil else {
            status = conflictWarning
            return
        }
        let values = mappings
        perform {
            if enabled {
                try LaunchDaemon.install(values)
                return "Mappings will apply at every boot"
            }
            try LaunchDaemon.uninstall()
            return "Startup mappings removed"
        }
    }

    func updateStartup() { setStartup(true) }

    func removeLegacyDaemon() {
        perform {
            try LaunchDaemon.removeLegacyDaemons()
            return "Removed the old keyboard daemon"
        }
    }

    private func perform(_ operation: @escaping @Sendable () throws -> String) {
        guard !isWorking else { return }
        isWorking = true
        status = "Applying changes…"
        Task {
            do { status = try await Task.detached(priority: .userInitiated, operation: operation).value } catch let e {
                status = e.localizedDescription
            }
            isWorking = false
            refreshStartupState()
        }
    }

    private func refreshStartupState() {
        startupEnabled = LaunchDaemon.isInstalled
        startupStale = startupEnabled && LaunchDaemon.isStale(for: mappings)
        hasLegacyDaemon = !LaunchDaemon.installedLegacyLabels.isEmpty
    }

    private struct LossyMapping: Decodable {
        let mapping: KeyMapping?

        init(from decoder: Decoder) throws {
            mapping = try? KeyMapping(from: decoder)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            mappings = Self.defaultMappings
            return
        }
        guard let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([LossyMapping].self, from: data)
        else {
            unreadableOnDisk = true
            status =
                "Saved mappings could not be read. The existing file is left untouched — "
                + "fix or remove it before editing, or it will be overwritten."
            return
        }
        let usable = decoded.compactMap(\.mapping)
        if usable.count < decoded.count {
            status =
                "\(decoded.count - usable.count) saved mapping(s) referenced keys this version no longer knows and were dropped."
        }
        mappings = usable
    }

    private func save() {
        guard !unreadableOnDisk else {
            status = "Not saving — the existing mappings file could not be read. Fix or remove it first."
            return
        }
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            status = "Could not save mappings: \(error.localizedDescription)"
        }
    }
}
