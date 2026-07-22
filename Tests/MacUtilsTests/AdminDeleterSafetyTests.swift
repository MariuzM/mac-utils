import XCTest
@testable import MacUtils

final class AdminDeleterSafetyTests: XCTestCase {
    func testRejectsProtectedRoots() {
        for root in ["/", "/System", "/Users", "/Library", "/bin", "/sbin", "/usr",
                     "/etc", "/var", "/private", "/Applications", "/Volumes", "/opt", "/tmp"] {
            XCTAssertTrue(AdminDeleter.isProtected(root), "\(root) must be rejected")
        }
    }

    func testRejectsProtectedRootsWrittenNonCanonically() {
        for variant in ["/System/", "/System/.", "/usr/..", "/Users/../Users", "//System", "/./System"] {
            XCTAssertTrue(AdminDeleter.isProtected(variant),
                          "\(variant) normalizes to a protected root and must be rejected")
        }
    }

    func testRejectsCanonicalFormsBehindPrivateSymlinks() {
        for variant in ["/private/tmp", "/private/var", "/private/etc"] {
            XCTAssertTrue(AdminDeleter.isProtected(variant),
                          "\(variant) is the real target of a protected symlink and must be rejected")
        }
    }

    func testRejectsVolumeRoots() {
        for root in ["/System/Volumes/Data", "/System/Volumes/Preboot", "/Volumes/Media"] {
            XCTAssertTrue(AdminDeleter.isProtected(root), "\(root) must be rejected")
        }
    }

    func testAllowsOrdinaryPathsUnderProtectedRoots() {
        for path in ["/Users/marius/Library/Caches/foo", "/Library/Caches/bar", "/tmp/scratch"] {
            XCTAssertFalse(AdminDeleter.isProtected(path), "\(path) should be deletable")
        }
    }

    func testRejectsRelativeAndEmptyPaths() {
        XCTAssertTrue(AdminDeleter.isProtected(""))
        XCTAssertTrue(AdminDeleter.isProtected("relative/path"))
    }

    func testPlanRoutesProtectedPathsToRejectedNotDeletion() {
        let plan = AdminDeleter.plan(for: ["/System", "/tmp/definitely-not-here-xyz"],
                                     myUID: getuid(), fileManager: .default)
        XCTAssertEqual(plan.rejected, ["/System"])
        XCTAssertFalse(plan.rootPaths.contains("/System"))
        XCTAssertFalse(plan.userPaths.contains("/System"))
    }

    func testPlanDetectsSimulatorPathsWithoutQueueingThemForRemoval() {
        let simPath = "/Library/Developer/CoreSimulator/Volumes/iOS_21A123"
        let plan = AdminDeleter.plan(for: [simPath], myUID: getuid(), fileManager: .default)
        XCTAssertTrue(plan.simulator)
        XCTAssertTrue(plan.rootPaths.isEmpty)
        XCTAssertTrue(plan.userPaths.isEmpty)
    }

    func testPlanSplitsByOwnership() throws {
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("admindeleter-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let plan = AdminDeleter.plan(for: [scratch.path], myUID: getuid(), fileManager: .default)
        XCTAssertEqual(plan.userPaths, [scratch.standardizedFileURL.path])
        XCTAssertTrue(plan.rootPaths.isEmpty)
    }

    func testCancellationDetectionMatchesOsascriptStderr() {
        XCTAssertTrue(Shell.indicatesCancellation("execution error: User canceled. (-128)"))
        XCTAssertTrue(Shell.indicatesCancellation("User cancelled"))
        XCTAssertFalse(Shell.indicatesCancellation("rm: /x: Permission denied"))
        XCTAssertFalse(Shell.indicatesCancellation(""))
    }
}
