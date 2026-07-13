import Foundation

@MainActor
final class MappingStore: ObservableObject {
    @Published var mappings: [KeyMapping] = [] {
        didSet {
            save()
            refreshStartupState()
        }
    }
    @Published var status: String?
    @Published var startupEnabled = false
    @Published var startupStale = false

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
        mappings.append(KeyMapping(source: Keys.sources[0], destination: Keys.destinations[0]))
    }

    func remove(_ mapping: KeyMapping) {
        mappings.removeAll { $0.id == mapping.id }
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

    private func refreshStartupState() {
        startupEnabled = LaunchDaemon.isInstalled
        startupStale = startupEnabled && LaunchDaemon.isStale(for: mappings)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([KeyMapping].self, from: data)
        else {
            mappings = Self.defaultMappings
            return
        }
        mappings = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        try? data.write(to: fileURL)
    }
}
