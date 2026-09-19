import Darwin
import Foundation

struct FileIssue: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case permission, missing, readOnly, locked, protected, other
    }

    let path: String
    let operation: String
    let kind: Kind
    let reason: String

    var id: String { operation + ":" + path }
    var canRetryAsAdmin: Bool { kind == .permission }
    var description: String { "\(path) — \(reason)" }

    static func from(_ error: Error, at url: URL, operation: String) -> FileIssue {
        let e = error as NSError
        let posix = posixCode(e)
        let kind: Kind
        if posix == Int(ENOENT)
            || (e.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(e.code))
        {
            kind = .missing
        } else if posix == Int(EROFS) || (e.domain == NSCocoaErrorDomain && e.code == NSFileWriteVolumeReadOnlyError) {
            kind = .readOnly
        } else if posix == Int(EBUSY) || (e.domain == NSCocoaErrorDomain && e.code == NSFileLockingError) {
            kind = .locked
        } else if posix == Int(EACCES) || posix == Int(EPERM)
            || (e.domain == NSCocoaErrorDomain
                && [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(e.code))
        {
            kind = .permission
        } else {
            kind = .other
        }
        return FileIssue(path: url.path, operation: operation, kind: kind, reason: e.localizedDescription)
    }

    private static func posixCode(_ error: NSError) -> Int? {
        if error.domain == NSPOSIXErrorDomain { return error.code }
        guard let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError else { return nil }
        return underlying.domain == NSPOSIXErrorDomain ? underlying.code : nil
    }
}

final class ScanDiagnostics: @unchecked Sendable {
    private let lock = NSLock()
    private var issues: [String: FileIssue] = [:]
    private var affectedRoots = Set<String>()
    private var overflow = 0

    func record(_ error: Error, at url: URL, root: URL? = nil) {
        let issue = FileIssue.from(error, at: url, operation: "Scan")
        guard issue.kind != .missing else { return }
        lock.withLock {
            affectedRoots.insert((root ?? url).standardizedFileURL.path)
            if issues[issue.id] != nil { return }
            if issues.count < 100 { issues[issue.id] = issue } else { overflow += 1 }
        }
    }

    var snapshot: [FileIssue] { lock.withLock { issues.values.sorted { $0.path < $1.path } } }
    var omittedCount: Int { lock.withLock { overflow } }

    func isIncomplete(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return lock.withLock { affectedRoots.contains { DeletionPolicy.contains(path, $0) } }
    }
}
