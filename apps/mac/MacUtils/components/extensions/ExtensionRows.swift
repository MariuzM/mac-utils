import SwiftUI

struct ExtensionGroupSection: View {
    let category: ExtensionCategory
    let entries: [ExtensionEntry]
    @ObservedObject var vm: ExtensionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(category.rawValue, symbol: category.icon, count: entries.count)
            ListCard {
                ForEach(entries) { entry in
                    ExtensionRow(entry: entry, vm: vm)
                    if entry.id != entries.last?.id {
                        RowDivider()
                    }
                }
            }
        }
    }
}

struct ExtensionRow: View {
    let entry: ExtensionEntry
    @ObservedObject var vm: ExtensionsViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text(".\(entry.ext)")
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .frame(width: 70, alignment: .leading)
            Text(entry.typeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            appPicker
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(minHeight: 34)
    }

    @ViewBuilder
    private var appPicker: some View {
        if entry.candidates.isEmpty && entry.defaultApp == nil {
            Text("No app installed")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Menu {
                ForEach(entry.candidates) { app in
                    Button {
                        vm.setDefault(app, for: entry)
                    } label: {
                        if app == entry.defaultApp {
                            Label(app.name, systemImage: "checkmark")
                        } else {
                            Text(app.name)
                        }
                    }
                }
                Divider()
                Button("Other…") { vm.chooseOtherApp(for: entry) }
            } label: {
                HStack(spacing: 6) {
                    if let app = entry.defaultApp {
                        Image(nsImage: vm.icon(for: app.url))
                        Text(app.name)
                    } else {
                        Text("None")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
