import Foundation

enum SafetyLevel: String, Codable {
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
}

struct CategoryResult: Identifiable, Hashable {
    let id = UUID()
    let ruleID: String
    let title: String
    let subtitle: String
    let safety: SafetyLevel
    var items: [ScanItem]
    var totalSize: Int64

    var isSystem: Bool {
        guard let first = items.first else { return false }
        return !first.url.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path)
    }
}

struct VolumeResult: Identifiable, Hashable {
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

enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}
