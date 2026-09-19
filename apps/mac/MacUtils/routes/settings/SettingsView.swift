import FolderKit
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKey.layeredContent) private var layeredContent = false
    @AppStorage(PreferenceKey.showBorders) private var showBorders = true
    @Bindable private var uiPreferences = UIAppearancePreferences.shared

    var body: some View {
        Form {
            Section("Appearance") {
                AccentColorPicker(accent: $uiPreferences.accent)
                SettingsToggle(
                    title: "Layered content",
                    caption: "Raise the main content as a rounded surface next to the sidebar.",
                    isOn: $layeredContent
                )
                SettingsToggle(
                    title: "Show borders",
                    caption: "Display a separator line between the sidebar and the content.",
                    isOn: $showBorders
                )
                .disabled(layeredContent)
            }
            Section {
                LabeledContent("Version", value: Developer.version)
                LabeledContent("Developer") {
                    Link(Developer.name, destination: Developer.url)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 360)
        .tint(uiPreferences.accentColor)
    }
}
