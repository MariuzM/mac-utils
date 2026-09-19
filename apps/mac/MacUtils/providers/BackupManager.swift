import Foundation

struct BackupSummary: Sendable {
    let destination: URL
    let copied: Int
    let failed: Int
    let bytes: Int64
    let failures: [(path: String, reason: String)]
    let setupError: String?
    var cancelled = false
}

actor BackupManager {
    func run(items: [ScanItem], progress: @escaping @Sendable (Double, String) -> Void) async -> BackupSummary {
        let items = DeletionPolicy.uniqueItems(items)
        let fm = FileManager()
        let desktop =
            fm.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let root = desktop.appendingPathComponent("Mac Utils Backup \(Self.timestamp()) \(UUID().uuidString.prefix(6))")
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            return BackupSummary(
                destination: root, copied: 0, failed: items.count, bytes: 0,
                failures: [], setupError: "Could not create the backup folder: \(error.localizedDescription)")
        }

        var copied = 0
        var failed = 0
        var bytes: Int64 = 0
        var failures: [(path: String, reason: String)] = []
        let total = max(items.count, 1)

        for (i, item) in items.enumerated() {
            if Task.isCancelled { break }
            progress(Double(i) / Double(total), "Backing up \(item.name)…")

            let path = item.url.path
            let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
            let dest = root.appendingPathComponent(relative)

            do {
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: item.url, to: dest)
                copied += 1
                bytes += item.size
            } catch {
                failed += 1
                failures.append((path: path, reason: error.localizedDescription))
            }
        }

        progress(1.0, "Done")
        return BackupSummary(
            destination: root, copied: copied, failed: failed, bytes: bytes,
            failures: failures, setupError: nil, cancelled: Task.isCancelled)
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return f.string(from: Date())
    }
}
