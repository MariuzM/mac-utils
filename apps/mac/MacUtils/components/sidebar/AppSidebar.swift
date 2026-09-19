import SwiftUI

struct AppSidebar: View {
    @Binding var selection: AppSection
    let badge: (AppSection) -> String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                AppSidebarRow(section: .overview, isSelected: selection == .overview, badge: badge(.overview)) {
                    selection = .overview
                }
                group("Maintenance", sections: AppSection.maintenance)
                group("Your Mac", sections: AppSection.controls)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .sidebarScrollFade()
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: SidebarLayout.topInset)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppSidebarFooter()
        }
    }

    private func group(_ title: String, sections: [AppSection]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.top, 14)
                .padding(.bottom, 4)
            ForEach(sections) { section in
                AppSidebarRow(section: section, isSelected: selection == section, badge: badge(section)) {
                    selection = section
                }
            }
        }
    }
}
