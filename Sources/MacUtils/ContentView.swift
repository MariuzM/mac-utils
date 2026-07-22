import SwiftUI
import AppKit
import FolderKit

enum AppTab: Hashable {
    case cleaner
    case spotlight
    case rekey
    case folders
    case extensions
}

struct ContentView: View {
    @ObservedObject var folderStore: FolderStore
    @StateObject private var scanVM = ScanViewModel()
    @StateObject private var spotlightVM = SpotlightViewModel()
    @StateObject private var rekeyStore = MappingStore()
    @StateObject private var extensionsVM = ExtensionsViewModel()
    @State private var tab: AppTab? = .cleaner
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                List(selection: $tab) {
                    Label("Cleaner", systemImage: "sparkles")
                        .tag(AppTab.cleaner)
                    Label("Spotlight Privacy", systemImage: "magnifyingglass.circle")
                        .tag(AppTab.spotlight)
                    Label("Rekey", systemImage: "keyboard")
                        .tag(AppTab.rekey)
                    Label("Folders", systemImage: "folder")
                        .tag(AppTab.folders)
                    Label("Extensions", systemImage: "arrow.up.forward.app")
                        .tag(AppTab.extensions)
                }
                .listStyle(.sidebar)
                .frame(width: 200)
                .overlay(alignment: .trailing) { Divider() }
                .transition(.move(edge: .leading))
            }

            Group {
                switch tab ?? .cleaner {
                case .cleaner:
                    CleanerView(vm: scanVM)
                case .spotlight:
                    SpotlightView(vm: spotlightVM)
                case .rekey:
                    RekeyView(store: rekeyStore)
                case .folders:
                    FoldersView(store: folderStore)
                case .extensions:
                    ExtensionsView(vm: extensionsVM)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
                .help("Hide or show the sidebar")
            }
        }
        .frame(minWidth: 860, minHeight: 480)
    }
}
