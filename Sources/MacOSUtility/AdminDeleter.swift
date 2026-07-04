import Foundation

struct AdminDeleteResult: Sendable {
    let attempted: Int
    let removed: Int
    let cancelled: Bool
    let needsFullDiskAccess: [String]
    let failed: [String]

    var ok: Bool { failed.isEmpty && needsFullDiskAccess.isEmpty && !cancelled }
}

private let adminProtectedRoots: Set<String> = [
    "/", "/System", "/Users", "/Library", "/bin", "/sbin", "/usr", "/etc",
    "/var", "/private", "/Applications", "/Volumes", "/cores", "/opt", "/tmp"
]

private final class OutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""
    func append(_ s: String) { lock.lock(); storage += s; lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return storage }
}

final class AdminDeleter: @unchecked Sendable {
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

    func run(paths: [String],
             log: @escaping @Sendable (String) -> Void,
             phase: @escaping @Sendable (String) -> Void) async -> AdminDeleteResult {
        resetCancelled()

        let fm = FileManager.default
        let myUID = getuid()

        var simulator = false
        var rootPaths: [String] = []
        var userPaths: [String] = []

        for p in paths {
            guard p.hasPrefix("/"), p.count > 1, !adminProtectedRoots.contains(p) else { continue }
            if p.hasPrefix("/Library/Developer/CoreSimulator") { simulator = true; continue }
            let owner = (try? fm.attributesOfItem(atPath: p))?[.ownerAccountID] as? NSNumber
            if let owner, owner.uint32Value == myUID {
                userPaths.append(p)
            } else {
                rootPaths.append(p)
            }
        }

        let attempted = rootPaths.count + userPaths.count + (simulator ? 1 : 0)
        guard attempted > 0 else {
            return AdminDeleteResult(attempted: 0, removed: 0, cancelled: false,
                                     needsFullDiskAccess: [], failed: [])
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
                    if ns.domain == NSCocoaErrorDomain, (ns.underlyingErrors.first as NSError?)?.code == 1
                        || "\(error)".localizedCaseInsensitiveContains("permitted") {
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
            let inner = rootPaths
                .map { "echo 'rm: \(Self.echoSafe($0))'; /bin/rm -rf \(Self.shellQuote($0)) 2>&1 || echo 'FAILED: \(Self.echoSafe($0))'" }
                .joined(separator: "; ")
            let apple = "do shell script \"\(Self.appleEscape(inner))\" with administrator privileges"
            let (status, out) = await runProc("/usr/bin/osascript", ["-e", apple], stream: false, log: log)

            if isCancelled {
                cancelled = true
            } else if out.contains("-128") || out.localizedCaseInsensitiveContains("User canceled") {
                cancelled = true
                log("Administrator access cancelled.")
            } else {
                for line in out.split(whereSeparator: { $0 == "\n" }) {
                    log(String(line))
                }
                var failedRoots = 0
                for line in out.split(whereSeparator: { $0 == "\n" }) where line.hasPrefix("FAILED:") {
                    failedRoots += 1
                    failed.append(String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces))
                }
                if status != 0 && out.isEmpty {
                    failed.append(contentsOf: rootPaths)
                    log("Administrator removal failed to start.")
                } else {
                    removed += rootPaths.count - failedRoots
                }
            }
        }

        if simulator && !cancelled && !isCancelled {
            phase("Listing simulator runtimes…")
            let (_, listOut) = await runProc("/usr/bin/xcrun", ["simctl", "runtime", "list", "-j"], stream: false, log: nil)
            let runtimes = Self.parseRuntimes(listOut)
            log("Found \(runtimes.count) simulator runtimes")
            for rt in runtimes {
                if isCancelled { cancelled = true; break }
                phase("Deleting simulator runtime \(rt.label)…")
                log("Deleting \(rt.label) [\(rt.id)]…")
                let (status, _) = await runProc("/usr/bin/xcrun", ["simctl", "runtime", "delete", rt.id], stream: true, log: log)
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

        return AdminDeleteResult(attempted: attempted, removed: removed, cancelled: cancelled,
                                 needsFullDiskAccess: needsFDA, failed: failed)
    }

    private func runProc(_ exe: String, _ args: [String], stream: Bool,
                         log: (@Sendable (String) -> Void)?) async -> (Int32, String) {
        await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            let outBox = OutputBox()

            let makeHandler: (Bool) -> (@Sendable (FileHandle) -> Void) = { isOut in
                { fh in
                    let d = fh.availableData
                    guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return }
                    if isOut { outBox.append(s) }
                    if stream, let log {
                        for line in s.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) where !line.isEmpty {
                            log(String(line))
                        }
                    }
                }
            }
            outPipe.fileHandleForReading.readabilityHandler = makeHandler(true)
            errPipe.fileHandleForReading.readabilityHandler = makeHandler(false)

            p.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if let tail = try? outPipe.fileHandleForReading.readToEnd(), let s = String(data: tail, encoding: .utf8) {
                    outBox.append(s)
                }
                self.setProcess(nil)
                cont.resume(returning: (proc.terminationStatus, outBox.text))
            }

            if isCancelled {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                cont.resume(returning: (-999, ""))
                return
            }
            setProcess(p)
            do {
                try p.run()
            } catch {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                setProcess(nil)
                cont.resume(returning: (-998, ""))
            }
        }
    }

    private static func parseRuntimes(_ json: String) -> [(id: String, label: String)] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
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

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func echoSafe(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "")
    }

    private static func appleEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
