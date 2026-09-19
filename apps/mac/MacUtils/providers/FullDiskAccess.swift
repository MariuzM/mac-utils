import AppKit
import Darwin
import Foundation

struct DiskAccessStatus {
    let checked: Int
    let readable: Int
    let issues: [FileIssue]

    var title: String {
        if !issues.isEmpty { return "Some protected locations are unavailable" }
        if checked == 0 { return "Protected-data access could not be checked" }
        return "Protected-data check passed"
    }
}

enum FullDiskAccess {
    static func inspect(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskAccessStatus {
        var checked = 0
        var readable = 0
        var issues: [FileIssue] = []
        for path in ["Library/Mail", "Library/Messages", "Library/Safari"] {
            let url = home.appendingPathComponent(path)
            errno = 0
            guard let directory = opendir(url.path) else {
                let code = errno
                if code != ENOENT {
                    checked += 1
                    issues.append(
                        .from(NSError(domain: NSPOSIXErrorDomain, code: Int(code)), at: url, operation: "Access check"))
                }
                continue
            }
            checked += 1
            errno = 0
            _ = readdir(directory)
            let code = errno
            closedir(directory)
            if code == 0 {
                readable += 1
            } else {
                issues.append(
                    .from(NSError(domain: NSPOSIXErrorDomain, code: Int(code)), at: url, operation: "Access check"))
            }
        }
        return DiskAccessStatus(checked: checked, readable: readable, issues: issues)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    static func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
}
