import AppKit
import SwiftUI

struct SidebarResizeHandle: NSViewRepresentable {
    let sidebarWidth: CGFloat
    let widthRange: ClosedRange<CGFloat>
    let onResize: (CGFloat, Bool) -> Void

    func makeNSView(context: Context) -> SidebarResizeView {
        let view = SidebarResizeView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: SidebarResizeView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: SidebarResizeView) {
        view.sidebarWidth = sidebarWidth
        view.widthRange = widthRange
        view.onResize = onResize
    }
}

final class SidebarResizeView: NSView {
    var sidebarWidth = SidebarLayout.defaultWidth
    var widthRange = SidebarLayout.minimumWidth...SidebarLayout.maximumWidth
    var onResize: ((CGFloat, Bool) -> Void)?
    private var dragStartWidth: CGFloat?
    private var dragStartX: CGFloat?

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for e: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with e: NSEvent) {
        dragStartWidth = sidebarWidth
        dragStartX = e.locationInWindow.x
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with e: NSEvent) {
        guard let width = draggedWidth(for: e) else { return }
        onResize?(width, false)
        NSCursor.resizeLeftRight.set()
    }

    override func mouseUp(with e: NSEvent) {
        guard let width = draggedWidth(for: e) else { return }
        onResize?(width, true)
        dragStartWidth = nil
        dragStartX = nil
    }

    private func draggedWidth(for e: NSEvent) -> CGFloat? {
        guard let dragStartWidth, let dragStartX else { return nil }
        return SidebarLayout.clamp(dragStartWidth + e.locationInWindow.x - dragStartX, to: widthRange)
    }
}
