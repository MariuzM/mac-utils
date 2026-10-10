import Foundation

@MainActor
final class DesktopShortcutStore: ObservableObject {
    @Published private(set) var shortcuts: [DesktopShortcut] = []
    @Published private(set) var desktopCount: Int?
    @Published var status: String?

    init() {
        reload()
    }

    func reload() {
        let count = SymbolicHotKeys.desktopCount()
        desktopCount = count
        shortcuts = SymbolicHotKeys.desktopShortcuts(count: max(count ?? 3, SymbolicHotKeys.configuredDesktopCount()))
    }

    func exists(_ shortcut: DesktopShortcut) -> Bool {
        guard let desktopCount else { return true }
        return shortcut.desktop <= desktopCount
    }

    func update(_ shortcut: DesktopShortcut) {
        guard let i = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[i] = shortcut
        do {
            try SymbolicHotKeys.save(shortcut)
            status =
                shortcut.enabled
                ? "Desktop \(shortcut.desktop) switches with \(shortcut.label)"
                : "Desktop \(shortcut.desktop) shortcut turned off"
        } catch let e {
            status = e.localizedDescription
        }
    }

    func apply(_ preset: DesktopShortcutPreset) {
        do {
            for i in shortcuts.indices where i < preset.keys.count {
                shortcuts[i].modifiers = preset.modifiers
                shortcuts[i].key = preset.keys[i]
                shortcuts[i].enabled = true
                try SymbolicHotKeys.save(shortcuts[i])
            }
            status = "Desktops now switch with \(preset.title)"
        } catch let e {
            status = e.localizedDescription
        }
    }

    func restartDock() {
        do {
            try SymbolicHotKeys.restartDock()
            status = "Dock restarted"
        } catch let e {
            status = e.localizedDescription
        }
    }

    func warning(remappedKeys: Set<String>) -> String? {
        let enabled = shortcuts.filter(\.enabled)
        var parts: [String] = []

        let duplicates = Dictionary(grouping: enabled, by: \.label).filter { $0.value.count > 1 }.keys.sorted()
        if !duplicates.isEmpty {
            parts.append("Several desktops share the same shortcut: \(duplicates.joined(separator: ", "))")
        }

        let remapped = enabled.map(\.key.name).filter(remappedKeys.contains)
        if !remapped.isEmpty {
            parts.append(
                "Keys remapped under Mappings can't trigger desktop shortcuts: \(remapped.joined(separator: ", "))")
        }

        if enabled.contains(where: \.key.isFunctionKey),
            !UserDefaults.standard.bool(forKey: "com.apple.keyboard.fnState")
        {
            parts.append("F1–F12 act as media keys on this Mac, so hold fn as well for F-key shortcuts.")
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
}
