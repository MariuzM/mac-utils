import Darwin
import Foundation

struct ScanRule: Sendable {
    let id: String
    let title: String
    let subtitle: String
    let safety: SafetyLevel
    let paths: [URL]
    let expandChildren: Bool
    var minimumAgeDays: Int? = nil

    func includes(_ url: URL, now: Date = Date()) -> Bool {
        guard let days = minimumAgeDays else { return true }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
            values.isRegularFile == true, let modified = values.contentModificationDate
        else { return false }
        return modified < now.addingTimeInterval(-Double(days) * 86_400)
    }
}

enum ScanRules {
    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func rule(
        _ id: String, _ title: String, _ subtitle: String, _ safety: SafetyLevel,
        _ paths: [URL], expand: Bool = true
    ) -> ScanRule? {
        let present = paths.filter { url in
            var info = stat()
            return lstat(url.path, &info) == 0 || errno != ENOENT
        }
        guard !present.isEmpty else { return nil }
        return ScanRule(
            id: id, title: title, subtitle: subtitle, safety: safety, paths: present, expandChildren: expand)
    }

    static func rule(
        _ id: String, _ title: String, _ subtitle: String, _ safety: SafetyLevel,
        _ paths: [String], expand: Bool = true
    ) -> ScanRule? {
        rule(id, title, subtitle, safety, paths.map { URL(fileURLWithPath: $0) }, expand: expand)
    }

    static func homeRules() -> [ScanRule] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let dev = lib.appendingPathComponent("Developer")

        let candidates: [ScanRule?] = [
            rule(
                "user-caches", "User Caches", "App caches in ~/Library/Caches. Quit affected apps before removing.",
                .caution,
                [lib.appendingPathComponent("Caches")]),

            rule(
                "logs", "Logs", "Application and diagnostic logs. Review active app logs before removing.", .caution,
                [lib.appendingPathComponent("Logs")]),

            rule(
                "trash", "Trash", "Items already in the Trash.", .safe,
                [home.appendingPathComponent(".Trash")]),

            rule(
                "xcode-derived", "Xcode DerivedData",
                "Build intermediates and indexes. Close Xcode and stop builds before removing.", .caution,
                [dev.appendingPathComponent("Xcode/DerivedData")]),

            rule(
                "xcode-cache", "Xcode Cache", "Xcode's own app cache.", .safe,
                [lib.appendingPathComponent("Caches/com.apple.dt.Xcode")]),

            rule(
                "xcode-previews", "SwiftUI Previews Cache", "Cached preview builds — regenerated on demand.", .safe,
                [dev.appendingPathComponent("Xcode/UserData/Previews")]),

            rule(
                "xcode-docs", "Documentation Cache", "Downloaded Xcode documentation.", .safe,
                [
                    dev.appendingPathComponent("Xcode/DocumentationCache"),
                    lib.appendingPathComponent("Developer/Shared/Documentation/DocSets"),
                ]),

            rule(
                "swiftpm-cache", "SwiftPM Cache",
                "Swift Package Manager clones and download cache. Stop builds before removing.", .caution,
                [
                    lib.appendingPathComponent("Caches/org.swift.swiftpm"),
                    lib.appendingPathComponent("org.swift.swiftpm"),
                ]),

            rule(
                "carthage-cache", "Carthage Cache", "Cached Carthage dependency builds.", .safe,
                [lib.appendingPathComponent("Caches/org.carthage.CarthageKit")]),

            rule(
                "xcode-archives", "Xcode Archives", "Old app archives — review before removing.", .review,
                [dev.appendingPathComponent("Xcode/Archives")]),

            rule(
                "xcode-devicesupport", "Device Support", "Symbol caches per iOS/watchOS version.", .caution,
                [
                    dev.appendingPathComponent("Xcode/iOS DeviceSupport"),
                    dev.appendingPathComponent("Xcode/watchOS DeviceSupport"),
                    dev.appendingPathComponent("Xcode/macOS DeviceSupport"),
                    dev.appendingPathComponent("Xcode/tvOS DeviceSupport"),
                ]),

            rule(
                "simulator-caches", "Simulator Caches", "CoreSimulator caches and simulator logs.", .safe,
                [
                    dev.appendingPathComponent("CoreSimulator/Caches"),
                    lib.appendingPathComponent("Logs/CoreSimulator"),
                ]),

            rule(
                "ios-backups", "iOS Device Backups", "Local device backups — verify these aren't your only copy.",
                .review,
                [lib.appendingPathComponent("Application Support/MobileSync/Backup")]),

            rule(
                "homebrew", "Homebrew Cache", "Downloaded formula bottles and archives.", .safe,
                [lib.appendingPathComponent("Caches/Homebrew")]),

            rule(
                "dev-package-caches", "Dev Package Caches",
                "npm / bun / pnpm / yarn / gradle / cocoapods caches. Stop builds and package installs first.",
                .caution,
                [
                    home.appendingPathComponent(".npm/_cacache"),
                    home.appendingPathComponent(".bun/install/cache"),
                    lib.appendingPathComponent("pnpm/store"),
                    home.appendingPathComponent(".cache/yarn"),
                    home.appendingPathComponent(".gradle/caches"),
                    lib.appendingPathComponent("Caches/CocoaPods"),
                    home.appendingPathComponent(".cargo/registry/cache"),
                ]),

        ]

