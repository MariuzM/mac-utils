import Foundation

enum DeleteMode: Sendable {
    case trash
    case permanent
}

struct DeleteSummary: Sendable {
    let mode: DeleteMode
    let deleted: Int
    let failed: Int
    let bytes: Int64
    let failures: [String]
}

actor DeleteManager {
    func run(items: [ScanItem], mode: DeleteMode, progress: @escaping @Sendable (Double, String) -> Void) async -> DeleteSummary {
        let fm = FileManager()
        var deleted = 0
        var failed = 0
        var bytes: Int64 = 0
        var failures: [String] = []
        let total = max(items.count, 1)

        for (i, item) in items.enumerated() {
            if Task.isCancelled { break }
            progress(Double(i) / Double(total), "Removing \(item.name)…")
            do {
                switch mode {
                case .trash:
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                case .permanent:
                    try fm.removeItem(at: item.url)
                }
                deleted += 1
                bytes += item.size
            } catch {
                failed += 1
                failures.append(item.url.path)
            }
        }

        progress(1.0, "Done")
        return DeleteSummary(mode: mode, deleted: deleted, failed: failed, bytes: bytes, failures: failures)
    }
}
