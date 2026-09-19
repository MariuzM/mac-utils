import SwiftUI

@MainActor
enum AppTheme {
    static var accent: Color { UIAppearancePreferences.shared.accentColor }
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let border = Color.primary.opacity(0.08)
    static let hover = Color.primary.opacity(0.08)
    static let radius: CGFloat = 10
    static let rowRadius: CGFloat = 6
    static let pagePadding: CGFloat = 24
    static let rowFontSize: CGFloat = 12
    static let rowHeight: CGFloat = 28
    static let windowTopInset: CGFloat = 28
}
