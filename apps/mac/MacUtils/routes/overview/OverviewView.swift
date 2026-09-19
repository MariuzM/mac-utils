import SwiftUI

struct OverviewView: View {
    @ObservedObject var scanVM: ScanViewModel
    @ObservedObject var siriVM: SiriViewModel
    @ObservedObject var leftoversVM: LeftoversViewModel
    let navigate: (AppSection) -> Void

    var body: some View {
        PageScaffold(title: AppSection.overview.title, subtitle: AppSection.overview.subtitle) {
            PageScroll(spacing: 24) {
                HStack(spacing: 12) {
                    MetricTile(
                        title: "Memory installed",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory),
                        symbol: "memorychip")
                    MetricTile(
                        title: "Storage to review",
                        value: scanVM.hasScanned ? ByteFormat.string(scanVM.totalReclaimable) : "Not scanned",
                        symbol: "internaldrive")
                    MetricTile(
                        title: "App leftovers",
                        value: leftoversVM.hasScanned ? "\(leftoversVM.confirmedCount) confirmed" : "Not scanned",
                        symbol: "trash.slash")
                    MetricTile(title: "Siri", value: siriVM.snapshot?.summary ?? "Not checked", symbol: "mic.slash")
                }

                Surface(padding: 18) {
                    HStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.tint)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Clean up storage").font(.headline)
                            Text("Review caches, logs, and developer files across your drives.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        Button("Open Storage Cleaner") { navigate(.cleaner) }
                            .buttonStyle(.borderedProminent)
                    }
                }

                utilityGroup("Maintenance", sections: AppSection.maintenance)
                utilityGroup("Your Mac", sections: AppSection.controls)
            }
        }
    }

    private func utilityGroup(_ title: String, sections: [AppSection]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], alignment: .leading, spacing: 12
            ) {
                ForEach(sections) { section in
                    OverviewTile(section: section) { navigate(section) }
                }
            }
        }
    }
}

private struct OverviewTile: View {
    let section: AppSection
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: section.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title).font(.callout.weight(.semibold))
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68, alignment: .leading)
            .background(
                isHovered ? AppTheme.surface.mix(with: .primary, by: 0.03) : AppTheme.surface,
                in: RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .strokeBorder(AppTheme.border)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
