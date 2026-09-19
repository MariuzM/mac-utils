import SwiftUI

struct CleanerHeaderActions: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
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
                IconButton(systemName: "terminal", help: "Show the activity log") {
                    vm.showConsole = true
                }
            }
            if vm.hasScanned && vm.totalItems > 0 {
                Button {
                    vm.backup(items: vm.selectedItems)
                } label: {
                    Label("Back Up", systemImage: "arrow.down.doc")
                }
                .disabled(vm.selectedItems.isEmpty)
                .help("Copy the checked items to a folder on your Desktop, preserving original paths")

                Button(role: .destructive) {
                    vm.requestDelete(items: vm.selectedItems)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(vm.selectedItems.isEmpty)
                .help("Remove the checked items — asks whether to Trash or delete permanently")
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
}
