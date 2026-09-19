import SwiftUI

struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var width: CGFloat = 220

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 26)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct IconButton: View {
    let systemName: String
    let help: String
    var role: ButtonRole? = nil
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(role == .destructive ? Color.red : Color.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .background(
                    AppTheme.hover.opacity(isHovered && isEnabled ? 1 : 0),
                    in: RoundedRectangle(cornerRadius: AppTheme.rowRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
