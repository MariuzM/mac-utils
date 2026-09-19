import Foundation

enum DeletionPolicy {
    private static let protectedRoots: Set<String> = Set(
        [
            "/", "/System", "/Users", "/Library", "/bin", "/sbin", "/usr", "/etc", "/var",
            "/private", "/Applications", "/Volumes", "/cores", "/opt", "/tmp", "/private/tmp",
            "/private/var", "/private/var/tmp", "/private/var/folders", "/Library/Application Support",
            "/Library/Developer", "/Library/Caches", "/Library/Logs", "/Library/LaunchAgents",
            "/Library/LaunchDaemons", "/Library/PrivilegedHelperTools",
        ].flatMap { path in
            [
                path, URL(fileURLWithPath: path).standardizedFileURL.path,
                URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path,
            ]
        })

    static func contains(_ parent: String, _ child: String) -> Bool {
        child == parent || child.hasPrefix(parent == "/" ? "/" : parent + "/")
    }

    static func rejectionReason(_ url: URL) -> String? {
        guard url.isFileURL else { return "Only local files can be removed." }
        let path = url.standardizedFileURL.path
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for candidate in [path, resolved] {
            if protectedRoots.contains(candidate) || candidate == home || candidate == home + "/Library" {
                return "This is a protected top-level folder."
            }
            if contains("/System", candidate) || contains("/usr", candidate) || contains("/bin", candidate)
                || contains("/sbin", candidate) || contains("/private/etc", candidate) || contains("/etc", candidate)
            {
                return "Operating-system files cannot be removed."
            }
            if contains(SystemPaths.coreSimulator, candidate)
                || contains(home + "/Library/Developer/CoreSimulator/Devices", candidate)
            {
                return "Manage simulator devices and runtimes in Xcode Device Hub. Direct deletion is disabled."
            }
            if candidate.hasPrefix("/Volumes/"), candidate.dropFirst("/Volumes/".count).contains("/") == false {
                return "A mounted volume cannot be removed."
            }
        }
        if let volume = try? url.resourceValues(forKeys: [.volumeURLKey]).volume,
            volume.standardizedFileURL.path == path
        {
            return "A mounted volume cannot be removed."
        }
        return nil
    }

    static func uniqueItems(_ items: [ScanItem]) -> [ScanItem] {
        var paths = Set<String>()
        return items.sorted { $0.url.path.count < $1.url.path.count }.filter { item in
            let path = item.url.standardizedFileURL.path
            guard !paths.contains(where: { contains($0, path) }) else { return false }
            paths.insert(path)
            return true
        }
    }
}
