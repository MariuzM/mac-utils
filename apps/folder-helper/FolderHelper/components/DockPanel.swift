import AppKit
import FolderKit
import SwiftUI

final class DockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class DockPanelController {
    private static let reopenSuppressionWindow: TimeInterval = 0.35

    private var panel: DockPanel?
    private var outsideMonitor: Any?
    private var lastClosedID: String?
    private var lastClosedAt: Date?

    init() {}

    func toggle(for item: DockFolderItem, store: FolderStore) {
        if let panel, panel.isVisible, panel.identifier?.rawValue == item.id {
            close()
            return
        }

        if lastClosedID == item.id, let lastClosedAt,
            Date().timeIntervalSince(lastClosedAt) < Self.reopenSuppressionWindow
        {
            self.lastClosedID = nil
            self.lastClosedAt = nil
            return
        }

        show(for: item, store: store)
    }

    func show(for item: DockFolderItem, store: FolderStore) {
        close()

        let content = FolderMenuView(store: store, root: item.url) { [weak self] in
            self?.close()
        }

        let hosting = NSHostingView(rootView: content)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let panel = DockPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier(item.id)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameOrigin(origin(for: item, size: size))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            self?.close()
        }

        self.panel = panel
    }

    func close() {
        if let outsideMonitor {
            NSEvent.removeMonitor(outsideMonitor)
        }
        outsideMonitor = nil
        if let panel {
            lastClosedID = panel.identifier?.rawValue
            lastClosedAt = Date()
        }
        panel?.orderOut(nil)
        panel = nil
    }

    private func origin(for item: DockFolderItem, size: NSSize) -> NSPoint {
        guard let primary = NSScreen.screens.first else { return .zero }

        let iconTopInCocoa = primary.frame.maxY - item.frame.minY
        var x = item.frame.midX - size.width / 2
        var y = iconTopInCocoa + 8

        let screen =
            NSScreen.screens.first {
                $0.frame.contains(NSPoint(x: item.frame.midX, y: primary.frame.maxY - item.frame.midY))
            } ?? primary

        x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
        y = max(screen.visibleFrame.minY + 8, min(y, screen.visibleFrame.maxY - size.height - 8))

        return NSPoint(x: x, y: y)
    }
}
