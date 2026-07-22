import Foundation

struct ScanProgress {
    var phase: String
    var fraction: Double
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

    func scan(progress: @escaping @Sendable (ScanProgress) -> Void) async -> [VolumeResult] {
        progress(ScanProgress(phase: "Enumerating…", fraction: 0))
        let scaffolds = buildScaffolds(progress: progress)

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
        let limit = max(2, ProcessInfo.processInfo.activeProcessorCount * 2)

        var completed = 0
        await withTaskGroup(of: (Int, Int64).self) { group in
            var next = 0
            while next < min(limit, jobs.count) {
                let i = next
                let job = jobs[i]
                group.addTask { (i, ScanEngine.entrySize(job.url, isDirectory: job.isDirectory)) }
                next += 1
            }

            while let (i, size) = await group.next() {
                sizes[i] = size
                completed += 1
                if completed % 4 == 0 || completed == jobs.count {
                    progress(ScanProgress(phase: "Sizing… \(completed)/\(jobs.count)",
                                          fraction: Double(completed) / Double(totalJobs)))
                }
                if Task.isCancelled { group.cancelAll(); break }
                if next < jobs.count {
                    let j = next
                    let job = jobs[j]
                    group.addTask { (j, ScanEngine.entrySize(job.url, isDirectory: job.isDirectory)) }
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
                    guard size > 0 else { continue }
                    items.append(ScanItem(url: e.url, name: e.name, size: size, isDirectory: e.isDirectory))
                    total += size
                }
                guard total > 0 else { continue }
                items.sort { $0.size > $1.size }
                categories.append(CategoryResult(ruleID: r.rule.id,
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
        return results
    }

    private func buildScaffolds(progress: @escaping @Sendable (ScanProgress) -> Void) -> [VolumeScaffold] {
        let boot = bootVolumeURL()
        let volumes = mountedVolumes()
        let home = fm.homeDirectoryForCurrentUser

        var scaffolds: [VolumeScaffold] = []

        progress(ScanProgress(phase: "Finding node_modules…", fraction: 0))
        var bootRules = ScanRules.homeRules() + ScanRules.systemRules()
        bootRules += nodeModulesRules(under: home, root: home)
        scaffolds.append(VolumeScaffold(name: volumeName(boot) + " (Startup)",
                                        url: boot,
                                        isBoot: true,
                                        rules: bootRules.map { scaffold(for: $0) }))

        for v in volumes where v.path != boot.path {
            var rules = ScanRules.volumeRules(for: v)
            rules += nodeModulesRules(under: v, root: v)
            scaffolds.append(VolumeScaffold(name: volumeName(v), url: v, isBoot: false,
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
            return ScanRule(id: "node-modules:\(key)",
                            title: "node_modules · \(relativeLabel(key, root: root))",
                            subtitle: "\(count) project\(count == 1 ? "" : "s") in \(key)",
                            safety: .safe,
                            paths: urls.sorted { $0.path < $1.path },
                            expandChildren: false)
        }
    }

    private func findNodeModules(under root: URL, maxDepth: Int = 8) -> [URL] {
        guard isDirectory(root) else { return [] }
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: keys,
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                     errorHandler: { _, _ in true }) else {
            return []
        }

        var results: [URL] = []
        var counter = 0
        for case let url as URL in en {
            counter += 1
            if counter & 0x3FF == 0, Task.isCancelled { break }
            if en.level > maxDepth { en.skipDescendants(); continue }
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            if name == "node_modules" {
                results.append(url)
                en.skipDescendants()
            } else if name == "Library" {
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
            if rule.expandChildren, isDirectory(base) {
                let children = (try? fm.contentsOfDirectory(at: base,
                                                            includingPropertiesForKeys: [.isDirectoryKey],
                                                            options: [.skipsHiddenFiles])) ?? []
                for child in children {
                    entries.append(Entry(url: child, name: child.lastPathComponent, isDirectory: isDirectory(child)))
                }
            } else {
                entries.append(Entry(url: base, name: base.lastPathComponent, isDirectory: isDirectory(base)))
            }
        }
        return RuleScaffold(rule: rule, entries: entries)
    }

    nonisolated static func entrySize(_ url: URL, isDirectory: Bool) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]

        if !isDirectory {
            let values = try? url.resourceValues(forKeys: Set(keys))
            return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
        }

        let fm = FileManager()
        var total: Int64 = 0
        guard let en = fm.enumerator(at: url,
                                     includingPropertiesForKeys: keys,
                                     options: [.skipsPackageDescendants],
                                     errorHandler: { _, _ in true }) else {
            return 0
        }
        var counter = 0
        for case let child as URL in en {
            counter += 1
            if counter & 0x3FF == 0, Task.isCancelled { break }
            let values = try? child.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
            }
        }
        return total
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let ok = fm.fileExists(atPath: url.path, isDirectory: &isDir)
        return ok && isDir.boolValue
    }

    private func mountedVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsBrowsableKey, .volumeIsLocalKey]
        let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                        options: [.skipHiddenVolumes]) ?? []
        return urls.filter { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            return (v?.volumeIsBrowsable ?? true) && (v?.volumeIsLocal ?? true)
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
