import AppKit
import Darwin
import Foundation

enum ProcessRole: String, Sendable, Hashable {
    case app
    case menuBar
    case background
    case unbundled

    var label: String {
        switch self {
        case .app: return "App"
        case .menuBar: return "Menu bar"
        case .background: return "Background"
        case .unbundled: return "Process"
        }
    }
}

struct ProcessSample: Identifiable, Hashable, Sendable {
    let pid: pid_t
    let ppid: pid_t
    let uid: uid_t
    let name: String
    let executablePath: String
    let bundleID: String?
    let bundleURL: URL?
    let role: ProcessRole
    let startDate: Date?
    let cpuNanos: UInt64
    let residentBytes: UInt64
    var cpuPercent: Double
    let metricsReadable: Bool
    let isProtected: Bool

    var id: pid_t { pid }

    var vendor: String? {
        guard let bundleID else { return nil }
        let parts = bundleID.split(separator: ".")
        guard parts.count >= 2 else { return bundleID }
        return parts.prefix(2).joined(separator: ".")
    }
}

struct ProcessSuggestion: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable, Hashable {
        case duplicateInstances
        case idleVendorStack
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let note: String
    let pids: [pid_t]
    let reclaimBytes: UInt64
}

enum ProcessCatalog {
    static let idleStackMinimumBytes: UInt64 = 100 * 1024 * 1024

    private static let pathMax = 4 * Int(MAXPATHLEN)

    private static let protectedNames: Set<String> = [
        "launchd", "kernel_task", "WindowServer", "loginwindow", "logd",
        "runningboardd", "opendirectoryd", "fseventsd", "Dock", "Finder",
        "SystemUIServer", "ControlCenter", "ControlCenterHelper", "NotificationCenter",
        "coreaudiod", "distnoted", "cfprefsd", "securityd", "trustd",
        "mds", "mds_stores", "mdworker", "mdworker_shared", "powerd", "configd",
        "diskarbitrationd", "notifyd", "UserEventAgent", "hidd", "WindowManager",
        "Spotlight", "systemstats", "amfid", "syspolicyd", "installd", "launchd_sim",
    ]

    private static let protectedPrefixes = [
        "/System/", "/usr/libexec/", "/usr/sbin/", "/usr/bin/", "/sbin/", "/bin/",
        "/Library/Developer/CoreSimulator/", "/Library/Developer/PrivateFrameworks/",
    ]

    static func isProtectedPath(_ path: String) -> Bool {
        protectedPrefixes.contains { path.hasPrefix($0) } || path.contains("/RuntimeRoot/")
    }

    static func snapshot() -> [ProcessSample] {
        let apps = runningAppsByPID()
        let me = getuid()
        let selfPID = getpid()

        return kernelProcesses().compactMap { proc in
            let pid = proc.kp_proc.p_pid
            guard pid > 0 else { return nil }

            let path = executablePath(pid)
            let app = apps[pid]
            let name =
                app?.localizedName
                ?? path.map { URL(fileURLWithPath: $0).lastPathComponent }.flatMap(meaningfulName)
                ?? argvName(pid)
                ?? commName(proc)
            let uid = proc.kp_eproc.e_ucred.cr_uid
            let usage = resourceUsage(pid)

            let role: ProcessRole
            switch app?.activationPolicy {
            case .regular: role = .app
            case .accessory: role = .menuBar
            case .prohibited: role = .background
            default: role = .unbundled
            }

            let resolvedPath = path ?? ""
            let isProtected =
                uid != me
                || pid <= 1
                || pid == selfPID
                || resolvedPath.isEmpty
                || protectedNames.contains(name)
                || isProtectedPath(resolvedPath)

            return ProcessSample(
                pid: pid,
                ppid: proc.kp_eproc.e_ppid,
                uid: uid,
                name: name,
                executablePath: resolvedPath,
                bundleID: app?.bundleIdentifier,
                bundleURL: app?.bundleURL ?? bundleURL(forExecutable: resolvedPath),
                role: role,
                startDate: startDate(proc),
                cpuNanos: usage?.cpuNanos ?? 0,
                residentBytes: usage?.residentBytes ?? 0,
                cpuPercent: 0,
                metricsReadable: usage != nil,
                isProtected: isProtected
            )
        }
    }

    static func applyCPU(
        to samples: [ProcessSample],
        previous: [pid_t: UInt64],
        elapsed: TimeInterval
    ) -> [ProcessSample] {
        guard elapsed > 0 else { return samples }
        let window = elapsed * 1_000_000_000
        return samples.map { sample in
            guard let before = previous[sample.pid], sample.cpuNanos >= before else { return sample }
            var updated = sample
            updated.cpuPercent = Double(sample.cpuNanos - before) / window * 100
            return updated
        }
    }

    static func suggestions(for samples: [ProcessSample]) -> [ProcessSuggestion] {
        (duplicateInstances(in: samples) + idleVendorStacks(in: samples))
            .sorted { $0.reclaimBytes > $1.reclaimBytes }
    }

