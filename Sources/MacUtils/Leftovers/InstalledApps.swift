import AppKit
import Foundation

struct InstalledIndex: Sendable {
    let bundleIDs: Set<String>
    let families: Set<String>
    let vendors: Set<String>

    func claims(_ bundleID: String) -> Bool {
        if bundleIDs.contains(bundleID) { return true }
        guard let family = InstalledApps.familyKey(bundleID) else { return true }
        return families.contains(family)
    }

    func vendorHasApps(_ bundleID: String) -> Bool {
        guard let vendor = InstalledApps.vendorKey(bundleID) else { return false }
        return vendors.contains(vendor)
    }
}

enum InstalledApps {
    private static let nestedDirectories = [
        "Contents/PlugIns", "Contents/XPCServices", "Contents/Library/LoginItems",
        "Contents/Library/QuickLook", "Contents/Library/Spotlight", "Contents/Library/Services",
        "Contents/Extensions", "Contents/Helpers", "Contents/Applications",
    ]

    private static let nestedExtensions: Set<String> = [
        "app", "appex", "xpc", "bundle", "qlgenerator", "plugin", "service",
    ]

    private static let strippedSuffixes = [
        "-mac", "-macos", "-osx", "-desktop", "-setapp", "-trial", "-beta", "-new", "-app",
    ]

    static func applicationRoots() -> [URL] {
        let fm = FileManager.default
        var roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
        let volumes =
            fm.mountedVolumeURLs(
                includingResourceValuesForKeys: [.volumeIsLocalKey], options: [.skipHiddenVolumes]) ?? []
        for volume in volumes {
            let candidate = volume.appendingPathComponent("Applications")
            if fm.fileExists(atPath: candidate.path) { roots.append(candidate) }
        }
        var seen = Set<String>()
        return roots.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func index(diagnostics: ScanDiagnostics? = nil) -> InstalledIndex {
        var ids = Set<String>()
        for root in applicationRoots() {
            collect(in: root, folderDepth: 0, into: &ids, diagnostics: diagnostics)
        }
        var families = Set<String>()
        var vendors = Set<String>()
        for id in ids {
            if let family = familyKey(id) { families.insert(family) }
            if let vendor = vendorKey(id) { vendors.insert(vendor) }
        }
        return InstalledIndex(bundleIDs: ids, families: families, vendors: vendors)
    }

    private static func collect(
        in directory: URL, folderDepth: Int, into ids: inout Set<String>, diagnostics: ScanDiagnostics?
    ) {
        let children = contents(of: directory, diagnostics: diagnostics)

        for child in children {
            if Task.isCancelled { return }
            if child.pathExtension == "app" {
                harvest(child, depth: 0, into: &ids, diagnostics: diagnostics)
            } else if folderDepth < 2, (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                collect(in: child, folderDepth: folderDepth + 1, into: &ids, diagnostics: diagnostics)
            }
        }
    }

    private static func harvest(_ bundle: URL, depth: Int, into ids: inout Set<String>, diagnostics: ScanDiagnostics?) {
        if let id = bundleIdentifier(at: bundle) { ids.insert(id) }
        guard depth < 2 else { return }
        for nested in nestedDirectories {
            let directory = bundle.appendingPathComponent(nested)
            let children = contents(of: directory, diagnostics: diagnostics)
            for child in children where nestedExtensions.contains(child.pathExtension) {
                harvest(child, depth: depth + 1, into: &ids, diagnostics: diagnostics)
            }
        }
    }

    private static func contents(of directory: URL, diagnostics: ScanDiagnostics?) -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        } catch {
            diagnostics?.record(error, at: directory)
            return []
        }
    }

    static func bundleIdentifier(at url: URL) -> String? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
            let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = object as? [String: Any]
        else { return nil }
        return dictionary["CFBundleIdentifier"] as? String
    }

    static func normalize(_ raw: String) -> String {
        var id = raw
        if let range = teamPrefixRange(in: id) { id.removeSubrange(range) }
        for prefix in ["group.", "groups."] where id.hasPrefix(prefix) {
            id.removeFirst(prefix.count)
        }
        return id
    }

    private static func teamPrefixRange(in id: String) -> Range<String.Index>? {
        guard let dot = id.firstIndex(of: ".") else { return nil }
        let prefix = id[id.startIndex..<dot]
        guard prefix.count == 10,
            prefix.allSatisfy({ $0.isUppercase && $0.isLetter || $0.isNumber })
        else { return nil }
        return id.startIndex..<id.index(after: dot)
    }

    static func normalizeComponent(_ component: String) -> String {
        var value = component.lowercased()
        for suffix in strippedSuffixes where value.hasSuffix(suffix) && value.count > suffix.count {
            value.removeLast(suffix.count)
            break
        }
        return value
    }

    static func isBundleIDShaped(_ id: String) -> Bool {
        let parts = id.split(separator: ".")
        guard parts.count >= 3, !id.contains(" "), !id.hasPrefix(".") else { return false }
        guard let first = parts.first, first == first.lowercased() else { return false }
        return !id.hasPrefix("com.apple.")
    }

    static func familyKey(_ id: String) -> String? {
        let parts = id.split(separator: ".").map(String.init)
        guard parts.count >= 2, let first = parts.first, first == first.lowercased() else { return nil }
        return parts.prefix(3).map(normalizeComponent).joined(separator: ".")
    }

    static func vendorKey(_ id: String) -> String? {
        let parts = id.split(separator: ".").map(String.init)
        guard parts.count >= 2, let first = parts.first, first == first.lowercased() else { return nil }
        return parts.prefix(2).map(normalizeComponent).joined(separator: ".")
    }
}
