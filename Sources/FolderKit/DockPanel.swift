import AppKit
import SwiftUI

public final class DockPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
}

@MainActor
public final class DockPanelController {
    private var panel: DockPanel?
    private var outsideMonitor: Any?

    public init() {}

    public func toggle(for item: DockFolderItem, store: FolderStore) {
        if let panel, panel.isVisible, panel.identifier?.rawValue == item.id {
            close()
            return
        }
        show(for: item, store: store)
    }

    public func show(for item: DockFolderItem, store: FolderStore) {
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

        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }

        self.panel = panel
    }

    public func close() {
        if let outsideMonitor {
            NSEvent.removeMonitor(outsideMonitor)
        }
        outsideMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func origin(for item: DockFolderItem, size: NSSize) -> NSPoint {
        guard let primary = NSScreen.screens.first else { return .zero }

        let iconTopInCocoa = primary.frame.maxY - item.frame.minY
        var x = item.frame.midX - size.width / 2
        var y = iconTopInCocoa + 8

        let screen = NSScreen.screens.first {
            $0.frame.contains(NSPoint(x: item.frame.midX, y: primary.frame.maxY - item.frame.midY))
        } ?? primary

        x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
        y = min(y, screen.visibleFrame.maxY - size.height - 8)

        return NSPoint(x: x, y: y)
    }
}
