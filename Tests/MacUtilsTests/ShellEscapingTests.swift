import XCTest
@testable import MacUtils

final class ShellEscapingTests: XCTestCase {
    func testQuoteWrapsPlainPaths() {
        XCTAssertEqual(Shell.quote("/tmp/file"), "'/tmp/file'")
    }

    func testQuoteNeutralisesEmbeddedSingleQuote() {
        XCTAssertEqual(Shell.quote("/Users/x/Bob's Stuff"), "'/Users/x/Bob'\\''s Stuff'")
    }

    func testQuotedPathSurvivesRoundTripThroughRealShell() throws {
        let tricky = [
            "/tmp/Bob's Stuff",
            "/tmp/with space",
            "/tmp/semi;colon",
            "/tmp/dollar$VAR",
            "/tmp/back\\slash",
            "/tmp/quote\"double",
            "/tmp/pipe|and&amp",
            "/tmp/newline\nsecond",
        ]
        for path in tricky {
            let result = Shell.run("/bin/sh", ["-c", "printf '%s' \(Shell.quote(path))"])
            XCTAssertTrue(result.succeeded, "shell failed for \(path)")
            XCTAssertEqual(result.stdout, path, "quoting mangled \(path)")
        }
    }

    func testQuotingPreventsCommandInjection() {
        let malicious = "/tmp/x'; echo PWNED; echo '"
        let result = Shell.run("/bin/sh", ["-c", "printf '%s' \(Shell.quote(malicious))"])
        XCTAssertEqual(result.stdout, malicious)
    }

    func testHostilePathSurvivesTheFullAppleScriptThenShellDoubleEncoding() {
        let hostile = #"/tmp/x'; touch /tmp/PWNED_$$; echo '"# + "\" \\ end"
        let inner = "printf '%s' " + Shell.quote(hostile)
        let script = "do shell script \(Shell.appleScriptLiteral(inner))"
        let result = Shell.run("/usr/bin/osascript", ["-e", script])

        XCTAssertTrue(result.succeeded, "double-encoded command was rejected: \(result.stderr)")
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), hostile,
                       "path was mangled or interpreted crossing Swift -> AppleScript -> shell")
    }

    func testDoubleEncodedNewlinePathDoesNotSplitIntoASecondCommand() {
        let hostile = "/tmp/a\ntouch /tmp/PWNED_NEWLINE"
        let inner = "printf '%s' " + Shell.quote(hostile)
        let script = "do shell script \(Shell.appleScriptLiteral(inner))"
        let result = Shell.run("/usr/bin/osascript", ["-e", script])

        XCTAssertTrue(result.succeeded, "newline broke the AppleScript literal: \(result.stderr)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/tmp/PWNED_NEWLINE"),
                       "a newline in a path executed as a separate command")
    }

    func testAppleScriptLiteralEscapesQuotesBackslashesAndNewlines() {
        XCTAssertEqual(Shell.appleScriptLiteral("plain"), "\"plain\"")
        XCTAssertEqual(Shell.appleScriptLiteral("a\"b"), "\"a\\\"b\"")
        XCTAssertEqual(Shell.appleScriptLiteral("a\\b"), "\"a\\\\b\"")
        XCTAssertEqual(Shell.appleScriptLiteral("a\nb"), "\"a\\nb\"")
    }

    func testAppleScriptLiteralIsAcceptedByOsascript() {
        let payload = "hello \"world\" \\ and 'single'"
        let script = "return \(Shell.appleScriptLiteral(payload))"
        let result = Shell.run("/usr/bin/osascript", ["-e", script])
        XCTAssertTrue(result.succeeded, "osascript rejected: \(result.stderr)")
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), payload)
    }

    func testAppleScriptLiteralWithNewlineDoesNotBreakOutOfTheStringLiteral() {
        let payload = "line1\nline2"
        let script = "return \(Shell.appleScriptLiteral(payload))"
        let result = Shell.run("/usr/bin/osascript", ["-e", script])
        XCTAssertTrue(result.succeeded, "newline broke the literal: \(result.stderr)")
    }

    func testRunCapturesStderrSeparatelyFromStdout() {
        let result = Shell.run("/bin/sh", ["-c", "printf out; printf err >&2; exit 3"])
        XCTAssertEqual(result.stdout, "out")
        XCTAssertEqual(result.stderr, "err")
        XCTAssertEqual(result.status, 3)
        XCTAssertFalse(result.succeeded)
    }

    func testRunReportsFailedLaunchInsteadOfCrashing() {
        let result = Shell.run("/nonexistent/binary/xyz")
        XCTAssertEqual(result.status, ProcExit.failedToLaunch)
    }

    func testRunHandlesOutputLargerThanPipeBuffer() {
        let result = Shell.run("/bin/sh", ["-c", "yes ABCDEFGHIJ | head -c 400000"])
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdout.count, 400_000)
    }

    func testRunHandlesLargeStderrWithoutDeadlocking() {
        let result = Shell.run("/bin/sh", ["-c", "yes ABCDEFGHIJ | head -c 400000 >&2"])
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stderr.count, 400_000)
    }

    func testRunHandlesLargeOutputOnBothStreamsSimultaneously() {
        let script = "yes OUT | head -c 300000 & yes ERR | head -c 300000 >&2; wait"
        let result = Shell.run("/bin/sh", ["-c", script])
        XCTAssertEqual(result.stdout.count, 300_000)
        XCTAssertEqual(result.stderr.count, 300_000)
    }
}
