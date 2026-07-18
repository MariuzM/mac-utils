import AppKit

public enum ExternalApp: String, CaseIterable, Identifiable {
    case terminal = "com.apple.Terminal"
    case ghostty = "com.mitchellh.ghostty"
    case vscode = "com.microsoft.VSCode"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .terminal: return "Terminal"
        case .ghostty: return "Ghostty"
        case .vscode: return "Visual Studio Code"
        }
    }

    public var wantsDirectory: Bool {
        switch self {
        case .terminal, .ghostty: return true
        case .vscode: return false
        }
    }

    public var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue)
    }

    public var isInstalled: Bool { applicationURL != nil }

    public func open(_ entry: FolderEntry) {
        guard let app = applicationURL else { return }
        let target = wantsDirectory && !entry.isDirectory
            ? entry.url.deletingLastPathComponent()
            : entry.url
        NSWorkspace.shared.open([target], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
