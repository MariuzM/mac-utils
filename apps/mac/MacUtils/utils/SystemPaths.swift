import Foundation

enum SystemPaths {
    static let osascript = "/usr/bin/osascript"
    static let xcrun = "/usr/bin/xcrun"
    static let hidutil = "/usr/bin/hidutil"
    static let launchctl = "/bin/launchctl"
    static let defaults = "/usr/bin/defaults"
    static let coreSimulator = "/Library/Developer/CoreSimulator"
}

enum ProcExit {
    static let cancelledBeforeStart: Int32 = -999
    static let failedToLaunch: Int32 = -998
    static let timedOut: Int32 = -997
    static let outputLimit: Int32 = -996
}
