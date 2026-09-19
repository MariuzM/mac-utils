import Foundation

enum LaunchScope: String, CaseIterable, Identifiable, Sendable {
    case userAgents = "Your Launch Agents"
    case globalAgents = "Launch Agents for All Users"
    case daemons = "Launch Daemons"

    var id: String { rawValue }

    var directory: String {
        switch self {
        case .userAgents: NSHomeDirectory() + "/Library/LaunchAgents"
        case .globalAgents: "/Library/LaunchAgents"
        case .daemons: "/Library/LaunchDaemons"
        }
    }

    var icon: String {
        switch self {
        case .userAgents: "person"
        case .globalAgents: "person.2"
        case .daemons: "gearshape.2"
        }
    }

    var domain: String {
        self == .daemons ? "system" : "gui/\(getuid())"
    }

    var needsAdmin: Bool { self == .daemons }
}

enum LaunchItemState: Sendable {
    case running(pid: Int?)
    case loaded
    case notLoaded

    var label: String {
        switch self {
        case .running(let pid): pid.map { "Running · PID \($0)" } ?? "Running"
        case .loaded: "Loaded"
        case .notLoaded: "Not loaded"
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

struct LaunchItem: Identifiable, Sendable {
    let label: String
    let plistPath: String
    let program: String?
    let runsAtLoad: Bool
    let keepsAlive: Bool
    let scope: LaunchScope
    var isDisabled: Bool
    var state: LaunchItemState

    var id: String { plistPath }
    var target: String { "\(scope.domain)/\(label)" }
}

enum ExtensionElection: Sendable {
    case enabled, disabled, systemDefault
}

struct FinderExtension: Identifiable, Sendable {
    let bundleID: String
    let version: String
    let path: String
    var election: ExtensionElection

    var id: String { bundleID }
    var isDisabled: Bool { election == .disabled }

    var parentAppName: String {
        let parts = path.components(separatedBy: "/")
        guard let app = parts.last(where: { $0.hasSuffix(".app") }) else { return bundleID }
        return String(app.dropLast(4))
    }
}
