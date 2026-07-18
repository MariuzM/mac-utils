import SwiftUI
import AppKit

struct FoldersView: View {
    @ObservedObject var store: FolderStore
    @ObservedObject var dock: DockOverrideController
    @AppStorage(FolderStore.enabledKey) private var enabled = true
    @State private var dockItems: [DockFolderItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                dockSection

                Divider()

                Text("Menu Bar")
                    .font(.headline)

                Text("Browse pinned folders from the menu bar. Right-click any item to open it in Terminal, Ghostty or Visual Studio Code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Toggle("Show Folders in the menu bar", isOn: $enabled)

                if enabled && !ExternalApp.allCases.contains(where: \.isInstalled) {
                    Label("None of Terminal, Ghostty or Visual Studio Code were found.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Divider()

                Text("Pinned Folders")
                    .font(.headline)

                if store.folders.isEmpty {
                    Text("No folders pinned yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.folders) { folder in
                        PinnedFolderRow(folder: folder) {
                            store.unpin(folder)
                        }
                    }
                }

                Button {
                    addFolder()
                } label: {
                    Label("Add Folder", systemImage: "plus")
                }

                if enabled {
                    Divider()
                    Text("If the icon doesn't appear, your menu bar is full — macOS parks extra items off-screen. Quit an app that uses the menu bar, or hold ⌘ and drag icons to make room.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: 480, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            dock.refreshTrust()
            dockItems = DockAX.folderItems()
        }
        .onChange(of: dock.trusted) { _ in
            dockItems = DockAX.folderItems()
        }
    }

    @ViewBuilder
    private var dockSection: some View {
        Text("Dock Folders")
            .font(.headline)

        Text("Clicking a checked folder in the Dock opens this list instead of the macOS stack, so you can right-click items inside it. Unchecked folders keep their normal behaviour.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        if !dock.trusted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Accessibility permission required", systemImage: "lock")
                    .foregroundStyle(.orange)
                Text("macOS only lets an app intercept Dock clicks with Accessibility access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Grant Access…") { dock.requestTrust() }
                    Button("Open Settings") { DockAX.openAccessibilitySettings() }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(.orange.opacity(0.12)))
        }

        if dockItems.isEmpty {
            Text(dock.trusted ? "No folders found in your Dock" : "Grant access to list your Dock folders")
                .foregroundStyle(.secondary)
        } else {
            ForEach(dockItems) { item in
                Toggle(isOn: Binding(
                    get: { store.isDockOverridden(item.url) },
                    set: { s in
                        store.setDockOverride(item.url, enabled: s)
                        dock.sync()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                            Text(item.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(!dock.trusted)
            }
        }

        Button {
            dock.refreshTrust()
            dockItems = DockAX.folderItems()
        } label: {
            Label("Refresh Dock Folders", systemImage: "arrow.clockwise")
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { store.pin($0) }
    }
}

struct PinnedFolderRow: View {
    let folder: PinnedFolder
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                .resizable()
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(folder.name)
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
