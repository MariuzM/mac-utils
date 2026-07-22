import SwiftUI
import AppKit
import FolderKit

struct ConsolePanel: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Console")
                    .font(.caption.weight(.semibold))
                if vm.isDeleting {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                Button("Clear") { vm.clearConsole() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    vm.showConsole = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide console")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(vm.consoleLines.enumerated()), id: \.offset) { i, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(i)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .onChange(of: vm.consoleLines.count) { _ in
                    if let last = vm.consoleLines.indices.last {
                        withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
        .frame(height: 190)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func color(for line: String) -> Color {
        if line.hasPrefix("✓") { return .green }
        if line.hasPrefix("✗") || line.hasPrefix("FAILED") { return .red }
        if line.hasPrefix("⚠︎") || line.localizedCaseInsensitiveContains("full disk access") { return .orange }
        if line.hasPrefix("…") || line.hasPrefix("→") || line.hasPrefix("──") || line.hasPrefix("⏹") {
            return .secondary
        }
        return .primary
    }
}
