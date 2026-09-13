import AppKit
import FolderKit
import SwiftUI

struct FullDiskAccessBanner: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
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
                .help(
                    "Grant access to this exact app. If access stops working after a rebuild, remove and re-add it in Full Disk Access."
                )
            Button("Open Settings") { FullDiskAccess.openSettings() }
            Button {
                vm.refreshAccess()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Recheck readable locations; this does not guarantee access to every folder")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
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
        Text(safety.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct EmptyState: View {
    let hasScanned: Bool
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(hasScanned ? "No removable files found" : "Scan your Mac for removable files")
                .font(.title3.weight(.semibold))
            Text(
                "Review caches, logs, and developer files across your drives. Only safe categories are selected automatically."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)
            Button(action: onScan) {
                Label("Scan Now", systemImage: "magnifyingglass")
            }
            .buttonStyle(PrimaryActionStyle())
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
