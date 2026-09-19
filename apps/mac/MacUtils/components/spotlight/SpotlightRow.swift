import SwiftUI

struct SpotlightRow: View {
    let folder: SpotlightFolder
    @ObservedObject var vm: SpotlightViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(folder.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(folder.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            StatusBadge(title: "Excluded", color: .green, showsDot: false)
            IconButton(systemName: "arrow.up.forward.square", help: "Reveal in Finder") {
                vm.reveal(folder)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
