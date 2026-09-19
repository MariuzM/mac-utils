import SwiftUI

struct PageScaffold<Actions: View, Banner: View, Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions
    @ViewBuilder var banner: Banner
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() },
        @ViewBuilder banner: () -> Banner = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
        self.banner = banner()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: title, subtitle: subtitle) { actions }
            Divider()
            banner
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct PageHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                actions
            }
            .controlSize(.regular)
        }
        .padding(.horizontal, AppTheme.pagePadding)
        .padding(.top, AppTheme.windowTopInset + 8)
        .padding(.bottom, 14)
    }
}

struct PageScroll<Content: View>: View {
    var spacing: CGFloat = 20
    var maxWidth: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(AppTheme.pagePadding)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: maxWidth == nil ? .leading : .top)
        }
    }
}
