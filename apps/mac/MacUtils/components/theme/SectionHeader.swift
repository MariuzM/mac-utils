import SwiftUI

struct SectionHeader<Trailing: View>: View {
    let title: String
    var symbol: String? = nil
    var count: Int? = nil
    @ViewBuilder var trailing: Trailing

    init(
        _ title: String,
        symbol: String? = nil,
        count: Int? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.symbol = symbol
        self.count = count
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 16)
            }
            Text(title)
                .font(.headline)
            if let count {
                CountBadge(count: count)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 2)
    }
}

struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .frame(minHeight: 16)
            .background(Color.primary.opacity(0.07), in: Capsule())
    }
}

struct RowDivider: View {
    var leading: CGFloat = 12

    var body: some View {
        Divider().padding(.leading, leading)
    }
}
