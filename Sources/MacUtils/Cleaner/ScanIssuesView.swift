import SwiftUI

struct ScanIssuesView: View {
    let issues: [FileIssue]
    var omittedCount = 0

    var body: some View {
        if !issues.isEmpty || omittedCount > 0 {
            DisclosureGroup(
                "Scan incomplete · \(issues.count + omittedCount) access or read error\(issues.count + omittedCount == 1 ? "" : "s")"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        "Unreadable and partially scanned folders are excluded from cleanup. Resolve these errors and scan again."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(issues) { issue in
                                Text(issue.description).font(.caption).textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    if omittedCount > 0 { Text("\(omittedCount) additional errors omitted.").font(.caption) }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color.orange.opacity(0.08))
        }
    }
}
