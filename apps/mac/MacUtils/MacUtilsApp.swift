import FolderKit
import SwiftUI

@main
struct MacUtilsApp: App {
    @StateObject private var folderStore = FolderStore()
    @State private var configObserver: NSObjectProtocol?

    var body: some Scene {
        Window("Mac Utils", id: "main") {
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
        .defaultSize(width: 1180, height: 800)
    }
}
