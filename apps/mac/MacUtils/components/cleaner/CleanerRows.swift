import AppKit
import SwiftUI

struct VolumeSection: View {
    let volume: VolumeResult
    @ObservedObject var vm: ScanViewModel

    private var userCategories: [CategoryResult] {
        volume.categories.filter { !$0.isSystem }
    }

    private var systemCategories: [CategoryResult] {
        volume.categories.filter(\.isSystem)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: volume.isBoot ? "internaldrive.fill" : "externaldrive.fill")
                    .foregroundStyle(.tint)
                Text(volume.name)
                    .font(.title3.weight(.semibold))
                CountBadge(count: volume.itemCount)
                Spacer()
                Text(ByteFormat.string(volume.totalSize))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if volume.categories.isEmpty {
                Text("Nothing found on this volume.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if !userCategories.isEmpty && !systemCategories.isEmpty {
                CategoryGroup(title: "User Files", categories: userCategories, vm: vm)
                CategoryGroup(title: "System Files", categories: systemCategories, vm: vm)
            } else {
                CategoryGroup(title: nil, categories: volume.categories, vm: vm)
            }
        }
    }
}

struct CategoryGroup: View {
    let title: String?
    let categories: [CategoryResult]
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let title {
                    Text(title.uppercased())
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check All") { vm.selectAll(categories) }
                    .buttonStyle(.link)
                    .font(.caption)
                Button("Uncheck All") { vm.deselectAll(categories) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .padding(.horizontal, 4)

            ListCard {
                ForEach(categories) { category in
                    CategoryRow(category: category, vm: vm)
                    if category.id != categories.last?.id {
                        RowDivider(leading: 40)
                    }
                }
            }
        }
    }
}

struct CategoryRow: View {
    let category: CategoryResult
    @ObservedObject var vm: ScanViewModel
    @State private var expanded = false

    private var selectedCount: Int {
        category.items.filter { vm.isItemSelected($0, category: category) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle(
                    "Select \(category.title)",
                    isOn: Binding(
                        get: { vm.isSelected(category) },
                        set: { vm.setSelected(category, $0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("Include this category in Delete and Back Up")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(category.title)
                                    .font(.callout.weight(.medium))
                                SafetyBadge(safety: category.safety)
                            }
                            Text(category.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .help(category.subtitle)
                        }
                        Spacer()
                        Text("\(selectedCount)/\(category.items.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 34, alignment: .trailing)
                        Text(ByteFormat.string(category.totalSize))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 64, alignment: .trailing)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 12)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                IconButton(systemName: "arrow.down.doc", help: "Back up this category to the Desktop") {
                    vm.backup(items: category.items)
                }
                .disabled(vm.isBusy)

                IconButton(systemName: "trash", help: "Delete selected items in this category", role: .destructive) {
                    vm.requestDelete(items: category.items.filter { vm.isItemSelected($0, category: category) })
                }
                .disabled(vm.isBusy || selectedCount == 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if expanded {
                Divider()
                LazyVStack(spacing: 0) {
                    ForEach(category.items) { item in
                        ItemRow(item: item, category: category, vm: vm)
                    }
                }
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.025))
            }
        }
    }
}

struct ItemRow: View {
    let item: ScanItem
    let category: CategoryResult
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        HStack(spacing: 10) {
            Toggle(
                "Select \(item.name)",
                isOn: Binding(
                    get: { vm.isItemSelected(item, category: category) },
                    set: { vm.setItemSelected(item, category: category, selected: $0) })
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(vm.isBusy)
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.url.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormat.string(item.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            IconButton(systemName: "arrow.up.forward.square", help: "Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
        .padding(.leading, 34)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
    }
}
