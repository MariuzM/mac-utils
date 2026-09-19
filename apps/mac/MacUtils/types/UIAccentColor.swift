import AppKit

enum UIAccentColor: String, CaseIterable, Identifiable {
    case automatic
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case graphite

    var id: String { rawValue }

    var name: String {
        switch self {
        case .automatic: "Automatic"
        case .blue: "Blue"
        case .purple: "Purple"
        case .pink: "Pink"
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .graphite: "Graphite"
        }
    }

    var nsColor: NSColor? {
        switch self {
        case .automatic: nil
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .pink: .systemPink
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .graphite: .systemGray
        }
    }

    static let swatchColors: [UIAccentColor] = allCases.filter { $0 != .automatic }
}
