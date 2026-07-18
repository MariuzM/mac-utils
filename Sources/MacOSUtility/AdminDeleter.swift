import Foundation

struct AdminDeleteResult: Sendable {
    let attempted: Int
    let removed: Int
    let cancelled: Bool
    let needsFullDiskAccess: [String]
    let failed: [String]
    let rejected: [String]
}

private let adminProtectedRoots: Set<String> = [
    "/", "/System", "/Users", "/Library", "/bin", "/sbin", "/usr", "/etc",
    "/var", "/private", "/Applications", "/Volumes", "/cores", "/opt", "/tmp",
]

private final class CompletionLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var streamsClosed = 0
    private var exited = false
    private var resumed = false
    private(set) var status: Int32 = 0

    func signalStreamEOF() {
        lock.lock()
        streamsClosed += 1
        lock.unlock()
    }

    func signalExit(status: Int32) {
        lock.lock()
        exited = true
        self.status = status
        lock.unlock()
    }

    func markDoneIfReady(status _: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard exited, streamsClosed >= 2, !resumed else { return false }
        resumed = true
        return true
    }

    func forceDone(status: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        self.status = status
        return true
    }
}

private final class OutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""
    func append(_ s: String) { lock.lock(); storage += s; lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return storage }
}

final class AdminDeleter: @unchecked Sendable {
    private static let drainGrace: TimeInterval = 0.25

    private let lock = NSLock()
    private var process: Process?
    private var cancelledFlag = false

    func cancel() {
        lock.lock()
        cancelledFlag = true
        let p = process
        lock.unlock()
        p?.terminate()
    }

