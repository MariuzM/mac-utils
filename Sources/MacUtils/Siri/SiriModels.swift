import Foundation

struct SiriService: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let executable: String

    var plistPath: String { "/System/Library/LaunchAgents/\(id).plist" }

    static let catalog: [Self] = [
        .init(
            id: "com.apple.campo", name: "Siri AI",
            executable: "/System/Applications/Siri AI.app/Contents/MacOS/Siri AI"),
        .init(
            id: "com.apple.Siri.agent", name: "Siri",
            executable: "/System/Library/CoreServices/Siri.app/Contents/MacOS/Siri"),
        .init(
            id: "com.apple.assistantd", name: "Siri assistant",
            executable: "/System/Library/PrivateFrameworks/AssistantServices.framework/Versions/A/Support/assistantd"),
        .init(
            id: "com.apple.siriinferenced", name: "Siri inference",
            executable: "/System/Library/PrivateFrameworks/SiriInference.framework/Versions/A/siriinferenced"),
        .init(id: "com.apple.siriknowledged", name: "Siri suggestions", executable: "/usr/libexec/siriknowledged"),
    ]
}

struct SiriPreference: Identifiable, Equatable, Sendable {
    let domain: String
    let key: String
    var id: String { domain + "/" + key }

    static let catalog: [Self] = [
        .init(domain: "com.apple.assistant.support", key: "Assistant Enabled"),
        .init(domain: "com.apple.assistant.backedup", key: "Cloud Sync Enabled"),
    ]
}

struct SiriServiceState: Identifiable, Sendable {
    let service: SiriService
    let disabled: Bool
    let running: Bool
    let loaded: Bool
    var id: String { service.id }
}

struct SiriSnapshot: Sendable {
    let checkedAt: Date
    let settingsOff: Bool
    let services: [SiriServiceState]

    var fullyDisabled: Bool {
        settingsOff && !services.isEmpty && services.allSatisfy { $0.disabled && !$0.running }
    }

    var restartNeeded: Bool {
        settingsOff && !services.isEmpty && services.allSatisfy(\.disabled) && services.contains(where: \.running)
    }

    var summary: String {
        if fullyDisabled { return "Disabled" }
        if restartNeeded { return "Sign out needed" }
        return settingsOff ? "Partly disabled" : "Enabled"
    }
}

struct SiriBackup: Codable, Sendable {
    struct Preference: Codable, Sendable {
        let id: String
        let value: Data?
    }

    struct Service: Codable, Sendable {
        let id: String
        let disabled: Bool
        let running: Bool
    }

    let version: Int
    let userID: UInt32
    let createdAt: Date
    let preferences: [Preference]
    let services: [Service]
}

struct SiriOperation: Sendable {
    let snapshot: SiriSnapshot
    let details: [String]
}

enum SiriError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}
