import AppKit
import SwiftUI

struct PerformanceView: View {
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        VStack(spacing: 0) {
            PerformanceHeaderBar(vm: vm)
            Divider()
            content
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .confirmationDialog(
            vm.pendingSuggestion.map { "Quit \($0.pids.count) processes?" } ?? "Quit processes?",
            isPresented: $vm.showQuitConfirm, titleVisibility: .visible
        ) {
            if let pending = vm.pendingSuggestion {
                Button("Quit") { vm.apply(pending, force: false) }
                Button("Force Quit", role: .destructive) { vm.apply(pending, force: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let pending = vm.pendingSuggestion {
                Text(
                    "\(pending.note)\n\nQuit asks each process to exit cleanly. Force Quit kills it immediately and can lose unsaved work."
                )
            }
        }
        .alert("Finished", isPresented: $vm.showResult, presenting: vm.lastResult) { _ in
            Button("OK", role: .cancel) {}
        } message: { result in
            Text(resultMessage(result))
        }
    }

    private func resultMessage(_ result: TerminationResult) -> String {
        let quit = result.requested - result.refused
        var parts = ["\(quit) of \(result.requested) processes quit."]
        if result.refused > 0 {
            parts.append(
                "\(result.refused) are still running — they may be busy or have unsaved work:\n"
                    + result.stillRunning.prefix(4).joined(separator: "\n")
                    + "\n\nTry Force Quit if they don't exit on their own.")
        }
        return parts.joined(separator: "\n\n")
    }

    @ViewBuilder
    private var content: some View {
        if !vm.loaded {
            VStack(spacing: 14) {
                ProgressView()
                Text("Sampling processes…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if !vm.suggestions.isEmpty {
                        SuggestionSection(vm: vm)
                    }
                    ProcessListSection(vm: vm)
                }
                .padding(20)
            }
        }
    }
}

struct PerformanceHeaderBar: View {
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Performance")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

            }
            .layoutPriority(1)
            Spacer(minLength: 12)

            Toggle("Background", isOn: $vm.showBackgroundOnly)
                .toggleStyle(.checkbox)
                .fixedSize()
                .help("Hide regular applications")

            Picker("", selection: $vm.sortKey) {
                ForEach(ProcessSortKey.allCases) { key in
                    Text(key.rawValue).tag(key)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search processes", text: $vm.search)
                    .textFieldStyle(.plain)
                if !vm.search.isEmpty {
                    Button {
                        vm.search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .frame(width: 200)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var subtitle: String {
        guard vm.loaded else { return "Reading running processes…" }
        let yours = vm.samples.filter { !$0.isProtected }.count
        let base = "\(vm.samples.count) processes · \(yours) yours"
        guard vm.totalReclaimable > 0 else { return base }
        return base + " · \(ByteFormat.string(Int64(vm.totalReclaimable))) in suggested processes"
    }
}

struct SuggestionSection: View {
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.badge.clock")
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text("Background activity to review")
                    .font(.headline)
                Text("\(vm.suggestions.count)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
            LazyVStack(spacing: 0) {
                ForEach(vm.suggestions) { suggestion in
                    SuggestionRow(suggestion: suggestion, vm: vm)
                    if suggestion.id != vm.suggestions.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
        }
    }
}

struct SuggestionRow: View {
    let suggestion: ProcessSuggestion
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.body.weight(.medium))
                Text(suggestion.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(ByteFormat.string(Int64(suggestion.reclaimBytes)))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.tint)
            Button("Quit") { vm.confirm(suggestion) }
                .help(suggestion.note)
                .disabled(vm.isTerminating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text("All processes")
                    .font(.headline)
                Text("\(vm.visibleProcesses.count)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
            LazyVStack(spacing: 0) {
                ForEach(vm.visibleProcesses) { sample in
                    ProcessRow(sample: sample, vm: vm)
                    Divider().padding(.leading, 14)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
        }
    }
}

struct ProcessRow: View {
    let sample: ProcessSample
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        HStack(spacing: 12) {
            if let icon = vm.icon(for: sample) {
                Image(nsImage: icon)
            } else {
                Image(systemName: "gearshape")
                    .foregroundStyle(.tertiary)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(sample.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("PID \(sample.pid) · \(sample.role.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(sample.metricsReadable ? String(format: "%.1f%%", sample.cpuPercent) : "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(sample.cpuPercent >= 20 ? .primary : .secondary)
                .frame(width: 56, alignment: .trailing)

            Text(sample.metricsReadable ? ByteFormat.string(Int64(sample.residentBytes)) : "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)

            if sample.isProtected {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 54)
                    .help("System process — Mac Utils won't quit this")
            } else {
                Menu {
                    Button("Quit") { vm.quit(sample: sample, force: false) }
                    Button("Force Quit", role: .destructive) { vm.quit(sample: sample, force: true) }
                    Divider()
                    Button("Reveal in Finder") {
                        guard !sample.executablePath.isEmpty else { return }
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [URL(fileURLWithPath: sample.executablePath)])
                    }
                } label: {
                    Text("Quit")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .frame(width: 54)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}
