import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case overview, cleaner, leftovers, performance, launchItems, siri, spotlight, rekey, folders, extensions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .cleaner: "Storage Cleaner"
        case .leftovers: "App Leftovers"
        case .performance: "Performance"
        case .launchItems: "Launch Items"
        case .siri: "Siri Controls"
        case .spotlight: "Spotlight Privacy"
        case .rekey: "Keyboard"
        case .folders: "Dock & Folders"
        case .extensions: "Default Apps"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .cleaner: "internaldrive"
        case .leftovers: "trash.slash"
        case .performance: "waveform.path.ecg"
        case .launchItems: "power"
        case .siri: "mic.slash"
        case .spotlight: "magnifyingglass"
        case .rekey: "keyboard"
        case .folders: "folder"
        case .extensions: "app.badge"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "Storage, processes, and system settings."
        case .cleaner: "Find removable files. Review before you clean."
        case .leftovers: "Review files left by uninstalled apps."
        case .performance: "Understand what is running in the background."
        case .launchItems: "Stop background jobs from starting."
        case .siri: "Disable Siri or restore previous settings."
        case .spotlight: "Choose what stays out of search."
        case .rekey: "Remap keys and configure startup mappings."
        case .folders: "Manage Dock and menu bar folders."
        case .extensions: "Choose which apps open your files."
        }
    }

    static let maintenance: [Self] = [.cleaner, .leftovers, .performance, .launchItems]
    static let controls: [Self] = [.siri, .spotlight, .rekey, .folders, .extensions]
}
