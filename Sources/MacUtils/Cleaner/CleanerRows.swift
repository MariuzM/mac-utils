import AppKit
import FolderKit
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: volume.isBoot ? "internaldrive.fill" : "externaldrive.fill")
                    .foregroundStyle(.tint)
                Text(volume.name)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(ByteFormat.string(volume.totalSize))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if volume.categories.isEmpty {
                Text("Nothing found on this volume.")
                    .font(.subheadline)
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
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check all") { vm.selectAll(categories) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Uncheck all") { vm.deselectAll(categories) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 0) {
                ForEach(categories) { category in
                    CategoryRow(category: category, vm: vm)
                    if category.id != categories.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
        }
    }
}

struct CategoryRow: View {
    let category: CategoryResult
    @ObservedObject var vm: ScanViewModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { vm.isSelected(category) },
                        set: { vm.setSelected(category, $0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("Include this category in Delete Selected / Back Up Selected")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(category.title)
                                    .font(.body.weight(.medium))
                                SafetyBadge(safety: category.safety)
                            }
                            Text(category.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .help(category.subtitle)
                        }
                        Spacer()
                        Text(ByteFormat.string(category.totalSize))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(
                            "\(category.items.filter { vm.isItemSelected($0, category: category) }.count)/\(category.items.count)"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 34, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    vm.backup(items: category.items)
                } label: {
                    Image(systemName: "arrow.down.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(vm.isBusy)
                .help("Back up this category to the Desktop")

                Button {
                    vm.requestDelete(items: category.items.filter { vm.isItemSelected($0, category: category) })
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .disabled(vm.isBusy || !category.items.contains { vm.isItemSelected($0, category: category) })
                .help("Delete selected items in this category")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if expanded {
                LazyVStack(spacing: 0) {
                    ForEach(category.items) { item in
                        ItemRow(item: item, category: category, vm: vm)
                    }

                }
                .padding(.bottom, 6)
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
            .labelsHidden().toggleStyle(.checkbox).disabled(vm.isBusy)
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "arrow.forward.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 5)
    }
}
