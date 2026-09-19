import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.22, green: 0.42, blue: 0.91)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let border = Color.primary.opacity(0.08)
    static let radius: CGFloat = 16
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radius).strokeBorder(AppTheme.border)
            }
    }
}

struct PageHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
                Text(value).font(.system(size: 25, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                AppTheme.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45),
                in: RoundedRectangle(cornerRadius: 10))
    }
}
