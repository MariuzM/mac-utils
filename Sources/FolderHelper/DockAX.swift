import AppKit
import ApplicationServices

struct DockFolderItem: Identifiable, Hashable {
    let title: String
    let url: URL
    let frame: CGRect

    var id: String { url.path }
}

enum DockAX {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }


    static func folderItems() -> [DockFolderItem] {
        guard isTrusted,
              let pid = NSRunningApplication
                  .runningApplications(withBundleIdentifier: "com.apple.dock")
                  .first?.processIdentifier
        else { return [] }

        let dock = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(dock, 0.25)

        guard let lists = attribute(dock, kAXChildrenAttribute) as? [AXUIElement] else { return [] }

        var items: [DockFolderItem] = []
        for list in lists {
            guard let children = attribute(list, kAXChildrenAttribute) as? [AXUIElement] else { continue }
            for child in children {
                guard attribute(child, kAXSubroleAttribute) as? String == "AXFolderDockItem",
                      let url = attribute(child, "AXURL") as? URL,
                      let frame = frame(of: child)
                else { continue }
                let title = attribute(child, kAXTitleAttribute) as? String ?? url.lastPathComponent
                items.append(DockFolderItem(title: title, url: url, frame: frame))
            }
        }
        return items
    }

    static func folderItem(at point: CGPoint) -> DockFolderItem? {
        folderItems().first { $0.frame.contains(point) }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let rawPosition = attribute(element, kAXPositionAttribute),
              let rawSize = attribute(element, kAXSizeAttribute)
        else { return nil }

        guard CFGetTypeID(rawPosition as CFTypeRef) == AXValueGetTypeID(),
              CFGetTypeID(rawSize as CFTypeRef) == AXValueGetTypeID()
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(rawPosition as! AXValue, .cgPoint, &origin),
              AXValueGetValue(rawSize as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0
        else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
