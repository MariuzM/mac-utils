import AppKit
import SwiftUI

struct SpotlightView: View {
    @ObservedObject var vm: SpotlightViewModel

    var body: some View {
        VStack(spacing: 0) {
            SpotlightHeaderBar(vm: vm)
            Divider()
            content
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if vm.loaded && !vm.isWorking { vm.refreshIfExpectingChange() }
        }
        .alert("Couldn’t read Spotlight privacy", isPresented: $vm.showError, presenting: vm.lastError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !vm.loaded {
            SpotlightLoadState(isWorking: vm.isWorking) { vm.refresh() }
        } else if vm.folders.isEmpty {
            SpotlightEmptyState { vm.openSettings() }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SpotlightEditHint { vm.openSettings() }
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(vm.folders) { folder in
                            SpotlightRow(folder: folder, vm: vm)
                            if folder.id != vm.folders.last?.id {
                                Divider().padding(.leading, 44)
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
                .padding(20)
            }
        }
    }
}

struct SpotlightHeaderBar: View {
    @ObservedObject var vm: SpotlightViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Spotlight Privacy")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if vm.isWorking {
                ProgressView().controlSize(.small)
            }

            if vm.loaded {
                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isWorking)
                .help("Reload the list from the system")

                Button {
                    vm.openSettings()
                } label: {
                    Label("Edit in System Settings", systemImage: "gearshape")
                }
                .buttonStyle(PrimaryActionStyle())
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var subtitle: String {
        if vm.isWorking && !vm.status.isEmpty { return vm.status }
        if !vm.loaded { return "Mirrors the System Settings › Spotlight › Privacy list" }
        if vm.folders.isEmpty { return "No folders excluded from Spotlight indexing" }
        return "\(vm.folders.count) folder\(vm.folders.count == 1 ? "" : "s") excluded from indexing"
    }
}

struct SpotlightEditHint: View {
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(
                "This is the live system list. To add or remove folders, edit it in System Settings — changes appear here automatically."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Open", action: onOpen)
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SpotlightRow: View {
    let folder: SpotlightFolder
    @ObservedObject var vm: SpotlightViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(folder.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(folder.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()

            Text("Excluded")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(Color.green)
                .clipShape(Capsule())

            Button {
                vm.reveal(folder)
            } label: {
                Image(systemName: "arrow.forward.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SpotlightLoadState: View {
    let isWorking: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Spotlight Privacy")
                .font(.title3.weight(.semibold))
            Text(
                "Shows the folders excluded from Spotlight in System Settings › Spotlight › Privacy. Reading this list is protected by macOS, so you’ll be asked for your password once."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 440)
            Button(action: onLoad) {
                Label("Load Current List", systemImage: "lock.open")
            }
            .buttonStyle(PrimaryActionStyle())
            .controlSize(.large)
            .disabled(isWorking)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct SpotlightEmptyState: View {
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("No folders excluded")
                .font(.title3.weight(.semibold))
            Text(
                "Nothing is currently excluded from Spotlight. Add folders in System Settings › Spotlight › Privacy and they’ll show up here."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
            Button(action: onOpen) {
                Label("Open System Settings", systemImage: "gearshape")
            }
            .buttonStyle(PrimaryActionStyle())
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
