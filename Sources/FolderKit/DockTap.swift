import AppKit
import CoreGraphics

public final class DockTap {
    public var shouldIntercept: ((URL) -> Bool)?
    public var onIntercept: ((DockFolderItem) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var swallowNextMouseUp = false

    public init() {}

    public var isRunning: Bool { tap != nil }

    public func start() {
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

    public func stop() {
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
        let item = DockAX.folderItem(at: location)
        let intercept = item.map { shouldIntercept?($0.url) == true } ?? false

        guard let item, intercept
        else { return Unmanaged.passUnretained(event) }

        swallowNextMouseUp = true
        let handler = onIntercept
        DispatchQueue.main.async { handler?(item) }
        return nil
    }
}
