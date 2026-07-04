import SwiftUI

@main
struct MacOSUtilityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 620)
    }
}
