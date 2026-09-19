import AppKit
import FolderKit
import SwiftUI

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
        PageScaffold(title: AppSection.folders.title, subtitle: AppSection.folders.subtitle) {
            StatusBadge(
                title: helperRunning ? "Helper running" : "Helper stopped",
                color: helperRunning ? .green : .secondary)
            if helperRunning {
                Button("Stop Helper") {
                    HelperControl.stop()
                    refreshSoon()
                }
            } else {
                Button("Start Helper") {
                    HelperControl.start()
                    refreshSoon()
                }
                .buttonStyle(.borderedProminent)
            }
        } content: {
            PageScroll(spacing: 20, maxWidth: 800) {
                helperSection
                dockSection
                menuBarSection
                pinnedSection
            }
        }
        .onAppear {
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
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didLaunchApplicationNotification)
        ) { _ in refresh() }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didTerminateApplicationNotification)
        ) { _ in refresh() }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            guard awaitingAccessibilityGrant else { return }
            refresh()
        }
    }

    private var helperSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Background Helper", symbol: "gearshape.2")
            ListCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        "“Mac Utils Helper” by \(Developer.name) runs in the background so this window doesn't need to stay open. It owns the Dock override and the menu bar list."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                RowDivider()
                SettingsToggle(
                    title: "Start at login",
                    caption: "Register the helper as a login item.",
                    isOn: Binding(
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
                    )
                )
                .padding(12)

                if HelperControl.needsLoginApproval {
                    RowDivider()
                    HStack {
                        Text("The helper needs approval in Login Items.").font(.callout)
                        Spacer()
                        Button("Open Login Items…") { HelperControl.openLoginSettings() }
                            .controlSize(.small)
                    }
                    .padding(12)
                }
            }

            if HelperControl.helperURL == nil {
                Notice(text: "Open the bundled Mac Utils app to use Dock Folders.", symbol: "exclamationmark.triangle")
            }

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
        }
    }

    private var dockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Dock Folders", symbol: "dock.rectangle", count: dockFolders.count) {
                IconButton(systemName: "arrow.clockwise", help: "Refresh Dock folders") {
                    refresh()
                }
            }
            Text(
                "Clicking a checked folder in the Dock opens this list instead of the macOS stack, so you can right-click items inside it. Unchecked folders keep their normal behaviour."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)

            if !store.dockOverrides.isEmpty && !helperRunning {
                VStack(alignment: .leading, spacing: 8) {
                    Notice(
                        text: "The helper is not running. Dock folders behave normally until the helper starts.",
                        symbol: "exclamationmark.triangle")
                }
            } else if !store.dockOverrides.isEmpty && !helperTrusted {
                VStack(alignment: .leading, spacing: 8) {
                    Notice(
                        text:
                            "The helper — “Mac Utils Helper (\(Developer.name))” — needs its own Accessibility access to intercept Dock clicks. This app doesn't need it.",
                        symbol: "lock")
                    HStack {
                        Button("Ask Helper to Request Access") {
                            HelperControl.start()
                            SharedConfig.postConfigChanged()
                            status =
                                "Helper asked for Accessibility access — approve the prompt, or add it in System Settings."
                        }
                        Button("Open Settings") { AccessibilitySettings.open() }
                        Button("Reveal Helper") {
                            if let helperURL = HelperControl.helperURL {
                                NSWorkspace.shared.activateFileViewerSelecting([helperURL])
                            }
                        }
                    }
                    .controlSize(.small)
                }
            }

            ListCard {
                if dockFolders.isEmpty {
                    Text("No folders found in your Dock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    ForEach(dockFolders) { folder in
                        HStack(spacing: 10) {
                            Toggle(
                                "Override \(folder.label)",
                                isOn: Binding(
                                    get: { store.isDockOverridden(folder.url) },
                                    set: { s in store.setDockOverride(folder.url, enabled: s) }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                            FolderLabel(title: folder.label, path: folder.url.path)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        if folder.id != dockFolders.last?.id {
                            RowDivider(leading: 40)
                        }
                    }
                }
            }
        }
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Menu Bar", symbol: "menubar.rectangle")
            ListCard {
                SettingsToggle(
                    title: "Show Folders in the menu bar",
                    caption:
                        "Browse pinned folders from the menu bar. Right-click any item to open it in Terminal, Ghostty or Visual Studio Code.",
                    isOn: Binding(
                        get: { menuBarEnabled },
                        set: { s in
                            menuBarEnabled = s
                            SharedConfig.postConfigChanged()
                        }
                    )
                )
                .padding(12)
            }
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Pinned Folders", symbol: "pin", count: store.folders.count) {
                Button {
                    store.pinFromOpenPanel()
                } label: {
                    Label("Add Folder", systemImage: "plus")
                }
                .controlSize(.small)
            }

            if let loadError = store.loadError {
                Notice(text: loadError, symbol: "exclamationmark.triangle")
            }

            ListCard {
                if store.folders.isEmpty {
                    Text("No folders pinned yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    ForEach(store.folders) { folder in
                        PinnedFolderRow(folder: folder) {
                            store.unpin(folder)
                        }
                        if folder.id != store.folders.last?.id {
                            RowDivider(leading: 40)
                        }
                    }
                }
            }
        }
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
