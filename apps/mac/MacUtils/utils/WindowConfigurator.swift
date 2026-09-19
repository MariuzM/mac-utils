import AppKit
import SwiftUI

final class WindowConfiguringView: NSView {
    nonisolated private static let frameKey = "MainWindowFrame"
    nonisolated(unsafe) private var frameObservers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeFrameObservers()
        guard let window else { return }
        applyConfiguration(to: window)
        restoreFrame(of: window)
        trackFrame(of: window)
    }

    deinit {
        removeFrameObservers()
    }

    nonisolated private func removeFrameObservers() {
        for observer in frameObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        frameObservers = []
    }

    private func restoreFrame(of window: NSWindow) {
        guard let saved = UserDefaults.standard.string(forKey: Self.frameKey) else { return }
        let frame = NSRectFromString(saved)
        guard frame.width > 0, frame.height > 0 else { return }
        window.setFrame(frame, display: true)
    }

    private func trackFrame(of window: NSWindow) {
        let center = NotificationCenter.default
        frameObservers = [
            NSWindow.didMoveNotification,
            NSWindow.didResizeNotification,
            NSWindow.willCloseNotification,
        ].map {
            center.addObserver(forName: $0, object: window, queue: .main) { [weak window] _ in
                MainActor.assumeIsolated {
                    guard let window else { return }
                    UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: WindowConfiguringView.frameKey)
                }
            }
        }
    }

    private func applyConfiguration(to window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowConfiguringView {
        WindowConfiguringView()
    }

    func updateNSView(_ nsView: WindowConfiguringView, context: Context) {}
}
