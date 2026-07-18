import Foundation

@MainActor
final class MappingStore: ObservableObject {
    @Published var mappings: [KeyMapping] = []
    @Published var status: String?
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
            parts.append("Duplicate source keys (only the last takes effect): \(duplicateSources.joined(separator: ", "))")
        }
        if !selfMappings.isEmpty {
            parts.append("Keys mapped to themselves: \(selfMappings.joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    func apply() {
        do {
            try Hidutil.apply(mappings)
            status = "Applied \(mappings.count) mapping\(mappings.count == 1 ? "" : "s")"
        } catch let e {
            status = e.localizedDescription
        }
    }

    func resetSystemMappings() {
        do {
            try Hidutil.reset()
            status = "System mappings cleared"
        } catch let e {
            status = e.localizedDescription
        }
    }

    func setStartup(_ enabled: Bool) {
        do {
            if enabled {
                try LaunchDaemon.install(mappings)
                status = "Startup daemon installed — mappings now apply at every boot"
            } else {
                try LaunchDaemon.uninstall()
                status = "Startup daemon removed"
            }
        } catch let e {
            status = e.localizedDescription
        }
        refreshStartupState()
    }

    func updateStartup() {
        do {
            try LaunchDaemon.install(mappings)
            status = "Startup mappings updated"
        } catch let e {
            status = e.localizedDescription
        }
        refreshStartupState()
    }

    func removeLegacyDaemon() {
        do {
            try LaunchDaemon.removeLegacyDaemons()
            status = "Removed the old rekey daemon"
        } catch let e {
            status = e.localizedDescription
        }
        refreshStartupState()
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
            status = "Saved mappings could not be read. The existing file is left untouched — "
                + "fix or remove it before editing, or it will be overwritten."
            return
        }
        let usable = decoded.compactMap(\.mapping)
        if usable.count < decoded.count {
            status = "\(decoded.count - usable.count) saved mapping(s) referenced keys this version no longer knows and were dropped."
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
            try data.write(to: fileURL)
        } catch {
            status = "Could not save mappings: \(error.localizedDescription)"
        }
    }
}