    static func isSuggestable(_ sample: ProcessSample) -> Bool {
        guard !sample.isProtected, sample.bundleID != nil else { return false }
        return sample.vendor != "com.apple"
    }

    static func duplicateInstances(in samples: [ProcessSample]) -> [ProcessSuggestion] {
        let candidates = samples.filter { $0.ppid == 1 && isSuggestable($0) }
        let groups = Dictionary(grouping: candidates) { sample in
            "\(sample.bundleID ?? "")|\(sample.executablePath)"
        }

        return groups.compactMap { key, group -> ProcessSuggestion? in
            guard group.count > 1 else { return nil }
            let ordered = group.sorted {
                ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
            }
            let extras = Array(ordered.dropFirst())
            let reclaim = extras.reduce(UInt64(0)) { $0 + $1.residentBytes }
            let first = ordered[0]
            return ProcessSuggestion(
                id: "duplicate:\(key)",
                kind: .duplicateInstances,
                title: first.name,
                detail: "\(group.count) instances of the same executable",
                note:
                    "These instances may serve different sessions. Review them before quitting; the oldest instance is kept.",
                pids: extras.map(\.pid),
                reclaimBytes: reclaim
            )
        }
    }

    static func idleVendorStacks(in samples: [ProcessSample]) -> [ProcessSuggestion] {
        let groups = Dictionary(grouping: samples.filter(isSuggestable)) { $0.vendor ?? "" }

        return groups.compactMap { vendor, group -> ProcessSuggestion? in
            guard !vendor.isEmpty, group.count >= 2 else { return nil }
            guard !group.contains(where: { $0.role == .app }) else { return nil }
            let reclaim = group.reduce(UInt64(0)) { $0 + $1.residentBytes }
            guard reclaim >= idleStackMinimumBytes else { return nil }

            return ProcessSuggestion(
                id: "idle:\(vendor)",
                kind: .idleVendorStack,
                title: vendorLabel(vendor),
                detail: "\(group.count) background processes, no regular app running",
                note:
                    "No regular app from this vendor appears in the process list. These may still provide sync, menu bar, or other services; quitting can interrupt them.",
                pids: group.map(\.pid),
                reclaimBytes: reclaim
            )
        }
    }

    static func vendorLabel(_ vendor: String) -> String {
        guard let last = vendor.split(separator: ".").last, !last.isEmpty else { return vendor }
        return last.prefix(1).uppercased() + last.dropFirst()
    }

    private static func kernelProcesses() -> [kinfo_proc] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        let capacity = size / MemoryLayout<kinfo_proc>.stride + 32
        var buffer = [kinfo_proc](repeating: kinfo_proc(), count: capacity)
        var actual = capacity * MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, 4, &buffer, &actual, nil, 0) == 0 else { return [] }

        return Array(buffer.prefix(actual / MemoryLayout<kinfo_proc>.stride))
    }

    private static func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: pathMax)
        let written = proc_pidpath(pid, &buffer, UInt32(pathMax))
        guard written > 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func resourceUsage(_ pid: pid_t) -> (cpuNanos: UInt64, residentBytes: UInt64)? {
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard status == 0 else { return nil }
        return (info.ri_user_time + info.ri_system_time, info.ri_resident_size)
    }

    static func argvZero(in buffer: [UInt8]) -> String? {
        guard buffer.count > 4 else { return nil }
        let argc = buffer.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard argc > 0 else { return nil }

        var index = 4
        while index < buffer.count && buffer[index] != 0 { index += 1 }
        while index < buffer.count && buffer[index] == 0 { index += 1 }

        let start = index
        while index < buffer.count && buffer[index] != 0 { index += 1 }
        guard index > start else { return nil }

        let argument = String(decoding: buffer[start..<index], as: UTF8.self)
        return meaningfulName(URL(fileURLWithPath: argument).lastPathComponent)
    }

    private static func argvName(_ pid: pid_t) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        return argvZero(in: Array(buffer.prefix(size)))
    }

    static func meaningfulName(_ component: String) -> String? {
        guard !component.isEmpty else { return nil }
        let versionLike = component.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" }
        return versionLike ? nil : component
    }

    private static func commName(_ proc: kinfo_proc) -> String {
        var comm = proc.kp_proc.p_comm
        let capacity = MemoryLayout.size(ofValue: comm)
        return withUnsafePointer(to: &comm) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { String(cString: $0) }
        }
    }

    private static func startDate(_ proc: kinfo_proc) -> Date? {
        let started = proc.kp_proc.p_un.__p_starttime
        guard started.tv_sec > 0 else { return nil }
        return Date(
            timeIntervalSince1970: TimeInterval(started.tv_sec)
                + TimeInterval(started.tv_usec) / 1_000_000)
    }

    private static func bundleURL(forExecutable path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        var current = URL(fileURLWithPath: path)
        while current.pathComponents.count > 2 {
            if current.pathExtension == "app" { return current }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    private static func runningAppsByPID() -> [pid_t: NSRunningApplication] {
        Dictionary(
            NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
