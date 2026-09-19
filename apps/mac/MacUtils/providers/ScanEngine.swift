import Foundation

struct ScanProgress: Sendable {
    var phase: String
    var fraction: Double
}

struct ScanReport: Sendable {
    let volumes: [VolumeResult]
    let issues: [FileIssue]
    let omittedIssueCount: Int
}

private struct Entry {
    let url: URL
    let name: String
    let isDirectory: Bool
}

private struct RuleScaffold {
    let rule: ScanRule
    let entries: [Entry]
}

private struct VolumeScaffold {
    let name: String
    let url: URL
    let isBoot: Bool
    let rules: [RuleScaffold]
}

private struct SizeJob {
    let url: URL
    let isDirectory: Bool
}

actor ScanEngine {
    private let fm = FileManager.default
    private var diagnostics = ScanDiagnostics()

    func scan(rules: [ScanRule]? = nil, progress: @escaping @Sendable (ScanProgress) -> Void) async -> ScanReport {
        diagnostics = ScanDiagnostics()
        let diagnostics = self.diagnostics
        progress(ScanProgress(phase: "Enumerating…", fraction: 0))
        let source =
            rules.map {
                [
                    VolumeScaffold(
                        name: "Selected locations", url: URL(fileURLWithPath: "/"), isBoot: true,
                        rules: $0.map { scaffold(for: $0) })
                ]
            }
            ?? buildScaffolds(progress: progress)
        let scaffolds = removeOverlaps(source)

        var jobs: [SizeJob] = []
        for vol in scaffolds {
            for r in vol.rules {
                for e in r.entries {
                    jobs.append(SizeJob(url: e.url, isDirectory: e.isDirectory))
                }
            }
        }

        var sizes = [Int64](repeating: 0, count: jobs.count)
        let totalJobs = max(jobs.count, 1)
        let limit = min(8, max(2, ProcessInfo.processInfo.activeProcessorCount))

        var completed = 0
        await withTaskGroup(of: (Int, Int64).self) { group in
            var next = 0
            while next < min(limit, jobs.count) {
                let i = next
                let job = jobs[i]
                group.addTask {
                    (i, ScanEngine.entrySize(job.url, isDirectory: job.isDirectory, diagnostics: diagnostics))
                }
                next += 1
            }

            while let (i, size) = await group.next() {
                sizes[i] = size
                completed += 1
                if completed % 4 == 0 || completed == jobs.count {
                    progress(
                        ScanProgress(
                            phase: "Sizing… \(completed)/\(jobs.count)",
                            fraction: Double(completed) / Double(totalJobs)))
                }
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                if next < jobs.count {
                    let j = next
                    let job = jobs[j]
                    group.addTask {
                        (j, ScanEngine.entrySize(job.url, isDirectory: job.isDirectory, diagnostics: diagnostics))
                    }
                    next += 1
                }
            }
        }

        var results: [VolumeResult] = []
        var k = 0
        for vol in scaffolds {
            var categories: [CategoryResult] = []
            for r in vol.rules {
                var items: [ScanItem] = []
                var total: Int64 = 0
                for e in r.entries {
                    guard k < sizes.count else { break }
                    let size = sizes[k]
                    k += 1
                    guard size > 0, !diagnostics.isIncomplete(e.url) else { continue }
                    items.append(ScanItem(url: e.url, name: e.name, size: size, isDirectory: e.isDirectory))
                    total += size
                }
                guard total > 0 else { continue }
                items.sort { $0.size > $1.size }
                categories.append(
                    CategoryResult(
                        ruleID: r.rule.id,
                        title: r.rule.title,
                        subtitle: r.rule.subtitle,
                        safety: r.rule.safety,
                        items: items,
                        totalSize: total))
            }
            categories.sort { $0.totalSize > $1.totalSize }
            if vol.isBoot || !categories.isEmpty {
                results.append(VolumeResult(name: vol.name, url: vol.url, isBoot: vol.isBoot, categories: categories))
            }
        }

        if Task.isCancelled {
            progress(ScanProgress(phase: "Cancelled", fraction: 0))
        } else {
            progress(ScanProgress(phase: "Done", fraction: 1.0))
        }
        return ScanReport(volumes: results, issues: diagnostics.snapshot, omittedIssueCount: diagnostics.omittedCount)
    }

    private func removeOverlaps(_ volumes: [VolumeScaffold]) -> [VolumeScaffold] {
        let paths = Set(volumes.flatMap { $0.rules.flatMap { $0.entries.map { $0.url.standardizedFileURL.path } } })
        var seen = Set<String>()
        return volumes.map { volume in
            let rules = volume.rules.map { scaffold in
                let entries = scaffold.entries.filter { entry in
                    let path = entry.url.standardizedFileURL.path
                    guard !paths.contains(where: { $0 != path && DeletionPolicy.contains($0, path) }) else {
                        return false
                    }
                    return seen.insert(path).inserted
                }
                return RuleScaffold(rule: scaffold.rule, entries: entries)
            }
            return VolumeScaffold(name: volume.name, url: volume.url, isBoot: volume.isBoot, rules: rules)
        }
    }

    private func buildScaffolds(progress: @escaping @Sendable (ScanProgress) -> Void) -> [VolumeScaffold] {
        let boot = bootVolumeURL()
        let volumes = mountedVolumes()
        let home = fm.homeDirectoryForCurrentUser

        var scaffolds: [VolumeScaffold] = []

        progress(ScanProgress(phase: "Finding node_modules…", fraction: 0))
        var bootRules = ScanRules.homeRules() + ScanRules.systemRules()
        bootRules += nodeModulesRules(under: home, root: home)
        scaffolds.append(
            VolumeScaffold(
                name: volumeName(boot) + " (Startup)",
                url: boot,
                isBoot: true,
                rules: bootRules.map { scaffold(for: $0) }))

        for v in volumes where v.path != boot.path {
            if Task.isCancelled { break }
            var rules = ScanRules.volumeRules(for: v)
            rules += nodeModulesRules(under: v, root: v)
            scaffolds.append(
                VolumeScaffold(
                    name: volumeName(v), url: v, isBoot: false,
                    rules: rules.map { scaffold(for: $0) }))
        }

        return scaffolds
    }

    private func nodeModulesRules(under searchRoot: URL, root: URL) -> [ScanRule] {
        let found = findNodeModules(under: searchRoot)
        guard !found.isEmpty else { return [] }

        var groups: [String: [URL]] = [:]
        for nm in found {
            let container = nm.deletingLastPathComponent().deletingLastPathComponent()
            groups[container.path, default: []].append(nm)
        }

        return groups.sorted { $0.key < $1.key }.map { key, urls in
            let count = urls.count
            return ScanRule(
                id: "node-modules:\(key)",
                title: "node_modules · \(relativeLabel(key, root: root))",
                subtitle:
                    "\(count) project\(count == 1 ? "" : "s") in \(key). Reinstall dependencies before running these projects.",
                safety: .caution,
                paths: urls.sorted { $0.path < $1.path },
                expandChildren: false)
        }
    }

    private func findNodeModules(under root: URL, maxDepth: Int = 8) -> [URL] {
        guard isDirectory(root) else { return [] }
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard
            let en = fm.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { [diagnostics] url, error in
                    diagnostics.record(error, at: url)
                    return true
                })
        else {
            return []
        }

        var results: [URL] = []
        var counter = 0
        for case let url as URL in en {
            counter += 1
            if counter & 0x3FF == 0, Task.isCancelled { break }
            if en.level > maxDepth {
                en.skipDescendants()
                continue
            }
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            if name == "node_modules" {
                results.append(url)
                en.skipDescendants()
            } else if name == "Library" || name.hasPrefix("Mac Utils Backup ") {
                en.skipDescendants()
            }
        }
        return results
    }

    private func relativeLabel(_ containerPath: String, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        if containerPath == rootPath { return root.lastPathComponent }
        if containerPath.hasPrefix(rootPath + "/") {
            return String(containerPath.dropFirst(rootPath.count + 1))
        }
        return containerPath
    }

    private func scaffold(for rule: ScanRule) -> RuleScaffold {
        var entries: [Entry] = []
        for base in rule.paths {
            if Task.isCancelled { break }
            do {
                let values = try base.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { continue }
                if rule.expandChildren, values.isDirectory == true {
                    let children = try fm.contentsOfDirectory(
                        at: base, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [])
                    for child in children {
                        if Task.isCancelled { break }
                        do {
                            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                            guard values.isSymbolicLink != true, rule.includes(child) else { continue }
                            entries.append(
                                Entry(
                                    url: child, name: child.lastPathComponent, isDirectory: values.isDirectory == true))
                        } catch { diagnostics.record(error, at: child) }
                    }
                } else if rule.includes(base) {
                    entries.append(
                        Entry(url: base, name: base.lastPathComponent, isDirectory: values.isDirectory == true))
                }
            } catch { diagnostics.record(error, at: base) }
        }
        return RuleScaffold(rule: rule, entries: entries)
    }

    nonisolated static func entrySize(_ url: URL, isDirectory: Bool, diagnostics: ScanDiagnostics? = nil) -> Int64 {
        if Task.isCancelled { return 0 }
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ]
        do {
            let values = try url.resourceValues(forKeys: keys)
            if values.isSymbolicLink == true { return 0 }
            if !isDirectory {
                return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            }
        } catch {
            diagnostics?.record(error, at: url, root: url)
            return 0
        }
        let fm = FileManager()
        var total: Int64 = 0
        guard
            let en = fm.enumerator(
                at: url, includingPropertiesForKeys: Array(keys), options: [],
                errorHandler: { child, error in
                    diagnostics?.record(error, at: child, root: url)
                    return true
                })
        else { return 0 }
        for case let child as URL in en {
            if Task.isCancelled { break }
            do {
                let values = try child.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true {
                    en.skipDescendants()
                    continue
                }
                if values.isRegularFile == true {
                    total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
                }
            } catch { diagnostics?.record(error, at: child, root: url) }
        }
        return total
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let ok = fm.fileExists(atPath: url.path, isDirectory: &isDir)
        return ok && isDir.boolValue
    }

    private func mountedVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsBrowsableKey, .volumeIsLocalKey, .volumeIsReadOnlyKey]
        let urls =
            fm.mountedVolumeURLs(
                includingResourceValuesForKeys: keys,
                options: [.skipHiddenVolumes]) ?? []
        return urls.filter { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            return (v?.volumeIsBrowsable ?? true) && (v?.volumeIsLocal ?? true) && v?.volumeIsReadOnly != true
        }
    }

    private func bootVolumeURL() -> URL {
        URL(fileURLWithPath: "/")
    }

    private func volumeName(_ url: URL) -> String {
        let v = try? url.resourceValues(forKeys: [.volumeNameKey])
        return v?.volumeName ?? url.lastPathComponent
    }
}
