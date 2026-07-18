import AppKit
import CoreGraphics

final class DockTap {
    private let lock = NSLock()
    private var overriddenPaths: Set<String> = []

    var onIntercept: ((DockFolderItem) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var swallowNextMouseUp = false

    init() {}

    deinit { stop() }

    func setOverriddenPaths(_ paths: Set<String>) {
        lock.lock()
        overriddenPaths = paths
        lock.unlock()
    }

    private func isOverridden(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return overriddenPaths.contains(url.standardizedFileURL.path)
    }

    func start() {
        guard tap == nil, DockAX.isTrusted else { return }

        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<DockTap>.fromOpaque(context).takeUnretainedValue()
                return tap.handle(type: type, event: event)
            },
            userInfo: context
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        swallowNextMouseUp = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseUp {
            guard swallowNextMouseUp else { return Unmanaged.passUnretained(event) }
            swallowNextMouseUp = false
            return nil
        }

        guard type == .leftMouseDown else { return Unmanaged.passUnretained(event) }

        let location = event.location
        guard let item = DockAX.folderItem(at: location), isOverridden(item.url)
        else { return Unmanaged.passUnretained(event) }

        swallowNextMouseUp = true
        let handler = onIntercept
        DispatchQueue.main.async { handler?(item) }
        return nil
    }
}
