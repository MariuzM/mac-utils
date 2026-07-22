import Foundation

public enum SharedConfig {
    public static let suiteName = "dev.marius.macutils.shared"
    public static let helperBundleID = "dev.marius.macutils.folderhelper"
    public static var helperLabel: String { helperBundleID }
    public static let configChanged = Notification.Name("dev.marius.macutils.configChanged")
    public static let helperTrustedKey = "helperTrusted"

    private static let legacySuiteName = "dev.marius.macosutility.shared"
    private static let legacySuiteMigratedKey = "legacySuiteMigrated"

    public static var defaults: UserDefaults {
        _ = migrateLegacySuite
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static let migrateLegacySuite: Void = {
        guard let target = UserDefaults(suiteName: suiteName),
            target.object(forKey: legacySuiteMigratedKey) == nil
        else { return }
        if let legacy = UserDefaults.standard.persistentDomain(forName: legacySuiteName) {
            for (key, value) in legacy {
                target.set(value, forKey: key)
            }
        }
        target.set(true, forKey: legacySuiteMigratedKey)
    }()

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
