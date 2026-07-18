import Foundation

public enum SharedConfig {
    public static let suiteName = "dev.marius.macosutility.shared"
    public static let helperBundleID = "dev.marius.macosutility.folderhelper"
    public static let helperLabel = "dev.marius.macosutility.folderhelper"
    public static let configChanged = Notification.Name("dev.marius.macosutility.configChanged")
    public static let helperTrustedKey = "helperTrusted"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public static func postConfigChanged() {
        defaults.synchronize()
        DistributedNotificationCenter.default().postNotificationName(
            configChanged,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func observeConfigChanged(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: configChanged,
            object: nil,
            queue: .main
        ) { _ in handler() }
    }
}
