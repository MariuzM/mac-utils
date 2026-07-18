import SwiftUI
import FolderKit

@main
struct MacOSUtilityApp: App {
    @StateObject private var folderStore = FolderStore()

    var body: some Scene {
        WindowGroup {
            ContentView(folderStore: folderStore)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 620)
    }
}
