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
    var issues: [FileIssue] = []
    var cancelled = false

    var retryablePaths: [String] { issues.filter(\.canRetryAsAdmin).map(\.path) }
}

actor DeleteManager {
    func run(items: [ScanItem], mode: DeleteMode, progress: @escaping @Sendable (Double, String) -> Void) async
        -> DeleteSummary
    {
        let items = DeletionPolicy.uniqueItems(items)
        let fm = FileManager()
        var deleted = 0
        var failed = 0
        var bytes: Int64 = 0
        var failures: [String] = []
        var issues: [FileIssue] = []
        let total = max(items.count, 1)

        for (i, item) in items.enumerated() {
            if Task.isCancelled { break }
            progress(Double(i) / Double(total), "Removing \(item.name)…")
            do {
                if let reason = DeletionPolicy.rejectionReason(item.url) {
                    failed += 1
                    failures.append(item.url.path)
                    issues.append(FileIssue(path: item.url.path, operation: "Remove", kind: .protected, reason: reason))
                    continue
                }
                guard item.isComplete else {
                    failed += 1
                    failures.append(item.url.path)
                    issues.append(
                        FileIssue(
                            path: item.url.path, operation: "Remove", kind: .other,
                            reason:
                                "This folder was only partially scanned. Resolve scan errors and rescan before removing it."
                        ))
                    continue
                }
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
                issues.append(.from(error, at: item.url, operation: "Remove"))
            }
        }

        progress(1.0, "Done")
        return DeleteSummary(
            mode: mode, deleted: deleted, failed: failed, bytes: bytes, failures: failures, issues: issues,
            cancelled: Task.isCancelled)
    }
}
