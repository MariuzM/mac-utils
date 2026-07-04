import Foundation

struct ScanRule {
    let id: String
    let title: String
    let subtitle: String
    let safety: SafetyLevel
    let paths: [URL]
    let expandChildren: Bool
}

enum ScanRules {
    static func homeRules() -> [ScanRule] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let dev = lib.appendingPathComponent("Developer")

        func exists(_ url: URL) -> Bool {
            FileManager.default.fileExists(atPath: url.path)
        }

        func rule(_ id: String, _ title: String, _ subtitle: String, _ safety: SafetyLevel, _ paths: [URL], expand: Bool = true) -> ScanRule? {
            let present = paths.filter(exists)
            guard !present.isEmpty else { return nil }
            return ScanRule(id: id, title: title, subtitle: subtitle, safety: safety, paths: present, expandChildren: expand)
        }

        let candidates: [ScanRule?] = [
            rule("user-caches", "User Caches", "App caches in ~/Library/Caches — regenerated on demand.", .safe,
                 [lib.appendingPathComponent("Caches")]),

            rule("logs", "Logs", "Application and diagnostic logs.", .safe,
                 [lib.appendingPathComponent("Logs")]),

            rule("trash", "Trash", "Items already in the Trash.", .safe,
                 [home.appendingPathComponent(".Trash")]),

            rule("xcode-derived", "Xcode DerivedData", "Build intermediates and indexes — Xcode rebuilds them.", .safe,
                 [dev.appendingPathComponent("Xcode/DerivedData")]),

            rule("xcode-cache", "Xcode Cache", "Xcode's own app cache.", .safe,
                 [lib.appendingPathComponent("Caches/com.apple.dt.Xcode")]),

            rule("xcode-previews", "SwiftUI Previews Cache", "Cached preview builds — regenerated on demand.", .safe,
                 [dev.appendingPathComponent("Xcode/UserData/Previews")]),

            rule("xcode-docs", "Documentation Cache", "Downloaded Xcode documentation.", .safe,
                 [dev.appendingPathComponent("Xcode/DocumentationCache"),
                  lib.appendingPathComponent("Developer/Shared/Documentation/DocSets")]),

            rule("swiftpm-cache", "SwiftPM Cache", "Swift Package Manager clones and download cache.", .safe,
                 [lib.appendingPathComponent("Caches/org.swift.swiftpm"),
                  lib.appendingPathComponent("org.swift.swiftpm")]),

            rule("carthage-cache", "Carthage Cache", "Cached Carthage dependency builds.", .safe,
                 [lib.appendingPathComponent("Caches/org.carthage.CarthageKit")]),

            rule("xcode-archives", "Xcode Archives", "Old app archives — review before removing.", .review,
                 [dev.appendingPathComponent("Xcode/Archives")]),

            rule("xcode-devicesupport", "Device Support", "Symbol caches per iOS/watchOS version.", .caution,
                 [dev.appendingPathComponent("Xcode/iOS DeviceSupport"),
                  dev.appendingPathComponent("Xcode/watchOS DeviceSupport"),
                  dev.appendingPathComponent("Xcode/macOS DeviceSupport"),
                  dev.appendingPathComponent("Xcode/tvOS DeviceSupport")]),

            rule("simulator-caches", "Simulator Caches", "CoreSimulator caches and simulator logs.", .safe,
                 [dev.appendingPathComponent("CoreSimulator/Caches"),
                  lib.appendingPathComponent("Logs/CoreSimulator")]),

            rule("simulator-devices", "Simulator Devices", "Installed simulator runtimes and their data — removing wipes simulator state.", .review,
                 [dev.appendingPathComponent("CoreSimulator/Devices")]),

            rule("ios-backups", "iOS Device Backups", "Local device backups — verify these aren't your only copy.", .review,
                 [lib.appendingPathComponent("Application Support/MobileSync/Backup")]),

            rule("homebrew", "Homebrew Cache", "Downloaded formula bottles and archives.", .safe,
                 [lib.appendingPathComponent("Caches/Homebrew")]),

            rule("dev-package-caches", "Dev Package Caches", "npm / bun / pnpm / yarn / gradle / cocoapods download caches.", .safe,
                 [home.appendingPathComponent(".npm/_cacache"),
                  home.appendingPathComponent(".bun/install/cache"),
                  lib.appendingPathComponent("pnpm/store"),
                  home.appendingPathComponent(".cache/yarn"),
                  home.appendingPathComponent(".gradle/caches"),
                  lib.appendingPathComponent("Caches/CocoaPods"),
                  home.appendingPathComponent(".cargo/registry/cache")]),

            rule("temp", "Temporary Files", "Per-user temporary items.", .caution,
                 [URL(fileURLWithPath: NSTemporaryDirectory())]),
        ]

        return candidates.compactMap { $0 }
    }

    static func systemRules() -> [ScanRule] {
        func exists(_ url: URL) -> Bool {
            FileManager.default.fileExists(atPath: url.path)
        }

        func rule(_ id: String, _ title: String, _ subtitle: String, _ safety: SafetyLevel, _ paths: [String], expand: Bool = true) -> ScanRule? {
            let urls = paths.map { URL(fileURLWithPath: $0) }.filter(exists)
            guard !urls.isEmpty else { return nil }
            return ScanRule(id: id, title: title, subtitle: subtitle, safety: safety, paths: urls, expandChildren: expand)
        }

        let candidates: [ScanRule?] = [
            rule("sys-caches", "System Caches", "Shared caches in /Library/Caches — needs Full Disk Access.", .caution,
                 ["/Library/Caches"]),

            rule("sys-logs", "System Logs", "Log files in /Library/Logs.", .safe,
                 ["/Library/Logs"]),

            rule("sys-diagnostics", "Diagnostic Reports", "Crash and spin reports.", .safe,
                 ["/Library/Logs/DiagnosticReports"]),

            rule("var-log", "Unix Logs", "System logs in /private/var/log — some are active.", .caution,
                 ["/private/var/log"]),

            rule("tmp", "System Temp", "Temporary files in /private/tmp and /private/var/tmp.", .caution,
                 ["/private/tmp", "/private/var/tmp"]),

            rule("var-folders", "Darwin Cache & Temp", "Per-session caches/temp in /private/var/folders — needs Full Disk Access.", .caution,
                 ["/private/var/folders"]),

            rule("cores", "Core Dumps", "Crash core dumps in /cores.", .safe,
                 ["/cores"]),

            rule("sys-simulator", "Shared Simulator Runtimes", "System-wide simulator runtimes — removing wipes them.", .review,
                 ["/Library/Developer/CoreSimulator"]),
        ]

        return candidates.compactMap { $0 }
    }

    static func volumeRules(for volume: URL) -> [ScanRule] {
        func exists(_ url: URL) -> Bool {
            FileManager.default.fileExists(atPath: url.path)
        }

        var rules: [ScanRule] = []
        let trashes = volume.appendingPathComponent(".Trashes")
        if exists(trashes) {
            rules.append(ScanRule(id: "vol-trashes",
                                  title: "Trashes",
                                  subtitle: "Per-volume trash folder.",
                                  safety: .safe,
                                  paths: [trashes],
                                  expandChildren: true))
        }
        return rules
    }
}
