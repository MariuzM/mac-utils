import SwiftUI

struct LeftoverGroupSection: View {
    let group: LeftoverGroup
    @ObservedObject var vm: LeftoversViewModel

    private var isExpanded: Bool {
        vm.expanded.contains(group.id)
    }

    var body: some View {
        ListCard {
            HStack(spacing: 10) {
                Toggle(
                    "Select \(group.title)",
                    isOn: Binding(
                        get: { vm.isFullySelected(group) },
                        set: { _ in vm.toggle(group: group) })
                )
                .toggleStyle(.checkbox)
                .labelsHidden()

                Button {
                    vm.toggleExpanded(group)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: group.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tint)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(group.title)
                                    .font(.callout.weight(.semibold))
                                CountBadge(count: group.items.count)
                                ConfidenceBadge(confidence: group.confidence)
                            }
                            Text(group.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(ByteFormat.string(group.totalSize))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 12)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if isExpanded {
                Divider()
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        LeftoverRow(item: item, vm: vm)
                        if item.id != group.items.last?.id {
                            RowDivider(leading: 40)
                        }
                    }
                }
                .background(Color.primary.opacity(0.025))
            }
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: LeftoverConfidence

    var body: some View {
        StatusBadge(
            title: confidence.label, color: confidence == .confirmed ? .green : .orange, showsDot: false)
    }
}

struct LeftoverRow: View {
    let item: LeftoverItem
    @ObservedObject var vm: LeftoversViewModel

    var body: some View {
        HStack(spacing: 10) {
            Toggle(
                "Select \(item.name)",
                isOn: Binding(
                    get: { vm.selected.contains(item.id) },
                    set: { _ in vm.toggle(item) })
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if item.needsAdmin {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("Root-owned — needs your administrator password")
                    }
                }
                Text(item.evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text(ByteFormat.string(item.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            IconButton(systemName: "arrow.up.forward.square", help: "Reveal \(item.url.path)") {
                vm.reveal(item)
            }
        }
        .padding(.leading, 34)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }
}