        return candidates.compactMap { $0 } + extraHomeRules(home: home)
            + [
                ScanRule(
                    id: "old-user-temp", title: "Older Temporary Files",
                    subtitle:
                        "Regular files unchanged for at least 30 days. Folders are excluded; review before removing.",
                    safety: .review, paths: [URL(fileURLWithPath: NSTemporaryDirectory())], expandChildren: true,
                    minimumAgeDays: 30)
            ]
    }

    static func extraHomeRules(home: URL) -> [ScanRule] {
        let library = home.appendingPathComponent("Library")
        let editors = ["Code", "Code - Insiders", "Cursor", "VSCodium"]
        let editorPaths = editors.flatMap { editor in
            ["Cache", "CachedData", "CachedExtensionVSIXs", "GPUCache", "DawnCache", "logs"].map {
                library.appendingPathComponent("Application Support/\(editor)/\($0)")
            }
        }
        return [
            rule(
                "editor-caches", "Editor Caches",
                "VS Code and Cursor caches and logs. Quit editors first; settings, extensions, and workspaces are excluded.",
                .caution, editorPaths),
            rule(
                "npm-logs", "npm Logs", "Package installation debug logs.", .safe,
                [home.appendingPathComponent(".npm/_logs")]),
            rule(
                "maven-cache", "Maven Repository",
                "Downloaded dependencies and locally installed artifacts. Local-only artifacts may not be recoverable.",
                .review, [home.appendingPathComponent(".m2/repository")]),
            rule(
                "nuget-cache", "NuGet Packages",
                "Downloaded packages. Restoring projects may need network access and private feeds.", .review,
                [home.appendingPathComponent(".nuget/packages")]),
            rule(
                "huggingface-cache", "Hugging Face Downloads",
                "Models and datasets. Downloads can be large; check offline requirements before removing.", .review,
                [
                    home.appendingPathComponent(".cache/huggingface/hub"),
                    home.appendingPathComponent(".cache/huggingface/datasets"),
                ]),
        ].compactMap { $0 }
    }

    static func systemRules() -> [ScanRule] {

        let candidates: [ScanRule?] = [
            rule(
                "sys-caches", "System Caches",
                "Shared app caches. Some items may require administrator or privacy access.", .caution,
                ["/Library/Caches"]),

            rule(
                "sys-logs", "System Logs", "Log files in /Library/Logs. Some may be in active use.", .caution,
                ["/Library/Logs"]),

            rule(
                "sys-diagnostics", "Diagnostic Reports", "Crash and spin reports.", .safe,
                ["/Library/Logs/DiagnosticReports"]),

            rule(
                "cores", "Core Dumps", "Crash core dumps in /cores.", .safe,
                ["/cores"]),

        ]

        return candidates.compactMap { $0 }
    }

    static func orphanedPlists(in directory: URL) -> [URL] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return
            contents
            .filter { $0.pathExtension == "plist" && isOrphanedPlist($0) }
            .sorted { $0.path < $1.path }
    }

    static func isOrphanedPlist(_ url: URL, diagnostics: ScanDiagnostics? = nil) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            guard let dictionary = plist as? [String: Any] else { return false }
            return isOrphanedJob(dictionary)
        } catch {
            diagnostics?.record(error, at: url)
            return false
        }
    }

    static func isOrphanedJob(_ plist: [String: Any]) -> Bool {
        guard plist["BundleProgram"] == nil else { return false }
        guard let program = launchdProgram(plist), program.hasPrefix("/") else { return false }
        guard !program.hasPrefix("/Volumes/") else { return false }
        var info = stat()
        let status = lstat(program, &info)
        return status != 0 && errno == ENOENT
    }

    static func launchdProgram(_ plist: [String: Any]) -> String? {
        if let program = plist["Program"] as? String, !program.isEmpty { return program }
        if let arguments = plist["ProgramArguments"] as? [String],
            let first = arguments.first, !first.isEmpty
        {
            return first
        }
        return nil
    }

    static func volumeRules(for volume: URL) -> [ScanRule] {

        let trash = volume.appendingPathComponent(".Trashes/\(getuid())")
        return [rule("vol-trashes", "Trash", "Trash for your account on this volume.", .safe, [trash])].compactMap {
            $0
        }
    }
}
