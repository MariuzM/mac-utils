import SwiftUI
import AppKit
import FolderKit

struct HeaderBar: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Utils")
                    .font(.headline)
                if vm.hasScanned && !vm.isScanning {
                    Text("\(ByteFormat.string(vm.totalReclaimable)) reclaimable · \(vm.totalItems) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if vm.isDeleting {
                    Text(vm.deletePhase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if vm.isBackingUp {
                    Text(vm.backupPhase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if vm.isScanning {
                    Text(vm.phase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Preview mode — nothing is deleted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if vm.isScanning {
                ProgressView(value: vm.fraction)
                    .frame(width: 140)
                Button("Cancel") { vm.cancel() }
            } else if vm.isBackingUp {
                ProgressView(value: vm.backupFraction)
                    .frame(width: 140)
                Button("Cancel") { vm.cancelBackup() }
            } else if vm.isDeleting {
                if vm.deleteIndeterminate {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    ProgressView(value: vm.deleteFraction)
                        .frame(width: 140)
                }
                Button("Cancel") { vm.cancelDelete() }
            } else {
                if !vm.consoleLines.isEmpty && !vm.showConsole {
                    Button {
                        vm.showConsole = true
                    } label: {
                        Label("Console", systemImage: "terminal")
                    }
                    .help("Show the activity log")
                }
                if vm.hasScanned && vm.totalItems > 0 {
                    Button(role: .destructive) {
                        vm.requestDelete(items: vm.selectedItems)
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .tint(.red)
                    .disabled(vm.selectedItems.isEmpty)
                    .help("Remove the checked categories — asks whether to Trash or delete permanently")

                    Button {
                        vm.backup(items: vm.selectedItems)
                    } label: {
                        Label("Back Up Selected", systemImage: "arrow.down.doc")
                    }
                    .disabled(vm.selectedItems.isEmpty)
                    .help("Copy the checked categories to a folder on your Desktop, preserving original paths")
                }
                Button {
                    vm.startScan()
                } label: {
                    Label(vm.hasScanned ? "Rescan" : "Scan", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
