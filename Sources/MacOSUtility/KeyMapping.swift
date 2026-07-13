import Foundation

struct KeyMapping: Codable, Hashable, Identifiable {
    var id: UUID
    var source: Key
    var destination: Key

    init(source: Key, destination: Key) {
        self.id = UUID()
        self.source = source
        self.destination = destination
    }
}
