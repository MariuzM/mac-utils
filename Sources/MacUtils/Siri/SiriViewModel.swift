import Foundation

@MainActor
final class SiriViewModel: ObservableObject {
    @Published private(set) var snapshot: SiriSnapshot?
    @Published private(set) var isWorking = false
    @Published private(set) var canRestore = false
    @Published private(set) var details: [String] = []
    @Published private(set) var error: String?
    @Published private(set) var activity = ""

    private let controller: SiriController

    init(controller: SiriController = SiriController()) {
        self.controller = controller
    }

    func refresh() {
        perform("Checking Siri…") { controller in
            SiriOperation(snapshot: try await controller.inspect(), details: [])
        }
    }

    func disable() {
        perform("Disabling Siri and verifying…") { try await $0.disable() }
    }

    func restore() {
        perform("Restoring your previous settings…") { try await $0.restore() }
    }

    private func perform(
        _ activity: String, operation: @escaping @Sendable (SiriController) async throws -> SiriOperation
    ) {
        guard !isWorking else { return }
        isWorking = true
        self.activity = activity
        error = nil
        Task {
            defer {
                isWorking = false
                self.activity = ""
            }
            do {
                let result = try await operation(controller)
                snapshot = result.snapshot
                details = result.details
            } catch let e {
                error = e.localizedDescription
                snapshot = try? await controller.inspect()
            }
            canRestore = await controller.hasBackup()
        }
    }
}
