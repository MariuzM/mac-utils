import SwiftUI

struct MappingRow: View {
    @Binding var mapping: KeyMapping
    let onChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker("From", selection: $mapping.source) {
                ForEach(Keys.sources) { key in
                    Text(key.name).tag(key)
                }
            }
            .labelsHidden()
            .onChange(of: mapping.source) { _, _ in onChange() }

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)

            Picker("To", selection: $mapping.destination) {
                ForEach(Keys.destinations) { key in
                    Text(key.name).tag(key)
                }
            }
            .labelsHidden()
            .onChange(of: mapping.destination) { _, _ in onChange() }

            IconButton(systemName: "trash", help: "Remove mapping", role: .destructive, action: onDelete)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
