import Foundation

enum SymbolicHotKeys {
    private static var domain: CFString { "com.apple.symbolichotkeys" as CFString }
    private static var key: CFString { "AppleSymbolicHotKeys" as CFString }
    private static var spacesDomain: CFString { "com.apple.spaces" as CFString }

    private typealias SetValue = @convention(c) (Int32, UInt16, UInt16, UInt32) -> Int32
    private typealias SetEnabled = @convention(c) (Int32, Bool) -> Int32

    private static let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"

    static func desktopShortcuts(count: Int) -> [DesktopShortcut] {
        let entries = readAll()
        return (1...max(1, min(count, DesktopShortcut.maxDesktops))).map { desktop in
            let fallback = DesktopShortcut.fallback(for: desktop)
            guard let entry = entries[String(fallback.hotKeyID)] as? [String: Any] else { return fallback }
            let enabled = (entry["enabled"] as? NSNumber)?.boolValue ?? false
            guard let value = entry["value"] as? [String: Any],
                let parameters = (value["parameters"] as? [NSNumber])?.map(\.intValue),
                parameters.count == 3
            else { return DesktopShortcut(desktop: desktop, enabled: enabled, modifiers: fallback.modifiers, key: fallback.key) }
            return DesktopShortcut(
                desktop: desktop,
                enabled: enabled,
                modifiers: ShortcutModifiers(rawValue: UInt32(truncatingIfNeeded: parameters[2]) & ShortcutModifiers.mask),
                key: ShortcutKey.resolve(
                    code: UInt16(truncatingIfNeeded: parameters[1]), character: UInt16(truncatingIfNeeded: parameters[0]))
            )
        }
    }

    static func configuredDesktopCount() -> Int {
        let entries = readAll()
        return (1...DesktopShortcut.maxDesktops).last { desktop in
            let entry = entries[String(117 + desktop)] as? [String: Any]
            return (entry?["enabled"] as? NSNumber)?.boolValue == true
        } ?? 0
    }

    static func save(_ shortcut: DesktopShortcut) throws {
        var entries = readAll()
        let modifiers = shortcut.modifiers.rawValue | (shortcut.key.isFunctionKey ? ShortcutModifiers.function : 0)
        entries[String(shortcut.hotKeyID)] = [
            "enabled": shortcut.enabled,
            "value": [
                "type": "standard",
                "parameters": [Int(shortcut.key.character), Int(shortcut.key.code), Int(modifiers)],
            ],
        ]
        CFPreferencesSetAppValue(key, entries as CFDictionary, domain)
        guard CFPreferencesAppSynchronize(domain) else { throw SymbolicHotKeyError.saveFailed }

        if let setValue = function("CGSSetSymbolicHotKeyValue", as: SetValue.self),
            let setEnabled = function("CGSSetSymbolicHotKeyEnabled", as: SetEnabled.self)
        {
            _ = setValue(shortcut.hotKeyID, shortcut.key.character, shortcut.key.code, modifiers)
            _ = setEnabled(shortcut.hotKeyID, shortcut.enabled)
        } else {
            Shell.run(SystemPaths.activateSettings, ["-u"])
        }
    }

    static func desktopCount() -> Int? {
        guard let config = CFPreferencesCopyAppValue("SpacesDisplayConfiguration" as CFString, spacesDomain)
            as? [String: Any],
            let management = config["Management Data"] as? [String: Any],
            let monitors = management["Monitors"] as? [[String: Any]]
        else { return nil }
        let counts = monitors.map { monitor in
            (monitor["Spaces"] as? [[String: Any]] ?? []).filter { ($0["type"] as? NSNumber)?.intValue == 0 }.count
        }
        return counts.max().flatMap { $0 > 0 ? $0 : nil }
    }

    static func restartDock() throws {
        let result = Shell.run(SystemPaths.killall, ["Dock"])
        guard result.succeeded else {
            throw SymbolicHotKeyError.dockRestartFailed(result.combined.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func readAll() -> [String: Any] {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key, domain) as? [String: Any] ?? [:]
    }

    private static func function<T>(_ name: String, as type: T.Type) -> T? {
        guard let skyLight = dlopen(skyLightPath, RTLD_NOW), let symbol = dlsym(skyLight, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }
}

enum SymbolicHotKeyError: LocalizedError {
    case saveFailed
    case dockRestartFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed: "Could not save the keyboard shortcut preferences."
        case .dockRestartFailed(let message): message.isEmpty ? "Could not restart the Dock." : message
        }
    }
}
