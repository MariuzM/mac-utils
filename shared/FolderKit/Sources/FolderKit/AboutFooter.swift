import SwiftUI

public enum Developer {
    public static let name = "Marius.dev"
    public static let url = URL(string: "https://marius.dev")!

    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

public struct AboutFooter: View {
    private let component: String

    public init(component: String) {
        self.component = component
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text("\(component) \(Developer.version)")
            Text("·")
            Text("by")
            Link(Developer.name, destination: Developer.url)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
