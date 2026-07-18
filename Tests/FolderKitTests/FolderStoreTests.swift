import XCTest
@testable import FolderKit

final class PinnedFolderTests: XCTestCase {
    func testDecodesRealWorldFoldersFile() throws {
        let json = #"[{"path":"\/Users\/marius\/Downloads"},{"path":"\/Users\/marius\/Documents"}]"#
        let decoded = try JSONDecoder().decode([PinnedFolder].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.map(\.path), ["/Users/marius/Downloads", "/Users/marius/Documents"])
        XCTAssertEqual(decoded.first?.name, "Downloads")
    }

    func testRoundTrip() throws {
        let original = [PinnedFolder(path: "/tmp/a"), PinnedFolder(path: "/tmp/b")]
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode([PinnedFolder].self, from: data), original)
    }
}

@MainActor
final class FolderStoreListingTests: XCTestCase {
    private var scratch: URL!

    override func setUp() async throws {
        scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("folderstore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testListingReportsEntriesSortedDirectoriesFirst() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: scratch.appendingPathComponent("zdir"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: scratch.appendingPathComponent("afile.txt"))

        guard case .entries(let entries) = FolderStore().listing(of: scratch) else {
            return XCTFail("expected entries")
        }
        XCTAssertEqual(entries.map(\.name), ["zdir", "afile.txt"])
        XCTAssertTrue(entries[0].isDirectory)
        XCTAssertFalse(entries[1].isDirectory)
    }

    func testEmptyDirectoryIsEntriesNotUnreadable() {
        guard case .entries(let entries) = FolderStore().listing(of: scratch) else {
            return XCTFail("an empty directory must not report as unreadable")
        }
        XCTAssertTrue(entries.isEmpty)
    }

    func testMissingDirectoryIsReportedUnreadableRatherThanEmpty() {
        let missing = scratch.appendingPathComponent("does-not-exist")
        guard case .unreadable = FolderStore().listing(of: missing) else {
            return XCTFail("a missing directory must be distinguishable from an empty one")
        }
    }

    func testUnreadableDirectoryIsReportedUnreadableRatherThanEmpty() throws {
        let locked = scratch.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: locked.appendingPathComponent("secret.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        guard case .unreadable = FolderStore().listing(of: locked) else {
            return XCTFail("a permission-denied directory must not report as empty")
        }
    }
}
