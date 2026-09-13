import Darwin
import Foundation

struct ShellResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String

    var outputData: Data? = nil

    var succeeded: Bool { status == 0 }
    var combined: String { stdout + stderr }
}

final class CommandRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.withLock { cancelled = true }
    }

    private var isCancelled: Bool { lock.withLock { cancelled } }

    func run(
        _ executable: String, _ arguments: [String], timeout: TimeInterval = 30,
        log: (@Sendable (String) -> Void)? = nil
    ) -> ShellResult {
        guard !isCancelled else {
            return ShellResult(status: ProcExit.cancelledBeforeStart, stdout: "", stderr: "Cancelled.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch let e {
            return ShellResult(status: ProcExit.failedToLaunch, stdout: "", stderr: e.localizedDescription)
        }

        try? output.fileHandleForWriting.close()
        try? errors.fileHandleForWriting.close()
        let streams = [output.fileHandleForReading, errors.fileHandleForReading]
        for stream in streams {
            let flags = fcntl(stream.fileDescriptor, F_GETFL)
            _ = fcntl(stream.fileDescriptor, F_SETFL, flags | O_NONBLOCK)
        }
        defer {
            for stream in streams { try? stream.close() }
        }

        var data = [Data(), Data()]
        var closed = [false, false]
        var buffer = [UInt8](repeating: 0, count: 16_384)
        let start = ProcessInfo.processInfo.systemUptime
        var stoppedAt: TimeInterval?
        var terminatedAt: TimeInterval?
        var forcedStatus: Int32?
        let outputLimit = 8 * 1024 * 1024

        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if process.isRunning && terminatedAt == nil && (isCancelled || now - start >= timeout) {
                forcedStatus = isCancelled ? ProcExit.cancelledBeforeStart : ProcExit.timedOut
                process.terminate()
                terminatedAt = now
            }
            if process.isRunning, let terminatedAt, now - terminatedAt > 1 {
                _ = kill(process.processIdentifier, SIGKILL)
            }

            for i in streams.indices where !closed[i] {
                for _ in 0..<16 {
                    let count = Darwin.read(streams[i].fileDescriptor, &buffer, buffer.count)
                    if count > 0 {
                        log?(String(decoding: buffer.prefix(count), as: UTF8.self))
                        let remaining = max(0, outputLimit - data[i].count)
                        data[i].append(contentsOf: buffer.prefix(min(count, remaining)))
                        if count > remaining { forcedStatus = forcedStatus ?? ProcExit.outputLimit }
                    } else {
                        if count == 0 || (errno != EAGAIN && errno != EINTR) { closed[i] = true }
                        break
                    }
                }
            }

            if !process.isRunning {
                if stoppedAt == nil { stoppedAt = now }
                if closed.allSatisfy({ $0 }) || now - (stoppedAt ?? now) > 0.25 { break }
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        process.waitUntilExit()

        var stderr = String(decoding: data[1], as: UTF8.self)
        if forcedStatus == ProcExit.timedOut { stderr += "\nCommand timed out after \(Int(timeout)) seconds." }
        if forcedStatus == ProcExit.outputLimit { stderr += "\nCommand output exceeded the capture limit." }
        return ShellResult(
            status: forcedStatus ?? process.terminationStatus,
            stdout: String(decoding: data[0], as: UTF8.self),
            stderr: stderr,
            outputData: data[0]
        )
    }

    func runAsync(
        _ executable: String, _ arguments: [String], timeout: TimeInterval = 30,
        log: (@Sendable (String) -> Void)? = nil
    ) async -> ShellResult {
        await withTaskCancellationHandler {
            await Task.detached(priority: .userInitiated) {
                self.run(executable, arguments, timeout: timeout, log: log)
            }.value
        } onCancel: {
            self.cancel()
        }
    }
}

enum Shell {
    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptLiteral(_ s: String) -> String {
        "\""
            + s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r") + "\""
    }

    static func indicatesCancellation(_ text: String) -> Bool {
        text.contains("-128")
            || text.localizedCaseInsensitiveContains("user canceled")
            || text.localizedCaseInsensitiveContains("user cancelled")
    }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String] = [], timeout: TimeInterval = 30) -> ShellResult {
        CommandRunner().run(executable, arguments, timeout: timeout)
    }

    static func runData(_ executable: String, _ arguments: [String] = []) -> Data? {
        let result = run(executable, arguments)
        return result.succeeded ? (result.outputData ?? result.stdout.data(using: .utf8)) : nil
    }
}
