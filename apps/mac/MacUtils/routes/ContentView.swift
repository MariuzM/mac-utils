import FolderKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var folderStore: FolderStore
    @StateObject private var scanVM = ScanViewModel()
    @StateObject private var spotlightVM = SpotlightViewModel()
    @StateObject private var rekeyStore = MappingStore()
    @StateObject private var desktopShortcutStore = DesktopShortcutStore()
    @State private var extensionsVM = ExtensionsViewModel()
    @State private var performanceVM = PerformanceViewModel()
    @State private var launchItemsVM = LaunchItemsViewModel()
    @StateObject private var leftoversVM = LeftoversViewModel()
    @StateObject private var siriVM = SiriViewModel()
    @AppStorage(PreferenceKey.selectedSection) private var selection = AppSection.overview
    @AppStorage(PreferenceKey.sidebarWidth) private var storedSidebarWidth = Double(SidebarLayout.defaultWidth)
    @AppStorage(PreferenceKey.layeredContent) private var layeredContent = false
    @AppStorage(PreferenceKey.showBorders) private var showBorders = true
    @State private var resizedSidebarWidth: CGFloat?
    private let uiPreferences = UIAppearancePreferences.shared

    var body: some View {
        GeometryReader { geometry in
            let widthRange = sidebarWidthRange(availableWidth: geometry.size.width)
            let sidebarWidth = SidebarLayout.clamp(
                resizedSidebarWidth ?? CGFloat(storedSidebarWidth), to: widthRange)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    AppSidebar(selection: $selection, badge: badge(for:))
                        .frame(width: sidebarWidth)
                        .overlay(alignment: .trailing) {
                            if showBorders && !layeredContent {
                                Rectangle()
                                    .fill(Color(nsColor: .separatorColor).opacity(0.6))
                                    .frame(width: 1)
                            }
                        }
                    detailSurface
                }
                SidebarResizeHandle(sidebarWidth: sidebarWidth, widthRange: widthRange, onResize: resizeSidebar)
                    .frame(width: SidebarLayout.resizeHandleWidth)
                    .frame(maxHeight: .infinity)
                    .offset(x: sidebarWidth - SidebarLayout.resizeHandleWidth / 2)
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background {
            SidebarBackground().ignoresSafeArea()
        }
        .tint(uiPreferences.accentColor)
        .navigationTitle(selection.title)
        .background(WindowConfigurator())
    }

    @ViewBuilder
    private var detailSurface: some View {
        if layeredContent {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvas)
                .clipShape(shape)
                .overlay { shape.strokeBorder(AppTheme.border) }
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                .padding([.top, .trailing, .bottom], 10)
        } else {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvas)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview: OverviewView(scanVM: scanVM, siriVM: siriVM, leftoversVM: leftoversVM) { selection = $0 }
        case .cleaner: CleanerView(vm: scanVM)
        case .leftovers: LeftoversView(vm: leftoversVM)
        case .performance: PerformanceView(vm: performanceVM)
        case .launchItems: LaunchItemsView(vm: launchItemsVM)
        case .siri: SiriView(vm: siriVM)
        case .spotlight: SpotlightView(vm: spotlightVM)
        case .rekey: KeyboardView(store: rekeyStore, desktopStore: desktopShortcutStore)
        case .folders: FoldersView(store: folderStore)
        case .extensions: ExtensionsView(vm: extensionsVM)
        }
    }

    private func badge(for section: AppSection) -> String? {
        switch section {
        case .cleaner:
            guard scanVM.hasScanned, scanVM.totalReclaimable > 0 else { return nil }
            return ByteFormat.string(scanVM.totalReclaimable)
        case .leftovers:
            guard leftoversVM.hasScanned, !leftoversVM.groups.isEmpty else { return nil }
            return "\(leftoversVM.groups.reduce(0) { $0 + $1.items.count })"
        case .spotlight:
            guard spotlightVM.loaded, !spotlightVM.folders.isEmpty else { return nil }
            return "\(spotlightVM.folders.count)"
        case .rekey:
            return rekeyStore.mappings.isEmpty ? nil : "\(rekeyStore.mappings.count)"
        default:
            return nil
        }
    }

    private func sidebarWidthRange(availableWidth: CGFloat) -> ClosedRange<CGFloat> {
        let upperBound = min(
            SidebarLayout.maximumWidth,
            max(SidebarLayout.minimumWidth, availableWidth - SidebarLayout.minimumDetailWidth)
        )
        return SidebarLayout.minimumWidth...upperBound
    }

    private func resizeSidebar(to width: CGFloat, isFinished: Bool) {
        if isFinished {
            storedSidebarWidth = Double(width)
            resizedSidebarWidth = nil
        } else {
            resizedSidebarWidth = width
        }
    }
}
