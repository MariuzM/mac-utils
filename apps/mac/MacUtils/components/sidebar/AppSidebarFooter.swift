import FolderKit
import SwiftUI

struct AppSidebarFooter: View {
    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Mac Utils \(Developer.version)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 6)
            Spacer(minLength: 0)
            Link(destination: Developer.url) {
                FooterIcon(systemName: "globe", helpText: "Visit \(Developer.name)")
            }
            .buttonStyle(.plain)
            SettingsLink {
                FooterIcon(systemName: "gearshape", helpText: "Settings")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }
}

private struct FooterIcon: View {
    let systemName: String
    let helpText: String
    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.secondary)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .background(Color.primary.opacity(isHovered ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 7))
            .onHover { isHovered = $0 }
            .help(helpText)
    }
}
