import SwiftUI

struct KeyboardView: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var desktopStore: DesktopShortcutStore

    var body: some View {
        PageScaffold(title: AppSection.rekey.title, subtitle: AppSection.rekey.subtitle) {
            if store.isWorking { ProgressView().controlSize(.small) }
            Button("Reset") { store.resetSystemMappings() }
                .help("Clear the active key mapping")
            Button("Apply") { store.apply() }
                .buttonStyle(.borderedProminent)
                .disabled(store.mappings.isEmpty)
        } content: {
            PageScroll(spacing: 16, maxWidth: 760) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Mappings", symbol: "keyboard", count: store.mappings.count) {
                        Button {
                            store.add()
                        } label: {
                            Label("Add Mapping", systemImage: "plus")
                        }
                        .controlSize(.small)
                    }
                    ListCard {
                        if store.mappings.isEmpty {
                            Text("No mappings yet. Choose an action for each key, then apply it.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        } else {
                            ForEach($store.mappings) { $mapping in
                                MappingRow(mapping: $mapping, onChange: { store.commit() }) {
                                    store.remove(mapping)
                                }
                                if mapping.id != store.mappings.last?.id {
                                    RowDivider()
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Startup", symbol: "power")
                    ListCard {
                        SettingsToggle(
                            title: "Apply mappings at startup",
                            caption: "Install a launch daemon that restores these mappings when the Mac starts.",
                            isOn: Binding(
                                get: { store.startupEnabled },
                                set: { s in store.setStartup(s) }
                            )
                        )
                        .padding(12)

                        if store.startupStale {
                            RowDivider()
                            warningRow("Startup daemon has older mappings", action: "Update") {
                                store.updateStartup()
                            }
                        }
                        if store.hasLegacyDaemon {
                            RowDivider()
                            warningRow("An older rekey daemon is still installed", action: "Remove") {
                                store.removeLegacyDaemon()
                            }
                        }
                    }
                }

                if let warning = store.conflictWarning {
                    Notice(text: warning, symbol: "exclamationmark.triangle")
                }

                if let status = store.status {
                    HStack(spacing: 6) {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        IconButton(systemName: "xmark", help: "Dismiss") {
                            store.status = nil
                        }
                    }
                }

                desktopSection
            }
            .disabled(store.isWorking)
            .onAppear { desktopStore.reload() }
        }
    }

    @ViewBuilder
    private var desktopSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Desktop Shortcuts", symbol: "rectangle.3.group", count: desktopStore.desktopCount) {
                Menu("Preset") {
                    ForEach(DesktopShortcutPreset.allCases) { preset in
                        Button(preset.title) { desktopStore.apply(preset) }
                    }
                }
                .fixedSize()
                .controlSize(.small)
                Button {
                    desktopStore.restartDock()
                } label: {
                    Label("Restart Dock", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .help("Restart the Dock if desktop shortcuts stop responding")
            }
            ListCard {
                ForEach(desktopStore.shortcuts) { shortcut in
                    DesktopShortcutRow(
                        shortcut: Binding(
                            get: { shortcut },
                            set: { s in desktopStore.update(s) }
                        ),
                        exists: desktopStore.exists(shortcut)
                    )
                    if shortcut.id != desktopStore.shortcuts.last?.id {
                        RowDivider()
                    }
                }
            }
            Text("Add desktops in Mission Control to configure more of them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let warning = desktopStore.warning(remappedKeys: Set(store.mappings.map(\.source.name))) {
            Notice(text: warning, symbol: "exclamationmark.triangle")
        }

        if let status = desktopStore.status {
            HStack(spacing: 6) {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                IconButton(systemName: "xmark", help: "Dismiss") {
                    desktopStore.status = nil
                }
            }
        }
    }

    private func warningRow(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
            Spacer()
            Button(action, action: perform)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
