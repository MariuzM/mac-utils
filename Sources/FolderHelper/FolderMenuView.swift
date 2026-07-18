import FolderKit
import SwiftUI
import AppKit

struct FolderMenuView: View {
    @ObservedObject var store: FolderStore
    let root: URL?
    let onClose: (() -> Void)?

    @State private var stack: [URL]
    @State private var entries: [FolderEntry] = []
    @State private var unreadableReason: String?

    init(store: FolderStore, root: URL? = nil, onClose: (() -> Void)? = nil) {
        self.store = store
        self.root = root
        self.onClose = onClose
        _stack = State(initialValue: root.map { [$0] } ?? [])
    }

    private var canGoBack: Bool {
        stack.count > (root == nil ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    if stack.isEmpty {
                        rootRows
                    } else {
                        directoryRows
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 560)
            Divider()
            footer
        }
        .frame(width: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { reload() }
        .onChange(of: stack) { _ in reload() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if canGoBack {
                Button {
                    stack.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
            }
            Text(stack.last?.lastPathComponent ?? "Folders")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var rootRows: some View {
        ForEach(store.folders) { folder in
            let entry = FolderEntry(url: folder.url, isDirectory: true)
            FolderRow(entry: entry) {
                stack.append(folder.url)
            } menu: {
                openMenuItems(for: entry)
                Divider()
                Button("Remove from List") { store.unpin(folder) }
            }
        }
    }

    private var directoryRows: some View {
        Group {
            if let unreadableReason {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Can't read this folder", systemImage: "lock")
                        .foregroundStyle(.orange)
                    Text(unreadableReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            } else if entries.isEmpty {
                Text("Empty folder")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            ForEach(entries) { entry in
                FolderRow(entry: entry) {
                    if entry.isDirectory {
                        stack.append(entry.url)
                    } else {
                        NSWorkspace.shared.open(entry.url)
                        onClose?()
                    }
                } menu: {
                    openMenuItems(for: entry)
                }
            }
        }
    }

    @ViewBuilder
    private func openMenuItems(for entry: FolderEntry) -> some View {
        ForEach(ExternalApp.allCases.filter(\.isInstalled)) { app in
            Button("Open in \(app.title)") {
                app.open(entry)
                onClose?()
            }
        }
        Divider()
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([entry.url])
            onClose?()
        }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.url.path, forType: .string)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if root == nil {
                Button("Add Folder…") { addFolder() }
                    .buttonStyle(.plain)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
            } else {
                Button("Open in Finder") {
                    if let current = stack.last {
                        NSWorkspace.shared.open(current)
                    }
                    onClose?()
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Copy Path") {
                    guard let current = stack.last else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(current.path, forType: .string)
                    onClose?()
                }
                .buttonStyle(.plain)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func addFolder() {
        store.pinFromOpenPanel(activate: true)
    }

    private func reload() {
        guard let current = stack.last else {
            entries = []
            unreadableReason = nil
            return
        }
        switch store.listing(of: current) {
        case .entries(let found):
            entries = found
            unreadableReason = nil
        case .unreadable(let reason):
            entries = []
            unreadableReason = reason
        }
    }
}

private struct FolderRow<Menu: View>: View {
    let entry: FolderEntry
    let action: () -> Void
    @ViewBuilder let menu: () -> Menu
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: entry.url.path))
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.accentColor.opacity(0.18) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu(menuItems: menu)
    }
}
