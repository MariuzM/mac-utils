import SwiftUI

struct OverviewView: View {
    @ObservedObject var scanVM: ScanViewModel
    @ObservedObject var siriVM: SiriViewModel
    let navigate: (AppSection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(
                    title: "Overview", subtitle: "Storage, processes, and system settings.")

                HStack(spacing: 14) {
                    MetricTile(
                        title: "Memory installed",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory),
                        symbol: "memorychip")
                    MetricTile(
                        title: "Storage to review",
                        value: scanVM.hasScanned ? ByteFormat.string(scanVM.totalReclaimable) : "Not scanned",
                        symbol: "internaldrive")
                    MetricTile(title: "Siri", value: siriVM.snapshot?.summary ?? "Not checked", symbol: "mic.slash")
                }

                Surface {
                    HStack(spacing: 22) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 68, height: 80)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Review caches, logs, and developer files across your drives.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Open Storage Cleaner") { navigate(.cleaner) }
                                .buttonStyle(PrimaryActionStyle())
                                .controlSize(.large)
                                .padding(.top, 4)
                        }
                        Spacer(minLength: 0)
                    }
                }

                Text("Utilities").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach([AppSection.siri, .performance, .leftovers, .rekey]) { section in
                        Button {
                            navigate(section)
                        } label: {
                            Surface {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: section.symbol)
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(section.title).font(.headline)
                                        Text(section.subtitle).font(.callout).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
                                }
                                .frame(minHeight: 62, alignment: .top)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(30)
        }
    }
}
