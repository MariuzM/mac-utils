import SwiftUI

struct SiriView: View {
    @ObservedObject var vm: SiriViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        PageScaffold(title: AppSection.siri.title, subtitle: AppSection.siri.subtitle) {
            if vm.isWorking { ProgressView().controlSize(.small) }
            Button {
                vm.refresh()
            } label: {
                Label("Recheck", systemImage: "arrow.clockwise")
            }
            .help("Check current Siri settings and services")
            .disabled(vm.isWorking)
        } content: {
            PageScroll(spacing: 16, maxWidth: 860) {
                Surface(padding: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.tint)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Siri & Siri AI").font(.headline)
                                Text("For your macOS account").font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(title: vm.snapshot?.summary ?? "Not checked", color: statusColor)
                        }

                        Text(
                            "Turn off Siri and Siri cloud sync, block its startup services, and stop the current Siri processes. Your previous settings are saved before anything changes."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button(action: vm.disable) {
                                Label("Disable Siri", systemImage: "mic.slash")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.isWorking || vm.snapshot?.fullyDisabled == true)
                            .accessibilityIdentifier("siri.disable")

                            if vm.canRestore {
                                Button("Restore Previous Settings", action: vm.restore)
                                    .disabled(vm.isWorking)
                                    .accessibilityIdentifier("siri.restore")
                            }
                            if vm.isWorking {
                                Text(vm.activity).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let error = vm.error {
                    Notice(text: error, symbol: "exclamationmark.triangle", color: .red)
                }
                if let snapshot = vm.snapshot, snapshot.restartNeeded {
                    Notice(
                        text:
                            "macOS is keeping a protected service running. Its startup is blocked. Sign out and back in, then choose Recheck to verify the result.",
                        symbol: "arrow.clockwise.circle")
                }

                if let snapshot = vm.snapshot {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Verified on this Mac", symbol: "checkmark.shield") {
                            Text(snapshot.checkedAt, style: .time).font(.caption).foregroundStyle(.secondary)
                        }
                        ListCard {
                            HStack {
                                Label("Siri settings & cloud sync", systemImage: "slider.horizontal.3")
                                    .font(.callout.weight(.medium))
                                Spacer()
                                StatusBadge(
                                    title: snapshot.settingsOff ? "Off" : "Not fully off",
                                    color: snapshot.settingsOff ? .green : .orange)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            ForEach(snapshot.services) { state in
                                RowDivider()
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(state.service.name).font(.callout.weight(.medium))
                                        Text(state.id)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                    Spacer()
                                    Text(state.disabled ? "Startup blocked" : "Startup allowed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    StatusBadge(
                                        title: state.running ? "Running" : "Stopped",
                                        color: state.running ? .orange : .green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                            }
                        }
                    }
                }

                if !vm.details.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Operation details", symbol: "list.bullet.rectangle")
                        Surface {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(vm.details.enumerated()), id: \.offset) { _, detail in
                                    Text(detail)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }

                Surface {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About downloaded models", systemImage: "internaldrive").font(.headline)
                        Text(
                            "Disabling Siri does not remove downloaded models or all Apple Intelligence features. macOS shares and protects these assets. This control keeps system protections enabled; model removal is not performed."
                        )
                        .font(.callout).foregroundStyle(.secondary)
                        Text(
                            "Blocking Siri AI can also affect its Spotlight integration. Restore returns the settings and service startup states saved by Mac Utils."
                        )
                        .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { vm.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.refresh() }
        }
    }

    private var statusColor: Color {
        guard let snapshot = vm.snapshot else { return .secondary }
        return snapshot.fullyDisabled ? .green : .orange
    }
}
