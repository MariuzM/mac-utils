import SwiftUI

struct RekeyView: View {
    @ObservedObject var store: MappingStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PageHeading(
                    title: "Keyboard", subtitle: "Remap keys and keep your mappings at startup.")

                Text(
                    "Choose an action for each key. Apply it now, or keep your mappings at startup."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if store.mappings.isEmpty {
                    Text("No mappings yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($store.mappings) { $mapping in
                        MappingRow(mapping: $mapping, onChange: { store.commit() }) {
                            store.remove(mapping)
                        }
                    }
                }

                Button {
                    store.add()
                } label: {
                    Label("Add Mapping", systemImage: "plus")
                }

                Divider()

                HStack {
                    Button("Apply") { store.apply() }
                        .buttonStyle(PrimaryActionStyle())
                        .disabled(store.mappings.isEmpty)
                    Button("Reset") { store.resetSystemMappings() }
                }

                Toggle(
                    "Apply mappings at startup",
                    isOn: Binding(
                        get: { store.startupEnabled },
                        set: { s in store.setStartup(s) }
                    ))

                if store.startupStale {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Startup daemon has older mappings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Update") { store.updateStartup() }
                            .controlSize(.small)
                    }
                }

                if store.hasLegacyDaemon {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("An older rekey daemon is still installed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Remove") { store.removeLegacyDaemon() }
                            .controlSize(.small)
                    }
                }

                if let warning = store.conflictWarning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let status = store.status {
                    HStack(spacing: 6) {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            store.status = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .disabled(store.isWorking)
        }
    }
}

struct MappingRow: View {
    @Binding var mapping: KeyMapping
    let onChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Picker("", selection: $mapping.source) {
                ForEach(Keys.sources) { key in
                    Text(key.name).tag(key)
                }
            }
            .labelsHidden()
            .onChange(of: mapping.source) { _, _ in onChange() }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Picker("", selection: $mapping.destination) {
                ForEach(Keys.destinations) { key in
                    Text(key.name).tag(key)
                }
            }
            .labelsHidden()
            .onChange(of: mapping.destination) { _, _ in onChange() }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}
