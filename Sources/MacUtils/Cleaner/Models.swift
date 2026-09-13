import Foundation

enum SafetyLevel: String, Codable, Sendable {
    case safe
    case caution
    case review

    var label: String {
        switch self {
        case .safe: return "Safe to remove"
        case .caution: return "Usually safe"
        case .review: return "Review first"
        }
    }
}

struct ScanItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    var isComplete = true
}

struct CategoryResult: Identifiable, Hashable, Sendable {
    let id = UUID()
    let ruleID: String
    let title: String
    let subtitle: String
    let safety: SafetyLevel
    var items: [ScanItem]
    var totalSize: Int64

    var isSystem: Bool {
        guard let first = items.first else { return false }
        return !DeletionPolicy.contains(FileManager.default.homeDirectoryForCurrentUser.path, first.url.path)
    }
}

struct VolumeResult: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    let isBoot: Bool
    var categories: [CategoryResult]

    var totalSize: Int64 {
        categories.reduce(0) { $0 + $1.totalSize }
    }

    var itemCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }
}
