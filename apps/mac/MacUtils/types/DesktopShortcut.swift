import Foundation

struct ShortcutKey: Hashable, Identifiable, Sendable {
    let name: String
    let code: UInt16
    let character: UInt16

    var id: UInt16 { code }
    var isFunctionKey: Bool { character == ShortcutKey.noCharacter }

    static let noCharacter: UInt16 = 0xFFFF

    static let functionKeys: [Self] = [
        (1, 122), (2, 120), (3, 99), (4, 118), (5, 96), (6, 97),
        (7, 98), (8, 100), (9, 101), (10, 109), (11, 103), (12, 111),
    ].map { Self(name: "F\($0.0)", code: $0.1, character: noCharacter) }

    static let numberKeys: [Self] = [
        ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23),
        ("6", 22), ("7", 26), ("8", 28), ("9", 25), ("0", 29),
    ].map { Self(name: $0.0, code: $0.1, character: UInt16($0.0.unicodeScalars.first!.value)) }

    static let all = numberKeys + functionKeys

    static func resolve(code: UInt16, character: UInt16) -> Self {
        all.first { $0.code == code } ?? Self(name: "Key \(code)", code: code, character: character)
    }
}

struct ShortcutModifiers: Hashable, Identifiable, Sendable {
    let rawValue: UInt32

    var id: UInt32 { rawValue }

    static let shift: UInt32 = 0x20000
    static let control: UInt32 = 0x40000
    static let option: UInt32 = 0x80000
    static let command: UInt32 = 0x100000
    static let function: UInt32 = 0x800000
    static let mask = shift | control | option | command

    static let presets: [Self] = [
        control, option, command, control | option, control | command, option | command,
    ].map(Self.init)

    var symbols: String {
        [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")]
            .filter { rawValue & $0.0 != 0 }
            .map(\.1)
            .joined()
    }
}

struct DesktopShortcut: Hashable, Identifiable, Sendable {
    let desktop: Int
    var enabled: Bool
    var modifiers: ShortcutModifiers
    var key: ShortcutKey

    var id: Int { desktop }
    var hotKeyID: Int32 { Int32(117 + desktop) }
    var label: String { modifiers.symbols + key.name }

    static let maxDesktops = 16

    static func fallback(for desktop: Int) -> Self {
        let keys = desktop <= 10 ? ShortcutKey.numberKeys : ShortcutKey.functionKeys
        let key = keys[(desktop - 1) % 10]
        return Self(desktop: desktop, enabled: false, modifiers: ShortcutModifiers(rawValue: ShortcutModifiers.control), key: key)
    }
}

enum DesktopShortcutPreset: String, CaseIterable, Identifiable {
    case controlNumber, optionNumber, commandFunction, controlFunction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlNumber: "⌃ + Number"
        case .optionNumber: "⌥ + Number"
        case .commandFunction: "⌘ + F-key"
        case .controlFunction: "⌃ + F-key"
        }
    }

    var modifiers: ShortcutModifiers {
        switch self {
        case .controlNumber, .controlFunction: ShortcutModifiers(rawValue: ShortcutModifiers.control)
        case .optionNumber: ShortcutModifiers(rawValue: ShortcutModifiers.option)
        case .commandFunction: ShortcutModifiers(rawValue: ShortcutModifiers.command)
        }
    }

    var keys: [ShortcutKey] {
        switch self {
        case .controlNumber, .optionNumber: ShortcutKey.numberKeys
        case .commandFunction, .controlFunction: ShortcutKey.functionKeys
        }
    }
}
