import Darwin
import Foundation

struct AdminDeleteResult: Sendable {
    let attempted: Int
    let removed: Int
    let cancelled: Bool
    let failed: [String]
    let rejected: [String]
    var issues: [FileIssue] = []

    var accessDeniedPaths: [String] { issues.filter { $0.kind == .permission }.map(\.path) }
    var message: String {
        var parts = ["Removed \(removed) of \(attempted) items."]
        if cancelled {
            parts.append("Cancelled. A system-authorized operation may still be finishing; rescan before retrying.")
        }
        if !rejected.isEmpty { parts.append("Refused \(rejected.count) protected locations.") }
        if !issues.isEmpty { parts.append(issues.prefix(5).map(\.description).joined(separator: "\n")) }
        if !accessDeniedPaths.isEmpty {
            parts.append(
                "Access was denied. Full Disk Access, folder permissions, locked files, or system protection can cause this. Administrator access does not bypass macOS privacy controls."
            )
        }
        return parts.joined(separator: "\n\n")
    }
}

final class AdminDeleter: @unchecked Sendable {
    private let lock = NSLock()
    private var runner: CommandRunner?
    private var cancelled = false
    private let privilegedExecutor: (@Sendable (String) async -> ShellResult)?

    init(privilegedExecutor: (@Sendable (String) async -> ShellResult)? = nil) {
        self.privilegedExecutor = privilegedExecutor
    }

    func cancel() {
        let active = lock.withLock {
            cancelled = true
            return runner
        }
        active?.cancel()
    }

    private var isCancelled: Bool { lock.withLock { cancelled } }

    func run(
        paths: [String],
        log: @escaping @Sendable (String) -> Void,
        phase: @escaping @Sendable (String) -> Void
    ) async -> AdminDeleteResult {
        lock.withLock { cancelled = false }
        if Task.isCancelled { cancel() }
        let plan = Self.plan(for: paths, myUID: getuid(), fileManager: .default)
        var removed = 0
        var issues: [FileIssue] = []
        var elevated = plan.rootPaths
        for path in plan.rejected { log("Refused protected path: \(path)") }
        for path in plan.userPaths {
            if isCancelled || Task.isCancelled { break }
            phase("Removing \(URL(fileURLWithPath: path).lastPathComponent)…")
            if Self.isProtected(path) {
                issues.append(
                    FileIssue(
                        path: path, operation: "Remove", kind: .protected,
                        reason: "The path now resolves to a protected location."))
                continue
            }
            do {
                try FileManager.default.removeItem(atPath: path)
                removed += 1
                log("Removed \(path)")
            } catch {
                let issue = FileIssue.from(error, at: URL(fileURLWithPath: path), operation: "Remove")
                if issue.canRetryAsAdmin { elevated.append(path) } else { issues.append(issue) }
                log(issue.description)
            }
        }

        if !elevated.isEmpty && !isCancelled && !Task.isCancelled {
            phase("Waiting for administrator authorization…")
            let valid = elevated.filter { !Self.isProtected($0) }
            for path in elevated where Self.isProtected(path) {
                issues.append(
                    FileIssue(
                        path: path, operation: "Remove", kind: .protected,
                        reason: "The path now resolves to a protected location."))
            }
            if !valid.isEmpty {
                let command = Self.removalScript(paths: valid)
                let script = "do shell script \(Shell.appleScriptLiteral(command)) with administrator privileges"
                let status: Int32
                let out: String
                let err: String
                if let privilegedExecutor {
                    let result = await privilegedExecutor(command)
                    (status, out, err) = (result.status, result.stdout, result.stderr)
                } else {
                    (status, out, err) = await runProc(SystemPaths.osascript, ["-e", script], stream: false, log: log)
                }
                if Shell.indicatesCancellation(out + err) { cancel() }
                let outcomes = Self.removalOutcomes(out)
                let reasons = Self.removalErrors(out)
                for (i, path) in valid.enumerated() {
                    if outcomes[i] == true {
                        removed += 1
                        log("Removed \(path)")
                    } else if !isCancelled {
                        let reason = (reasons[i] ?? err).trimmingCharacters(in: .whitespacesAndNewlines)
                        let denied =
                            reason.localizedCaseInsensitiveContains("permission denied")
                            || reason.localizedCaseInsensitiveContains("operation not permitted")
                        issues.append(
                            FileIssue(
                                path: path, operation: "Administrator removal", kind: denied ? .permission : .other,
                                reason: reason.isEmpty
                                    ? "Removal could not be verified (exit \(status)). Rescan before retrying."
                                    : String(reason.prefix(1000))))
                    }
                }
                if status != 0 { log(err.isEmpty ? "Administrator command exited \(status)." : err) }
            }
        }
        return AdminDeleteResult(
            attempted: plan.rootPaths.count + plan.userPaths.count, removed: removed,
            cancelled: isCancelled || Task.isCancelled,
            failed: issues.map(\.path), rejected: plan.rejected, issues: issues)
    }

