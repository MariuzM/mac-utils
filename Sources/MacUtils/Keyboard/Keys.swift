import Foundation

struct Key: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let usage: UInt64

    var id: UInt64 { usage }
}

enum Keys {
    private static let keyboardPage: UInt64 = 0x7_0000_0000
    private static let consumerPage: UInt64 = 0xC_0000_0000

    static let sources: [Key] = [
        Key(name: "F1", usage: keyboardPage | 0x3A),
        Key(name: "F2", usage: keyboardPage | 0x3B),
        Key(name: "F3", usage: keyboardPage | 0x3C),
        Key(name: "F4", usage: keyboardPage | 0x3D),
        Key(name: "F5", usage: keyboardPage | 0x3E),
        Key(name: "F6", usage: keyboardPage | 0x3F),
        Key(name: "F7", usage: keyboardPage | 0x40),
        Key(name: "F8", usage: keyboardPage | 0x41),
        Key(name: "F9", usage: keyboardPage | 0x42),
        Key(name: "F10", usage: keyboardPage | 0x43),
        Key(name: "F11", usage: keyboardPage | 0x44),
        Key(name: "F12", usage: keyboardPage | 0x45),
        Key(name: "Caps Lock", usage: keyboardPage | 0x39),
        Key(name: "Escape", usage: keyboardPage | 0x29),
        Key(name: "Right Option", usage: keyboardPage | 0xE6),
        Key(name: "Right Command", usage: keyboardPage | 0xE7),
    ]

    static let destinations: [Key] =
        [
            Key(name: "Brightness Down", usage: consumerPage | 0x70),
            Key(name: "Brightness Up", usage: consumerPage | 0x6F),
            Key(name: "Mute", usage: consumerPage | 0xE2),
            Key(name: "Volume Down", usage: consumerPage | 0xEA),
            Key(name: "Volume Up", usage: consumerPage | 0xE9),
            Key(name: "Play / Pause", usage: consumerPage | 0xCD),
            Key(name: "Next Track", usage: consumerPage | 0xB5),
            Key(name: "Previous Track", usage: consumerPage | 0xB6),
        ] + sources
}
