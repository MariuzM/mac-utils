import Foundation

struct KeyMapping: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var source: Key
    var destination: Key

    init(source: Key, destination: Key) {
        self.id = UUID()
        self.source = source
        self.destination = destination
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, destination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()

        let sourceUsage = try Self.usage(from: container, forKey: .source)
        let destinationUsage = try Self.usage(from: container, forKey: .destination)

        guard let resolvedSource = Keys.sources.first(where: { $0.usage == sourceUsage }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .source, in: container,
                debugDescription: "Unknown source usage \(sourceUsage)")
        }
        guard let resolvedDestination = Keys.destinations.first(where: { $0.usage == destinationUsage }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .destination, in: container,
                debugDescription: "Unknown destination usage \(destinationUsage)")
        }
        source = resolvedSource
        destination = resolvedDestination
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source.usage, forKey: .source)
        try container.encode(destination.usage, forKey: .destination)
    }

    private static func usage(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> UInt64 {
        if let usage = try? container.decode(UInt64.self, forKey: key) { return usage }
        return try container.decode(Key.self, forKey: key).usage
    }
}
