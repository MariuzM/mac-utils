import SwiftUI
import FolderKit

@main
struct MacOSUtilityApp: App {
    @StateObject private var folderStore = FolderStore()
    @State private var configObserver: NSObjectProtocol?

    var body: some Scene {
        WindowGroup {
            ContentView(folderStore: folderStore)
                .onAppear {
                    guard configObserver == nil else { return }
                    configObserver = SharedConfig.observeConfigChanged {
                        folderStore.reloadFromDisk()
                    }
                }
                .onDisappear {
                    if let configObserver {
                        DistributedNotificationCenter.default().removeObserver(configObserver)
                    }
                    configObserver = nil
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 620)
    }
}
