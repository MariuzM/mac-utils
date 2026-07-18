import Foundation

struct ShellResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { status == 0 }
    var combined: String { stdout + stderr }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func set(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

enum Shell {
    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptLiteral(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
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
    static func run(_ executable: String, _ arguments: [String] = []) -> ShellResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        guard (try? task.run()) != nil else {
            return ShellResult(status: ProcExit.failedToLaunch, stdout: "", stderr: "")
        }

        let outBox = DataBox()
        let errBox = DataBox()
        let group = DispatchGroup()

        for (pipe, box) in [(outPipe, outBox), (errPipe, errBox)] {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                box.set(pipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
        }

        group.wait()
        task.waitUntilExit()

        return ShellResult(
            status: task.terminationStatus,
            stdout: String(data: outBox.value, encoding: .utf8) ?? "",
            stderr: String(data: errBox.value, encoding: .utf8) ?? ""
        )
    }

    static func runData(_ executable: String, _ arguments: [String] = []) -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        guard (try? task.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return task.terminationStatus == 0 ? data : nil
    }
}
