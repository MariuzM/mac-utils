import Darwin
import Foundation

protocol SiriSystem: Sendable {
    var userID: UInt32 { get }
    func installed(_ service: SiriService) -> Bool
    func preference(_ preference: SiriPreference) throws -> Data?
    func setPreference(_ preference: SiriPreference, value: Data?) throws
    func command(_ arguments: [String]) async -> ShellResult
    func stop(_ service: SiriService) throws
}

struct LocalSiriSystem: SiriSystem {
    var userID: UInt32 { getuid() }

    func installed(_ service: SiriService) -> Bool {
        FileManager.default.fileExists(atPath: service.plistPath)
    }

    func preference(_ preference: SiriPreference) throws -> Data? {
        guard CFPreferencesSynchronize(preference.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        else {
            throw SiriError.failed("Could not read \(preference.domain).")
        }
        guard
            let value = CFPreferencesCopyValue(
                preference.key as CFString, preference.domain as CFString,
                kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        else { return nil }
        return try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
    }

    func setPreference(_ preference: SiriPreference, value: Data?) throws {
        var restoredValue: CFPropertyList?
        if let value {
            guard let decoded = try PropertyListSerialization.propertyList(from: value, format: nil) as? [String: Any],
                let savedValue = decoded["value"]
            else {
                throw SiriError.failed("Invalid saved preference for \(preference.key).")
            }
            restoredValue = savedValue as CFPropertyList
        }
        CFPreferencesSetValue(
            preference.key as CFString, restoredValue,
            preference.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(preference.domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        else {
            throw SiriError.failed("macOS did not save \(preference.key).")
        }
    }

    func command(_ arguments: [String]) async -> ShellResult {
        await CommandRunner().runAsync(SystemPaths.launchctl, arguments, timeout: 10)
    }

    func stop(_ service: SiriService) throws {
        let target = service.executable
        var pids = [pid_t](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard count > 0 && count < pids.count else {
            throw SiriError.failed("Could not safely enumerate Siri processes.")
        }
        for pid in pids.prefix(Int(count)) where pid > 1 && pid != getpid() {
            var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0,
                String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self) == target
            else { continue }
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
                info.pbi_uid == getuid()
            else { continue }
            guard kill(pid, SIGTERM) == 0 || errno == ESRCH else {
                throw SiriError.failed("macOS refused to stop \(service.name): \(String(cString: strerror(errno))).")
            }
        }
    }
}