    static func removalScript(paths: [String]) -> String {
        "LC_ALL=C; export LC_ALL\n"
            + paths.enumerated().map { i, path in
                let quoted = Shell.quote(path)
                return """
                    error=$(/bin/rm -rf -- \(quoted) 2>&1)
                    status=$?
                    if [ "$status" -eq 0 ] && [ ! -e \(quoted) ] && [ ! -L \(quoted) ]; then
                        /usr/bin/printf 'MACUTILS_RESULT:\(i):ok\\n'
                    else
                        /usr/bin/printf 'MACUTILS_RESULT:\(i):failed\\nMACUTILS_ERROR:\(i):'
                        /usr/bin/printf '%s' "$error" | /usr/bin/base64 | /usr/bin/tr -d '\\n'
                        /usr/bin/printf '\\n'
                    fi
                    """
            }.joined(separator: "\n")
    }

    static func removalOutcomes(_ output: String) -> [Int: Bool] {
        var results: [Int: Bool] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":")
            guard parts.count == 3, parts[0] == "MACUTILS_RESULT", let i = Int(parts[1]),
                parts[2] == "ok" || parts[2] == "failed"
            else { continue }
            results[i] = parts[2] == "ok"
        }
        return results
    }

    static func removalErrors(_ output: String) -> [Int: String] {
        var errors: [Int: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0] == "MACUTILS_ERROR", let i = Int(parts[1]),
                let data = Data(base64Encoded: String(parts[2])), let message = String(data: data, encoding: .utf8)
            else { continue }
            errors[i] = message
        }
        return errors
    }

    func runProc(
        _ executable: String, _ arguments: [String], stream: Bool,
        log: (@Sendable (String) -> Void)?
    ) async -> (Int32, String, String) {
        let command = CommandRunner()
        lock.withLock {
            runner = command
            if cancelled { command.cancel() }
        }
        defer { lock.withLock { runner = nil } }
        let result = await command.runAsync(executable, arguments, timeout: 300, log: stream ? log : nil)
        return (result.status, result.stdout, result.stderr)
    }

    struct DeletionPlan: Equatable {
        var rootPaths: [String] = []
        var userPaths: [String] = []
        var rejected: [String] = []
    }

    static func isProtected(_ path: String) -> Bool {
        !path.hasPrefix("/") || DeletionPolicy.rejectionReason(URL(fileURLWithPath: path)) != nil
    }

    static func plan(for paths: [String], myUID: uid_t, fileManager: FileManager) -> DeletionPlan {
        var plan = DeletionPlan()
        var accepted = Set<String>()
        for path in paths.sorted(by: { $0.count < $1.count }) {
            guard !isProtected(path) else {
                plan.rejected.append(path)
                continue
            }
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            guard !accepted.contains(where: { DeletionPolicy.contains($0, normalized) }) else { continue }
            accepted.insert(normalized)
            let owner = (try? fileManager.attributesOfItem(atPath: normalized))?[.ownerAccountID] as? NSNumber
            if owner?.uint32Value == myUID {
                plan.userPaths.append(normalized)
            } else {
                plan.rootPaths.append(normalized)
            }
        }
        return plan
    }
}
