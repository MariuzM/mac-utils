import AppKit
import Foundation

enum LeftoverConfidence: String, Sendable, Hashable {
    case confirmed
    case review

    var label: String {
        switch self {
        case .confirmed: return "Confirmed orphan"
        case .review: return "Review first"
        }
    }
}

struct LeftoverItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let evidence: String
    let size: Int64
    let confidence: LeftoverConfidence
    let needsAdmin: Bool

    var id: String { url.path }

    var scanItem: ScanItem {
        ScanItem(
            url: url, name: name, size: size,
            isDirectory: (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true)
    }
}

struct LeftoverGroup: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let confidence: LeftoverConfidence
    var items: [LeftoverItem]

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

actor LeftoverScanner {
    private let fm = FileManager.default
    private var diagnostics = ScanDiagnostics()

    var scanIssues: [FileIssue] { diagnostics.snapshot }
    var omittedIssueCount: Int { diagnostics.omittedCount }

    private struct DataSurface {
        let id: String
        let title: String
        let icon: String
        let directory: URL
        let suffix: String?
    }

    func scan(progress: @escaping @Sendable (String) -> Void) async -> [LeftoverGroup] {
        diagnostics = ScanDiagnostics()
        progress("Indexing installed apps…")
        let index = InstalledApps.index(diagnostics: diagnostics)
        guard !Task.isCancelled else { return [] }

        var groups: [LeftoverGroup] = []

        progress("Checking startup items…")
        groups.append(contentsOf: launchdGroups())
        groups.append(contentsOf: privilegedHelperGroups(index))

        progress("Checking system add-ons…")
        groups.append(contentsOf: addOnGroups(index))

        progress("Checking app data…")
        groups.append(contentsOf: appDataGroups(index, progress: progress))

        return groups.compactMap { group in
            var updated = group
            updated.items.removeAll { diagnostics.isIncomplete($0.url) }
            return updated.items.isEmpty ? nil : updated
        }
    }

    // MARK: - Confirmed: launchd jobs whose program is gone

    private func launchdGroups() -> [LeftoverGroup] {
        let directories = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
        ]

        var items: [LeftoverItem] = []
        for directory in directories {
            for plist in children(in: directory).filter({
                $0.pathExtension == "plist" && ScanRules.isOrphanedPlist($0, diagnostics: diagnostics)
            }
            ) {
                let target = launchdTarget(plist) ?? "its program"
                items.append(
                    LeftoverItem(
                        url: plist,
                        name: plist.deletingPathExtension().lastPathComponent,
                        evidence: "Starts \(target), which is not installed",
                        size: size(of: plist),
                        confidence: .confirmed,
                        needsAdmin: !DeletionPolicy.contains(fm.homeDirectoryForCurrentUser.path, plist.path)))
            }
        }

        guard !items.isEmpty else { return [] }
        return [
            LeftoverGroup(
                id: "launchd",
                title: "Startup Items",
                subtitle: "Launch agents and daemons that still try to start a program you removed.",
                icon: "power",
                confidence: .confirmed,
                items: items.sorted { $0.name < $1.name })
        ]
    }

    private func launchdTarget(_ plist: URL) -> String? {
        guard let data = try? Data(contentsOf: plist),
            let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = object as? [String: Any]
        else { return nil }
        return ScanRules.launchdProgram(dictionary)
    }

    // MARK: - Confirmed: privileged helpers with no daemon and no app

    private func privilegedHelperGroups(_ index: InstalledIndex) -> [LeftoverGroup] {
        let directory = URL(fileURLWithPath: "/Library/PrivilegedHelperTools")
        let helpers =
            children(in: directory)
        guard !helpers.isEmpty else { return [] }

        let referenced = referencedHelperPaths()

        var items: [LeftoverItem] = []
        for helper in helpers {
            if Task.isCancelled { break }
            let label = helper.lastPathComponent
            guard !referenced.contains(helper.path) else { continue }
            guard !index.claims(label) else { continue }
            items.append(
                LeftoverItem(
                    url: helper,
                    name: label,
                    evidence: "No launch daemon refers to it and no installed app matches it",
                    size: size(of: helper),
                    confidence: .review,
                    needsAdmin: true))
        }

        guard !items.isEmpty else { return [] }
        return [
            LeftoverGroup(
                id: "privileged-helpers",
                title: "Privileged Helper Tools",
                subtitle: "Helpers with no matching app or launch daemon. Review before removing.",
                icon: "lock.shield",
                confidence: .review,
                items: items.sorted { $0.name < $1.name })
        ]
    }

    private func referencedHelperPaths() -> Set<String> {
        var referenced = Set<String>()
        for directory in ["/Library/LaunchDaemons", "/Library/LaunchAgents"] {
            let plists = children(in: URL(fileURLWithPath: directory))
            for plist in plists where plist.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: plist),
                    let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
                    let dictionary = object as? [String: Any],
                    let program = ScanRules.launchdProgram(dictionary)
                else { continue }
                referenced.insert(program)
            }
        }
        return referenced
    }

    // MARK: - Review: system add-ons whose vendor app is gone

    private func addOnGroups(_ index: InstalledIndex) -> [LeftoverGroup] {
        let home = fm.homeDirectoryForCurrentUser
        let surfaces: [(String, String, String, [URL])] = [
            (
                "prefpanes", "Preference Panes", "slider.horizontal.3",
                [
                    home.appendingPathComponent("Library/PreferencePanes"),
                    URL(fileURLWithPath: "/Library/PreferencePanes"),
                ]
            ),
            (
                "kexts", "Kernel Extensions", "cpu",
                [URL(fileURLWithPath: "/Library/Extensions")]
            ),
            (
                "audio", "Audio Plug-ins", "waveform",
                [
                    URL(fileURLWithPath: "/Library/Audio/Plug-Ins/HAL"),
                    URL(fileURLWithPath: "/Library/Audio/Plug-Ins/Components"),
                    home.appendingPathComponent("Library/Audio/Plug-Ins/Components"),
                ]
            ),
            (
                "quicklook", "Quick Look Plug-ins", "eye",
                [
                    home.appendingPathComponent("Library/QuickLook"),
                    URL(fileURLWithPath: "/Library/QuickLook"),
                ]
            ),
            (
                "inputmethods", "Input Methods", "keyboard",
                [
                    home.appendingPathComponent("Library/Input Methods"),
                    URL(fileURLWithPath: "/Library/Input Methods"),
                ]
            ),
            (
                "screensavers", "Screen Savers", "display",
                [
                    home.appendingPathComponent("Library/Screen Savers"),
                    URL(fileURLWithPath: "/Library/Screen Savers"),
                ]
            ),
            (
                "internetplugins", "Internet Plug-ins", "globe",
                [
                    home.appendingPathComponent("Library/Internet Plug-Ins"),
                    URL(fileURLWithPath: "/Library/Internet Plug-Ins"),
                ]
            ),
        ]

        return surfaces.compactMap { id, title, icon, directories in
            var items: [LeftoverItem] = []
            for directory in directories {
                let children =
                    children(in: directory)
                for child in children {
                    if Task.isCancelled { break }
                    guard !child.pathExtension.isEmpty else { continue }
                    guard let bundleID = InstalledApps.bundleIdentifier(at: child) else { continue }
                    guard InstalledApps.isBundleIDShaped(bundleID), !index.claims(bundleID) else { continue }
                    items.append(
                        LeftoverItem(
                            url: child,
                            name: child.lastPathComponent,
                            evidence: "\(bundleID) — no installed app matches this vendor",
                            size: size(of: child),
                            confidence: .review,
                            needsAdmin: !DeletionPolicy.contains(fm.homeDirectoryForCurrentUser.path, child.path)))
                }
            }
            guard !items.isEmpty else { return nil }
            return LeftoverGroup(
                id: id, title: title,
                subtitle: "Installed by an app that is no longer on this Mac.",
                icon: icon, confidence: .review,
                items: items.sorted { $0.name < $1.name })
        }
    }

    // MARK: - Review: per-app data keyed by bundle identifier

    private func appDataGroups(
        _ index: InstalledIndex,
        progress: @escaping @Sendable (String) -> Void
    ) -> [LeftoverGroup] {
        let home = fm.homeDirectoryForCurrentUser
        let surfaces = [
            DataSurface(
                id: "containers", title: "App Containers", icon: "shippingbox",
                directory: home.appendingPathComponent("Library/Containers"), suffix: nil),
            DataSurface(
                id: "groupcontainers", title: "Group Containers", icon: "square.stack.3d.up",
                directory: home.appendingPathComponent("Library/Group Containers"), suffix: nil),
            DataSurface(
                id: "appsupport", title: "Application Support", icon: "folder",
                directory: home.appendingPathComponent("Library/Application Support"), suffix: nil),
            DataSurface(
                id: "prefs", title: "Preferences", icon: "gearshape",
                directory: home.appendingPathComponent("Library/Preferences"), suffix: ".plist"),
            DataSurface(
                id: "savedstate", title: "Saved Application State", icon: "clock.arrow.circlepath",
                directory: home.appendingPathComponent("Library/Saved Application State"),
                suffix: ".savedState"),
            DataSurface(
                id: "httpstorages", title: "Cookies & Web Storage", icon: "network",
                directory: home.appendingPathComponent("Library/HTTPStorages"), suffix: nil),
            DataSurface(
                id: "webkit", title: "WebKit Data", icon: "safari",
                directory: home.appendingPathComponent("Library/WebKit"), suffix: nil),
            DataSurface(
                id: "appcaches", title: "App Caches", icon: "internaldrive",
                directory: home.appendingPathComponent("Library/Caches"), suffix: nil),
        ]

        return surfaces.compactMap { surface in
            progress("Checking \(surface.title)…")
            let children =
                children(in: surface.directory)

            var items: [LeftoverItem] = []
            for child in children {
                if Task.isCancelled { break }
                var raw = child.lastPathComponent
                if let suffix = surface.suffix {
                    guard raw.hasSuffix(suffix) else { continue }
                    raw = String(raw.dropLast(suffix.count))
                }
                let bundleID = InstalledApps.normalize(raw)
                guard InstalledApps.isBundleIDShaped(bundleID), !index.claims(bundleID) else { continue }

                let related =
                    index.vendorHasApps(bundleID)
                    ? " — other apps from this vendor are still installed, so check before removing"
                    : ""
                items.append(
                    LeftoverItem(
                        url: child,
                        name: raw,
                        evidence: "No installed app claims \(bundleID)\(related)",
                        size: size(of: child),
                        confidence: .review,
                        needsAdmin: false))
            }

            guard !items.isEmpty else { return nil }
            return LeftoverGroup(
                id: surface.id, title: surface.title,
                subtitle: "Data left behind by apps that are no longer installed.",
                icon: surface.icon, confidence: .review,
                items: items.sorted { $0.size > $1.size })
        }
    }

    private func children(in directory: URL) -> [URL] {
        do {
            return try fm.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        } catch {
            diagnostics.record(error, at: directory)
            return []
        }
    }

    private func size(of url: URL) -> Int64 {
        ScanEngine.entrySize(
            url, isDirectory: (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
            diagnostics: diagnostics)
    }
}
