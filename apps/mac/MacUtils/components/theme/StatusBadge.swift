import SwiftUI

struct StatusBadge: View {
    let title: String
    let color: Color
    var showsDot = true

    var body: some View {
        HStack(spacing: 5) {
            if showsDot {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(showsDot ? Color.primary : color)
        .padding(.horizontal, 7)
        .frame(minHeight: 18)
        .background(color.opacity(0.13), in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct Notice: View {
    let text: String
    let symbol: String
    var color: Color = .orange

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .strokeBorder(color.opacity(0.18))
        }
    }
}

struct BannerBar<Content: View>: View {
    var color: Color = .orange
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.07))
            Divider()
        }
    }
}
