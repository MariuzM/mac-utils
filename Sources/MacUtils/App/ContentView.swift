import FolderKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var folderStore: FolderStore
    @StateObject private var scanVM = ScanViewModel()
    @StateObject private var spotlightVM = SpotlightViewModel()
    @StateObject private var rekeyStore = MappingStore()
    @StateObject private var extensionsVM = ExtensionsViewModel()
    @StateObject private var performanceVM = PerformanceViewModel()
    @StateObject private var leftoversVM = LeftoversViewModel()
    @StateObject private var siriVM = SiriViewModel()
    @State private var selection: AppSection? = .overview

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.accent.gradient, in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mac Utils").font(.headline)
                    }
                    Spacer()
                }
                .padding(18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        navigationRow(.overview)
                        sidebarGroup("MAINTENANCE", sections: AppSection.maintenance)
                        sidebarGroup("YOUR MAC", sections: AppSection.controls)
                    }
                    .padding(.horizontal, 12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)",
                        systemImage: "desktopcomputer"
                    )
                    .font(.caption.weight(.medium))
                    AboutFooter(component: "Mac Utils")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
            .frame(minWidth: 220, idealWidth: 235, maxWidth: 260, maxHeight: .infinity)
            .background(.bar)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvas)
        }
        .tint(AppTheme.accent)
        .frame(minWidth: 1040, minHeight: 680)
    }

    private func sidebarGroup(_ title: String, sections: [AppSection]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.top, 20).padding(.bottom, 6)
            ForEach(sections) { navigationRow($0) }
        }
    }

    private func navigationRow(_ section: AppSection) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(selection == section ? Color.white : Color.secondary)
                    .frame(width: 18)
                Text(section.title)
            }
            .font(.callout.weight(selection == section ? .semibold : .regular))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .foregroundStyle(selection == section ? Color.white : Color.primary)
            .background(
                selection == section ? AppTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("navigation.\(section.rawValue)")
        .accessibilityAddTraits(selection == section ? .isSelected : [])
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .overview {
        case .overview: OverviewView(scanVM: scanVM, siriVM: siriVM) { selection = $0 }
        case .cleaner: CleanerView(vm: scanVM)
        case .leftovers: LeftoversView(vm: leftoversVM)
        case .performance: PerformanceView(vm: performanceVM)
        case .siri: SiriView(vm: siriVM)
        case .spotlight: SpotlightView(vm: spotlightVM)
        case .rekey: RekeyView(store: rekeyStore)
        case .folders: FoldersView(store: folderStore)
        case .extensions: ExtensionsView(vm: extensionsVM)
        }
    }
}
