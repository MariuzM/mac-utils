import SwiftUI
import AppKit
import FolderKit

struct FoldersView: View {
    @ObservedObject var store: FolderStore
    @AppStorage(FolderStore.enabledKey, store: SharedConfig.defaults) private var menuBarEnabled = true

    @State private var dockFolders: [DockFolder] = []
    @State private var helperRunning = false
    @State private var launchAtLogin = false
    @State private var helperTrusted = false
    @State private var status: String?
    @State private var configObserver: NSObjectProtocol?

    private var awaitingAccessibilityGrant: Bool {
        !store.dockOverrides.isEmpty && (!helperRunning || !helperTrusted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                helperSection
                Divider()
                dockSection
                Divider()
                menuBarSection
                Divider()
                pinnedSection

                Divider()

                AboutFooter(component: "macOS Utility")
            }
            .padding(20)
            .frame(maxWidth: 480, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            HelperControl.migrateLegacyLoginItems()
            refresh()
            if configObserver == nil {
                configObserver = SharedConfig.observeConfigChanged { refresh() }
            }
        }
        .onDisappear {
            if let configObserver {
                DistributedNotificationCenter.default().removeObserver(configObserver)
            }
            configObserver = nil
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.didLaunchApplicationNotification)) { _ in refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.didTerminateApplicationNotification)) { _ in refresh() }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            guard awaitingAccessibilityGrant else { return }
            refresh()
        }
    }

    @ViewBuilder
    private var helperSection: some View {
        Text("Background Helper")
            .font(.headline)

        Text("“macOS Utility Helper” by \(Developer.name) runs in the background so this window doesn't need to stay open. It owns the Dock override and the menu bar list.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        HStack(spacing: 6) {
            Circle()
                .fill(helperRunning ? .green : .secondary)
                .frame(width: 8, height: 8)
            Text(helperRunning ? "Helper is running" : "Helper is not running")
            Spacer()
            if helperRunning {
                Button("Stop") {
                    HelperControl.stop()
                    refreshSoon()
                }
            } else {
                Button("Start") {
                    HelperControl.start()
                    refreshSoon()
                }
            }
        }

        Toggle("Start at login", isOn: Binding(
            get: { launchAtLogin },
            set: { s in
                do {
                    try HelperControl.setLaunchAtLogin(s)
                    status = s ? "Helper will start at login" : "Helper removed from login items"
                    if s { HelperControl.start() }
                } catch let e {
                    status = e.localizedDescription
                }
                refreshSoon()
            }
        ))

        if HelperControl.helperURL == nil {
            Label("Helper is not embedded in this build — run `make build`.", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        if let status {
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var dockSection: some View {
        Text("Dock Folders")
            .font(.headline)

        Text("Clicking a checked folder in the Dock opens this list instead of the macOS stack, so you can right-click items inside it. Unchecked folders keep their normal behaviour.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        if dockFolders.isEmpty {
            Text("No folders found in your Dock")
                .foregroundStyle(.secondary)
        } else {
            ForEach(dockFolders) { folder in
                Toggle(isOn: Binding(
                    get: { store.isDockOverridden(folder.url) },
                    set: { s in store.setDockOverride(folder.url, enabled: s) }
                )) {
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: folder.url.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(folder.label)
                            Text(folder.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
        }

        Button {
            refresh()
        } label: {
            Label("Refresh Dock Folders", systemImage: "arrow.clockwise")
        }

        if !store.dockOverrides.isEmpty && !helperRunning {
            VStack(alignment: .leading, spacing: 6) {
                Label("Helper is not running", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Dock folders behave normally until the helper starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Start Helper") {
                    HelperControl.start()
                    refreshSoon()
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(.orange.opacity(0.12)))
        } else if !store.dockOverrides.isEmpty && !helperTrusted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Accessibility permission required", systemImage: "lock")
                    .foregroundStyle(.orange)
                Text("The helper — “macOS Utility Helper (\(Developer.name))” — needs its own Accessibility access to intercept Dock clicks. This app doesn't need it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Ask Helper to Request Access") {
                        HelperControl.start()
                        SharedConfig.postConfigChanged()
                        status = "Helper asked for Accessibility access — approve the prompt, or add it in System Settings."
                    }
                    Button("Open Settings") { AccessibilitySettings.open() }
                    Button("Reveal Helper") {
                        if let helperURL = HelperControl.helperURL {
                            NSWorkspace.shared.activateFileViewerSelecting([helperURL])
                        }
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(.orange.opacity(0.12)))
        }
    }

    @ViewBuilder
    private var menuBarSection: some View {
        Text("Menu Bar")
            .font(.headline)

        Text("Browse pinned folders from the menu bar. Right-click any item to open it in Terminal, Ghostty or Visual Studio Code.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        Toggle("Show Folders in the menu bar", isOn: Binding(
            get: { menuBarEnabled },
            set: { s in
                menuBarEnabled = s
                SharedConfig.postConfigChanged()
            }
        ))
    }

    @ViewBuilder
    private var pinnedSection: some View {
        Text("Pinned Folders")
            .font(.headline)

        if let loadError = store.loadError {
            Label(loadError, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }

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
    }

    private func addFolder() {
        store.pinFromOpenPanel()
    }

    private func refresh() {
        dockFolders = DockPrefs.folders()
        helperRunning = HelperControl.isRunning
        helperTrusted = HelperControl.helperReportedTrusted
        launchAtLogin = HelperControl.launchesAtLogin
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { refresh() }
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
