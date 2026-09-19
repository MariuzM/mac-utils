import AppKit
import SwiftUI

struct SuggestionSection: View {
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Background activity to review", symbol: "bolt.badge.clock", count: vm.suggestions.count)
            ListCard {
                ForEach(vm.suggestions) { suggestion in
                    SuggestionRow(suggestion: suggestion, vm: vm)
                    if suggestion.id != vm.suggestions.last?.id {
                        RowDivider(leading: 40)
                    }
                }
            }
        }
    }
}

struct SuggestionRow: View {
    let suggestion: ProcessSuggestion
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.callout.weight(.medium))
                Text(suggestion.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(ByteFormat.string(Int64(suggestion.reclaimBytes)))
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tint)
            Button("Quit") { vm.confirm(suggestion) }
                .controlSize(.small)
                .help(suggestion.note)
                .disabled(vm.isTerminating)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var icon: String {
        switch suggestion.kind {
        case .duplicateInstances: return "square.on.square.dashed"
        case .idleVendorStack: return "moon.zzz"
        }
    }
}

struct ProcessListSection: View {
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("All processes", symbol: "list.bullet", count: vm.visibleProcesses.count)
            ListCard(clipsContent: false) {
                HStack(spacing: 12) {
                    Text("Name")
                    Spacer()
                    Text("CPU").frame(width: 56, alignment: .trailing)
                    Text("Memory").frame(width: 76, alignment: .trailing)
                    Color.clear.frame(width: 54, height: 1)
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 40)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
                Divider()
                let processes = vm.visibleProcesses
                let lastID = processes.last?.id
                LazyVStack(spacing: 0) {
                    ForEach(processes) { sample in
                        ProcessRow(
                            sample: sample,
                            icon: vm.icon(for: sample),
                            isLast: sample.id == lastID,
                            onQuit: { force in vm.quit(sample: sample, force: force) }
                        )
                        .equatable()
                    }
                }
            }
        }
    }
}

struct ProcessRow: View, Equatable {
    let sample: ProcessSample
    let icon: NSImage?
    let isLast: Bool
    let onQuit: (Bool) -> Void

    nonisolated static func == (lhs: ProcessRow, rhs: ProcessRow) -> Bool {
        lhs.sample == rhs.sample && lhs.icon === rhs.icon && lhs.isLast == rhs.isLast
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            if !isLast {
                RowDivider(leading: 40)
            }
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(sample.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("PID \(sample.pid) · \(sample.role.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(sample.metricsReadable ? String(format: "%.1f%%", sample.cpuPercent) : "—")
                .font(.callout.monospacedDigit())
                .foregroundStyle(sample.cpuPercent >= 20 ? .primary : .secondary)
                .frame(width: 56, alignment: .trailing)

            Text(sample.metricsReadable ? ByteFormat.string(Int64(sample.residentBytes)) : "—")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)

            if sample.isProtected {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 54)
                    .help("System process — Mac Utils won't quit this")
            } else {
                Button(action: showActions) {
                    HStack(spacing: 3) {
                        Text("Quit")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .fixedSize()
                .frame(width: 54)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }

    private func showActions() {
        let path = sample.executablePath
        let menu = NSMenu()
        menu.addItem(ActionMenuItem(title: "Quit") { onQuit(false) })
        menu.addItem(ActionMenuItem(title: "Force Quit") { onQuit(true) })
        menu.addItem(.separator())
        menu.addItem(
            ActionMenuItem(title: "Reveal in Finder") {
                guard !path.isEmpty else { return }
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            })
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}
