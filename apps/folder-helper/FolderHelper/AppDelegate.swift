import AppKit
import FolderKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = FolderStore()
    private let tap = DockTap()
    private let panels = DockPanelController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var observer: NSObjectProtocol?
    private var trustTimer: Timer?
    private var hasPrompted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        tap.onIntercept = { [weak self] item in
            guard let self else { return }
            self.closePopover()
            self.panels.toggle(for: item, store: self.store)
        }

        observer = SharedConfig.observeConfigChanged { [weak self] in
            guard let self else { return }
            self.store.reloadFromDisk()
            self.sync()
        }

        sync()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
        stopTrustPolling()
        tap.stop()
        panels.close()
    }

    private func sync() {
        let wantsDockOverride = !store.dockOverrides.isEmpty
        publishTrustState()
        tap.setOverriddenPaths(store.dockOverrides)

        if !wantsDockOverride {
            hasPrompted = false
        }

        if wantsDockOverride && !DockAX.isTrusted {
            if !hasPrompted {
                hasPrompted = true
                DockAX.requestTrust()
            }
            startTrustPolling()
        }

        if !wantsDockOverride || !DockAX.isTrusted {
            if !wantsDockOverride {
                stopTrustPolling()
            }
            tap.stop()
            panels.close()
        } else {
            stopTrustPolling()
            tap.start()
        }

        let menuBarEnabled = SharedConfig.defaults.object(forKey: FolderStore.enabledKey) as? Bool ?? true
        if menuBarEnabled {
            installStatusItem()
        } else {
            removeStatusItem()
        }
    }

    private func publishTrustState() {
        let trusted = DockAX.isTrusted
        guard SharedConfig.defaults.object(forKey: SharedConfig.helperTrustedKey) as? Bool != trusted else { return }
        SharedConfig.defaults.set(trusted, forKey: SharedConfig.helperTrustedKey)
        SharedConfig.postConfigChanged()
    }

    private func startTrustPolling() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, DockAX.isTrusted else { return }
                self.stopTrustPolling()
                self.sync()
            }
        }
    }

    private func stopTrustPolling() {
        trustTimer?.invalidate()
        trustTimer = nil
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Folders")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
    }

    private func removeStatusItem() {
        closePopover()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    @objc private func togglePopover() {
        if let popover, popover.isShown {
            closePopover()
            return
        }
        guard let button = statusItem?.button else { return }

        let content = FolderMenuView(store: store) { [weak self] in
            self?.closePopover()
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: content)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
    }

    private func closePopover() {
        popover?.performClose(nil)
        popover = nil
    }
}
