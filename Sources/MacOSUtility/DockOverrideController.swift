import AppKit
import Combine

@MainActor
final class DockOverrideController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var trusted = DockAX.isTrusted

    private let tap = DockTap()
    private let panels = DockPanelController()
    private let store: FolderStore
    private var trustTimer: Timer?

    init(store: FolderStore) {
        self.store = store

        tap.shouldIntercept = { [weak store] url in
            store?.isDockOverridden(url) ?? false
        }
        tap.onIntercept = { [weak self] item in
            guard let self else { return }
            self.panels.toggle(for: item, store: self.store)
        }
    }

    func refreshTrust() {
        trusted = DockAX.isTrusted
        sync()
    }

    func requestTrust() {
        DockAX.requestTrust()
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { return }
                if DockAX.isTrusted {
                    timer.invalidate()
                    self.refreshTrust()
                }
            }
        }
    }

    func sync() {
        let wanted = trusted && !store.dockOverrides.isEmpty
        if wanted && !tap.isRunning {
            tap.start()
        } else if !wanted && tap.isRunning {
            tap.stop()
            panels.close()
        }
        isRunning = tap.isRunning
    }

    func stop() {
        tap.stop()
        panels.close()
        isRunning = false
    }
}
