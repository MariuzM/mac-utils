import SwiftUI

struct DesktopShortcutRow: View {
    @Binding var shortcut: DesktopShortcut
    let exists: Bool

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Desktop \(shortcut.desktop)", isOn: $shortcut.enabled)
                .toggleStyle(.checkbox)

            if !exists {
                StatusBadge(title: "Not created", color: .secondary)
                    .help("Add this desktop in Mission Control for the shortcut to work")
            }

            Spacer(minLength: 8)

            Picker("Modifiers", selection: $shortcut.modifiers) {
                ForEach(modifierOptions) { modifiers in
                    Text(modifiers.symbols.isEmpty ? "None" : modifiers.symbols).tag(modifiers)
                }
            }
            .labelsHidden()
            .frame(width: 84)

            Picker("Key", selection: $shortcut.key) {
                ForEach(ShortcutKey.numberKeys) { key in
                    Text(key.name).tag(key)
                }
                Divider()
                ForEach(ShortcutKey.functionKeys) { key in
                    Text(key.name).tag(key)
                }
                if !ShortcutKey.all.contains(shortcut.key) {
                    Divider()
                    Text(shortcut.key.name).tag(shortcut.key)
                }
            }
            .labelsHidden()
            .frame(width: 84)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var modifierOptions: [ShortcutModifiers] {
        ShortcutModifiers.presets.contains(shortcut.modifiers)
            ? ShortcutModifiers.presets : ShortcutModifiers.presets + [shortcut.modifiers]
    }
}
