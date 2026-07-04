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
        let scaffolds = buildScaffolds()

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

        progress(ScanProgress(phase: "Done", fraction: 1.0))
        return results
    }

    private func buildScaffolds() -> [VolumeScaffold] {
        let boot = bootVolumeURL()
        let volumes = mountedVolumes()

        var scaffolds: [VolumeScaffold] = []

        let bootRules = ScanRules.homeRules() + ScanRules.systemRules()
        scaffolds.append(VolumeScaffold(name: volumeName(boot) + " (Startup)",
                                        url: boot,
                                        isBoot: true,
                                        rules: bootRules.map { scaffold(for: $0) }))

        for v in volumes where v.path != boot.path {
            let rules = ScanRules.volumeRules(for: v).map { scaffold(for: $0) }
            scaffolds.append(VolumeScaffold(name: volumeName(v), url: v, isBoot: false, rules: rules))
        }

        return scaffolds
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
