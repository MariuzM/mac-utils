import Foundation
import SwiftUI
import AppKit

@MainActor
final class SpotlightViewModel: ObservableObject {
    @Published private(set) var folders: [SpotlightFolder] = []
    @Published private(set) var loaded = false
    @Published private(set) var isWorking = false
    @Published var status = ""
    @Published var lastError: String?
    @Published var showError = false

    private var expectingChange = false
    private var loadTask: Task<Void, Never>?

    deinit { loadTask?.cancel() }

    func refreshIfExpectingChange() {
        guard expectingChange else { return }
        expectingChange = false
        refresh()
    }

    func refresh() {
        guard !isWorking else { return }
        isWorking = true
        status = "Reading Spotlight privacy list…"
        loadTask?.cancel()
        loadTask = Task {
            do {
                let paths = try await Task.detached(priority: .userInitiated) {
                    try SpotlightManager.loadExclusions()
                }.value
                folders = paths.map { SpotlightFolder(path: $0) }
                loaded = true
            } catch let e as SpotlightError {
                if case .cancelled = e {} else { fail(e.localizedDescription) }
            } catch let e {
                fail(e.localizedDescription)
            }
            isWorking = false
            status = ""
        }
    }

    func openSettings() {
        expectingChange = true
        SpotlightManager.openPrivacySettings()
    }

    func reveal(_ folder: SpotlightFolder) {
        NSWorkspace.shared.activateFileViewerSelecting([folder.url])
    }

    private func fail(_ message: String) {
        lastError = message
        showError = true
    }
}
