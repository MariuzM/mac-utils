import SwiftUI
import AppKit
import FolderKit

struct FullDiskAccessBanner: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Full Disk Access not granted")
                    .font(.callout.weight(.medium))
                Text("System and other-user locations at the root are skipped until you grant access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") { FullDiskAccess.openSettings() }
            Button {
                vm.refreshAccess()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Re-check after granting access")
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
            Text("Caches, logs, trash, developer junk and temporary files across all mounted volumes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button(action: onScan) {
                Label("Scan Now", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
