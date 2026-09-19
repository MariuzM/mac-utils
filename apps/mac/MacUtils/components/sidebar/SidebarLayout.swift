import CoreGraphics

enum SidebarLayout {
    static let defaultWidth: CGFloat = 220
    static let minimumWidth: CGFloat = 180
    static let maximumWidth: CGFloat = 320
    static let minimumDetailWidth: CGFloat = 640
    static let resizeHandleWidth: CGFloat = 10
    static let topInset: CGFloat = 44

    static func clamp(_ width: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        let lowerBound = range.lowerBound.rounded(.up)
        let upperBound = range.upperBound.rounded(.down)
        return min(max(width.rounded(), lowerBound), upperBound)
    }
}
