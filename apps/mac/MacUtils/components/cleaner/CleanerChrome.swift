import SwiftUI

struct FullDiskAccessBanner: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        BannerBar(color: vm.accessStatus.issues.isEmpty ? .secondary : .orange) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(vm.accessStatus.issues.isEmpty ? Color.secondary : .orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.accessStatus.title)
                        .font(.callout.weight(.medium))
                    Text(
                        "Grant access to this copy of Mac Utils, then quit and reopen it before rescanning. Administrator access is separate."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Show App") { FullDiskAccess.revealApp() }
                    .controlSize(.small)
                    .help(
                        "Grant access to this exact app. If access stops working after a rebuild, remove and re-add it in Full Disk Access."
                    )
                Button("Open Settings") { FullDiskAccess.openSettings() }
                    .controlSize(.small)
                IconButton(
                    systemName: "arrow.clockwise",
                    help: "Recheck readable locations; this does not guarantee access to every folder"
                ) {
                    vm.refreshAccess()
                }
            }
        }
    }
}

struct SafetyBadge: View {
    let safety: SafetyLevel

    private var color: Color {
        switch safety {
        case .safe: return .green
        case .caution: return .orange
        case .review: return .red
        }
    }

    var body: some View {
        StatusBadge(title: safety.label, color: color, showsDot: false)
    }
}