    private var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelledFlag
    }

    private func setProcess(_ p: Process?) {
        lock.lock(); process = p; lock.unlock()
    }

    private func resetCancelled() {
        lock.lock(); cancelledFlag = false; lock.unlock()
    }

    func run(
        paths: [String],
        log: @escaping @Sendable (String) -> Void,
        phase: @escaping @Sendable (String) -> Void
    ) async -> AdminDeleteResult {
        resetCancelled()

        let fm = FileManager.default
        let myUID = getuid()

        let plan = Self.plan(for: paths, myUID: myUID, fileManager: fm)
        let simulator = plan.simulator
        let rootPaths = plan.rootPaths
        let userPaths = plan.userPaths

        if !plan.rejected.isEmpty {
            log("⚠︎ \(plan.rejected.count) path(s) refused as protected system locations:")
            plan.rejected.forEach { log("⚠︎   \($0)") }
        }

        var attempted = rootPaths.count + userPaths.count
        guard attempted > 0 || simulator else {
            return AdminDeleteResult(
                attempted: 0, removed: 0, cancelled: false,
                needsFullDiskAccess: [], failed: [], rejected: plan.rejected)
        }

        var removed = 0
        var failed: [String] = []
        var needsFDA: [String] = []
        var cancelled = false

        if !userPaths.isEmpty && !isCancelled {
            phase("Removing \(userPaths.count) user items…")
            log("Removing \(userPaths.count) user-owned items (as you)")
            for p in userPaths {
                if isCancelled { cancelled = true; break }
                do {
                    try fm.removeItem(atPath: p)
                    removed += 1
                    log("✓ \(p)")
                } catch {
                    let ns = error as NSError
                    if ns.domain == NSCocoaErrorDomain,
                        (ns.underlyingErrors.first as NSError?)?.code == 1
                            || "\(error)".localizedCaseInsensitiveContains("permitted")
                    {
                        needsFDA.append(p)
                        log("⚠︎ \(p): needs Full Disk Access")
                    } else {
                        failed.append(p)
                        log("✗ \(p): \(ns.localizedDescription)")
                    }
                }
            }
        }

        if !rootPaths.isEmpty && !cancelled && !isCancelled {
            phase("Removing \(rootPaths.count) system items — authorize when prompted…")
            log("→ Requesting administrator access for \(rootPaths.count) root-owned items")
            let inner = "/bin/rm -rf " + rootPaths.map(Shell.quote).joined(separator: " ")
            let apple = "do shell script \(Shell.appleScriptLiteral(inner)) with administrator privileges"
            let (status, out, err) = await runProc(SystemPaths.osascript, ["-e", apple], stream: false, log: log)

            if isCancelled {
                cancelled = true
            } else if Shell.indicatesCancellation(out + err) {
                cancelled = true
                log("Administrator access cancelled.")
            } else {
                for line in (out + err).split(whereSeparator: { $0 == "\n" }) where !line.isEmpty {
                    log(String(line))
                }
                if status != 0 && out.isEmpty && err.isEmpty {
                    failed.append(contentsOf: rootPaths)
                    log("Administrator removal failed to start.")
                } else {
                    for p in rootPaths {
                        if fm.fileExists(atPath: p) {
                            failed.append(p)
                            log("✗ \(p)")
                        } else {
                            removed += 1
                            log("✓ \(p)")
                        }
                    }
                }
            }
        }

        if simulator && !cancelled && !isCancelled {
            phase("Listing simulator runtimes…")
            let (listStatus, listOut, listErr) = await runProc(
                SystemPaths.xcrun, ["simctl", "runtime", "list", "-j"], stream: false, log: nil)

            guard listStatus == 0 else {
                let detail = listErr.trimmingCharacters(in: .whitespacesAndNewlines)
                failed.append("Simulator runtimes could not be listed\(detail.isEmpty ? "" : ": \(detail)")")
                log("✗ Could not list simulator runtimes (xcrun exit \(listStatus))")
                return AdminDeleteResult(
                    attempted: attempted + 1, removed: removed, cancelled: cancelled,
                    needsFullDiskAccess: needsFDA, failed: failed, rejected: plan.rejected)
            }

            let runtimes = Self.parseRuntimes(listOut)
            attempted += runtimes.count
            log("Found \(runtimes.count) simulator runtimes")
            for rt in runtimes {
                if isCancelled { cancelled = true; break }
                phase("Deleting simulator runtime \(rt.label)…")
                log("Deleting \(rt.label) [\(rt.id)]…")
                let (status, _, _) = await runProc(
                    SystemPaths.xcrun, ["simctl", "runtime", "delete", rt.id], stream: true, log: log)
                if status == 0 {
                    removed += 1
                    log("✓ Removed \(rt.label)")
                } else if isCancelled {
                    cancelled = true
                    break
                } else {
                    failed.append("Simulator \(rt.label)")
                    log("✗ Failed to remove \(rt.label)")
                }
            }
        }

        return AdminDeleteResult(
            attempted: attempted, removed: removed, cancelled: cancelled,
            needsFullDiskAccess: needsFDA, failed: failed, rejected: plan.rejected)
    }

    func runProc(
        _ exe: String, _ args: [String], stream: Bool,
        log: (@Sendable (String) -> Void)?
    ) async -> (Int32, String, String) {
        await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            let outBox = OutputBox()
            let errBox = OutputBox()

            let completion = CompletionLatch()

            let finish: @Sendable (Int32) -> Void = { status in
                guard completion.markDoneIfReady(status: status) else { return }
                self.setProcess(nil)
                cont.resume(returning: (completion.status, outBox.text, errBox.text))
            }

            let makeHandler: @Sendable (OutputBox, @escaping @Sendable () -> Void) -> (@Sendable (FileHandle) -> Void) = { box, onEOF in
                { fh in
                    let d = fh.availableData
                    guard !d.isEmpty else {
                        fh.readabilityHandler = nil
                        onEOF()
                        return
                    }
                    guard let s = String(data: d, encoding: .utf8) else { return }
                    box.append(s)
                    if stream, let log {
                        for line in s.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) where !line.isEmpty {
                            log(String(line))
                        }
                    }
                }
            }

            outPipe.fileHandleForReading.readabilityHandler =
                makeHandler(outBox) { completion.signalStreamEOF(); finish(0) }
            errPipe.fileHandleForReading.readabilityHandler =
                makeHandler(errBox) { completion.signalStreamEOF(); finish(0) }

            p.terminationHandler = { proc in
                completion.signalExit(status: proc.terminationStatus)
                finish(proc.terminationStatus)
                DispatchQueue.global().asyncAfter(deadline: .now() + Self.drainGrace) {
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    guard completion.forceDone(status: proc.terminationStatus) else { return }
                    self.setProcess(nil)
                    cont.resume(returning: (proc.terminationStatus, outBox.text, errBox.text))
                }
            }

            func abandon(_ status: Int32) {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                p.terminationHandler = nil
                guard completion.forceDone(status: status) else { return }
                cont.resume(returning: (status, "", ""))
            }

            guard !isCancelled else {
                abandon(ProcExit.cancelledBeforeStart)
                return
            }
            do {
                try p.run()
            } catch {
                setProcess(nil)
                abandon(ProcExit.failedToLaunch)
                return
            }
            setProcess(p)
            if isCancelled { p.terminate() }
        }
    }

    private static func parseRuntimes(_ json: String) -> [(id: String, label: String)] {
        guard let data = json.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var out: [(String, String)] = []
        for (id, value) in obj {
            guard let v = value as? [String: Any] else { continue }
            let version = v["version"] as? String ?? ""
            let ident = v["runtimeIdentifier"] as? String ?? ""
            let os = ident.components(separatedBy: "SimRuntime.").last?.components(separatedBy: "-").first ?? "Runtime"
            out.append((id, "\(os) \(version)".trimmingCharacters(in: .whitespaces)))
        }
        return out.sorted { $0.1 < $1.1 }
    }

    struct DeletionPlan: Equatable {
        var simulator = false
        var rootPaths: [String] = []
        var userPaths: [String] = []
        var rejected: [String] = []
    }

    private static let volumeContainers = ["/Volumes", "/System/Volumes"]

    static func isProtected(_ path: String) -> Bool {
        guard path.hasPrefix("/") else { return true }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let std = url.path

        if std.count <= 1 || adminProtectedRoots.contains(std) { return true }

        for container in volumeContainers where std.hasPrefix(container + "/") {
            let remainder = std.dropFirst(container.count + 1)
            if !remainder.contains("/") { return true }
        }

        if let values = try? url.resourceValues(forKeys: [.volumeURLKey]),
           let volume = values.volume?.standardizedFileURL,
           volume.path == std {
            return true
        }

        return false
    }

    static func plan(for paths: [String], myUID: uid_t, fileManager fm: FileManager) -> DeletionPlan {
        var plan = DeletionPlan()
        for p in paths {
            guard !isProtected(p) else {
                plan.rejected.append(p)
                continue
            }
            let std = URL(fileURLWithPath: p).standardizedFileURL.path
            if std.hasPrefix(SystemPaths.coreSimulator) {
                plan.simulator = true
                continue
            }
            let owner = (try? fm.attributesOfItem(atPath: std))?[.ownerAccountID] as? NSNumber
            if let owner, owner.uint32Value == myUID {
                plan.userPaths.append(std)
            } else {
                plan.rootPaths.append(std)
            }
        }
        return plan
    }


}
