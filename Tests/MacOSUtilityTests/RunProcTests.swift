import XCTest
@testable import MacOSUtility

final class RunProcTests: XCTestCase {
    private func runProc(_ args: [String], stream: Bool = false) async -> (Int32, String, String) {
        await AdminDeleter().runProc("/bin/sh", ["-c"] + args, stream: stream, log: nil)
    }

    func testCapturesStdoutAndStderrSeparately() async {
        let (status, out, err) = await runProc(["printf out; printf err >&2; exit 0"])
        XCTAssertEqual(status, 0)
        XCTAssertEqual(out, "out")
        XCTAssertEqual(err, "err")
    }

    func testReportsNonZeroExitStatus() async {
        let (status, _, _) = await runProc(["exit 7"])
        XCTAssertEqual(status, 7)
    }

    func testDoesNotHangOnLargeOutputOnBothStreams() async {
        let (status, out, err) = await runProc(
            ["yes OUT | head -c 300000 & yes ERR | head -c 300000 >&2; wait"])
        XCTAssertEqual(status, 0)
        XCTAssertEqual(out.count, 300_000)
        XCTAssertEqual(err.count, 300_000)
    }

    func testCapturesFinalBytesWrittenImmediatelyBeforeExit() async {
        for _ in 0..<20 {
            let (_, out, _) = await runProc(["printf FINAL"])
            XCTAssertEqual(out, "FINAL", "tail bytes were lost on exit")
        }
    }

    func testReturnsPromptlyWhenADescendantHoldsThePipeOpen() async {
        let start = Date()
        let (status, out, _) = await runProc(["(sleep 30 &) ; printf done; exit 0"])
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(status, 0)
        XCTAssertEqual(out, "done")
        XCTAssertLessThan(elapsed, 5, "runProc waited on a descendant instead of the child's exit")
    }

    func testFailedLaunchIsReportedNotHung() async {
        let (status, _, _) = await AdminDeleter()
            .runProc("/nonexistent/binary/xyz", [], stream: false, log: nil)
        XCTAssertEqual(status, ProcExit.failedToLaunch)
    }

    func testCancelBeforeStartReturnsImmediately() async {
        let deleter = AdminDeleter()
        deleter.cancel()
        let (status, _, _) = await deleter.runProc("/bin/sh", ["-c", "sleep 30"], stream: false, log: nil)
        XCTAssertEqual(status, ProcExit.cancelledBeforeStart)
    }

    func testStreamingDeliversLines() async {
        let box = LineBox()
        _ = await AdminDeleter().runProc(
            "/bin/sh", ["-c", "printf 'a\\nb\\nc\\n'"], stream: true, log: { box.append($0) })
        XCTAssertEqual(box.lines, ["a", "b", "c"])
    }
}

private final class LineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    func append(_ s: String) { lock.lock(); storage.append(s); lock.unlock() }
    var lines: [String] { lock.lock(); defer { lock.unlock() }; return storage }
}
