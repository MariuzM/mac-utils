import SwiftUI

struct AppSidebarRow: View {
    let section: AppSection
    let isSelected: Bool
    let badge: String?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: section.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary)
                    .frame(width: 16)
                Text(section.title)
                    .font(.system(size: AppTheme.rowFontSize + 1))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .frame(minHeight: 16)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                        .fixedSize()
                }
            }
            .padding(.horizontal, 8)
            .frame(height: AppTheme.rowHeight)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: AppTheme.rowRadius, style: .continuous)
                    .fill(background)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier("navigation.\(section.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected { return AppTheme.accent.opacity(0.18) }
        return isHovered ? Color.primary.opacity(0.05) : .clear
    }
}
