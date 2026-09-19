import SwiftUI

struct ScanIssuesView: View {
    let issues: [FileIssue]
    var omittedCount = 0

    var body: some View {
        if !issues.isEmpty || omittedCount > 0 {
            BannerBar {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "Unreadable and partially scanned folders are excluded from cleanup. Resolve these errors and scan again."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(issues) { issue in
                                    Text(issue.description)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 150)
                        if omittedCount > 0 {
                            Text("\(omittedCount) additional errors omitted.").font(.caption)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label(title, systemImage: "exclamationmark.triangle")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var title: String {
        let count = issues.count + omittedCount
        return "Scan incomplete · \(count) access or read error\(count == 1 ? "" : "s")"
    }
}
