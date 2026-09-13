import SwiftUI

struct SiriView: View {
    @ObservedObject var vm: SiriViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    PageHeading(
                        title: "Siri Controls", subtitle: "Disable Siri and check its settings and services.")
                    Button {
                        vm.refresh()
                    } label: {
                        Label("Recheck", systemImage: "arrow.clockwise")
                    }
                    .help("Check current Siri settings and services")
                    .disabled(vm.isWorking)
                }

                Surface {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 16) {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 64, height: 64)
                                .background(AppTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Siri & Siri AI").font(.title2.weight(.semibold))
                                Text("For your macOS account").foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(title: vm.snapshot?.summary ?? "Not checked", color: statusColor)
                        }

                        Text(
                            "Turn off Siri and Siri cloud sync, block its startup services, and stop the current Siri processes. Your previous settings are saved before anything changes."
                        )
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Button(action: vm.disable) {
                                Label("Disable Siri", systemImage: "mic.slash")
                            }
                            .buttonStyle(PrimaryActionStyle())
                            .controlSize(.large)
                            .disabled(vm.isWorking || vm.snapshot?.fullyDisabled == true)
                            .accessibilityIdentifier("siri.disable")

                            if vm.canRestore {
                                Button("Restore previous settings", action: vm.restore)
                                    .controlSize(.large)
                                    .disabled(vm.isWorking)
                                    .accessibilityIdentifier("siri.restore")
                            }
                            if vm.isWorking { ProgressView().controlSize(.small) }
                        }
                        if vm.isWorking { Text(vm.activity).font(.callout).foregroundStyle(.secondary) }
                    }
                }

                if let error = vm.error {
                    notice(error, symbol: "exclamationmark.triangle", color: .red)
                }
                if let snapshot = vm.snapshot, snapshot.restartNeeded {
                    notice(
                        "macOS is keeping a protected service running. Its startup is blocked. Sign out and back in, then choose Recheck to verify the result.",
                        symbol: "arrow.clockwise.circle", color: .orange)
                }
                if !vm.details.isEmpty {
                    Surface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Operation details").font(.headline)
                            ForEach(Array(vm.details.enumerated()), id: \.offset) { _, detail in
                                Text(detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }

                if let snapshot = vm.snapshot {
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Verified on this Mac").font(.headline)
                                Spacer()
                                Text(snapshot.checkedAt, style: .time).font(.caption).foregroundStyle(.secondary)
                            }
                            HStack {
                                Label("Siri settings & cloud sync", systemImage: "slider.horizontal.3")
                                Spacer()
                                StatusBadge(
                                    title: snapshot.settingsOff ? "Off" : "Not fully off",
                                    color: snapshot.settingsOff ? .green : .orange)
                            }
                            ForEach(snapshot.services) { state in
                                Divider()
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(state.service.name).font(.callout.weight(.medium))
                                        Text(state.id).font(.caption).foregroundStyle(.secondary).textSelection(
                                            .enabled)
                                    }
                                    Spacer()
                                    Text(state.disabled ? "Startup blocked" : "Startup allowed")
                                        .font(.caption).foregroundStyle(.secondary)
                                    StatusBadge(
                                        title: state.running ? "Running" : "Stopped",
                                        color: state.running ? .orange : .green)
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
            .padding(30)
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

    private func notice(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(color)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
