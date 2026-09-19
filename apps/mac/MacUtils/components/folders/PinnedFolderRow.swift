import AppKit
import FolderKit
import SwiftUI

struct PinnedFolderRow: View {
    let folder: PinnedFolder
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            FolderLabel(title: folder.name, path: folder.path)
            Spacer()
            IconButton(systemName: "trash", help: "Unpin folder", role: .destructive, action: onDelete)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

struct FolderLabel: View {
    let title: String
    let path: String

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
    }
}
