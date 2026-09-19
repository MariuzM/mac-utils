import SwiftUI

struct Surface<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .strokeBorder(AppTheme.border)
            }
    }
}

struct ListCard<Content: View>: View {
    var clipsContent = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: clipsContent ? AppTheme.radius : 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .strokeBorder(AppTheme.border)
        }
    }
}
