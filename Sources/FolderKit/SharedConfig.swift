import Foundation

public enum SharedConfig {
    public static let suiteName = "dev.marius.macosutility.shared"
    public static let helperBundleID = "dev.marius.macosutility.folderhelper"
    public static var helperLabel: String { helperBundleID }
    public static let configChanged = Notification.Name("dev.marius.macosutility.configChanged")
    public static let helperTrustedKey = "helperTrusted"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static let processToken = UUID().uuidString

    public static func postConfigChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            configChanged,
            object: processToken,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func observeConfigChanged(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: configChanged,
            object: nil,
            queue: .main
        ) { notification in
            guard notification.object as? String != processToken else { return }
            handler()
        }
    }
}
