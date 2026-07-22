import SwiftUI
import AppKit

struct ExtensionsView: View {
    @ObservedObject var vm: ExtensionsViewModel

    var body: some View {
        VStack(spacing: 0) {
            ExtensionsHeaderBar(vm: vm)
            Divider()
            content
        }
        .onAppear { vm.loadIfNeeded() }
        .alert("Couldn’t change the default app", isPresented: $vm.showError, presenting: vm.lastError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !vm.loaded {
            VStack(spacing: 14) {
                ProgressView()
                Text("Reading file type handlers…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.visibleGroups.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text("No matches")
                    .font(.title3.weight(.semibold))
                Text("No extension, file type, or app matches “\(vm.search)”.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(vm.visibleGroups, id: \.category) { group in
                        ExtensionGroupSection(category: group.category, entries: group.entries, vm: vm)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct ExtensionsHeaderBar: View {
    @ObservedObject var vm: ExtensionsViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Extensions")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if vm.isWorking {
                ProgressView().controlSize(.small)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search extensions or apps", text: $vm.search)
                    .textFieldStyle(.plain)
                if !vm.search.isEmpty {
                    Button {
                        vm.search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .frame(width: 230)

            if vm.loaded {
                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isWorking)
                .help("Reload the current handlers from the system")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        if !vm.loaded { return "Choose which app opens each file type" }
        let count = vm.entries.count
        return "\(count) extensions — changes apply to all files of the same type (e.g. .jpg and .jpeg)"
    }
}

struct ExtensionGroupSection: View {
    let category: ExtensionCategory
    let entries: [ExtensionEntry]
    @ObservedObject var vm: ExtensionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text(category.rawValue)
                    .font(.headline)
                Text("\(entries.count)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    ExtensionRow(entry: entry, vm: vm)
                    if entry.id != entries.last?.id {
                        Divider().padding(.leading, 14)
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

struct ExtensionRow: View {
    let entry: ExtensionEntry
    @ObservedObject var vm: ExtensionsViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text(".\(entry.ext)")
                .font(.system(.body, design: .monospaced).weight(.medium))
                .frame(width: 70, alignment: .leading)
            Text(entry.typeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            appPicker
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
