import SwiftUI

@main
struct MacOSUtilityApp: App {
    @StateObject private var folderStore: FolderStore
    @StateObject private var dockController: DockOverrideController
    @AppStorage(FolderStore.enabledKey) private var foldersMenuEnabled = true

    init() {
        let store = FolderStore()
        _folderStore = StateObject(wrappedValue: store)
        _dockController = StateObject(wrappedValue: DockOverrideController(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(folderStore: folderStore, dockController: dockController)
                .onAppear { dockController.refreshTrust() }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 620)

        MenuBarExtra("Folders", systemImage: "folder", isInserted: $foldersMenuEnabled) {
            FolderMenuView(store: folderStore)
        }
        .menuBarExtraStyle(.window)
    }
}
