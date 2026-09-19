import SwiftUI

struct PerformanceView: View {
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        PageScaffold(title: AppSection.performance.title, subtitle: subtitle) {
            Toggle("Background only", isOn: $vm.showBackgroundOnly)
                .toggleStyle(.checkbox)
                .fixedSize()
                .help("Hide regular applications")

            Picker("Sort", selection: $vm.sortKey) {
                ForEach(ProcessSortKey.allCases) { key in
                    Text(key.rawValue).tag(key)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)

            SearchField(prompt: "Search processes", text: $vm.search, width: 200)
        } content: {
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

    private var subtitle: String {
        guard vm.loaded else { return "Reading running processes…" }
        let yours = vm.samples.filter { !$0.isProtected }.count
        let base = "\(vm.samples.count) processes · \(yours) yours"
        guard vm.totalReclaimable > 0 else { return base }
        return base + " · \(ByteFormat.string(Int64(vm.totalReclaimable))) in suggested processes"
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
            LoadingStateView(message: "Sampling processes…")
        } else {
            PageScroll {
                if !vm.suggestions.isEmpty {
                    SuggestionSection(vm: vm)
                }
                ProcessListSection(vm: vm)
            }
        }
    }
}
