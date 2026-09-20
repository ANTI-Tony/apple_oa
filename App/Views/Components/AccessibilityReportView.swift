import ReportCore
import SwiftUI

/// The accessibility report shown in the badge popover: verdict, issues (each
/// jumps to its block) and, on demand, every rule that was checked.
struct AccessibilityReportView: View {
    let report: AccessibilityReport
    let onSelectIssue: (AccessibilityIssue) -> Void

    @State private var showAllChecks = false

    private var failedRules: Set<AccessibilityRule> {
        Set(report.issues.map(\.rule))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: report.isCompliant ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(report.isCompliant ? .green : .red)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.isCompliant ? "Ready to share" : "Fix before sharing")
                        .font(.headline)
                    Text(report.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            if !report.issues.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(report.issues) { issue in
                        IssueRow(issue: issue) { onSelectIssue(issue) }
                    }
                }
            }

            Divider()
            DisclosureGroup("What is checked (\(report.rulesEvaluated) rules)", isExpanded: $showAllChecks) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(AccessibilityRule.allCases, id: \.self) { rule in
                        let failed = failedRules.contains(rule)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(failed ? .red : .green)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rule.title).font(.callout)
                                Text(rule.wcagReference).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(rule.title), \(failed ? "failed" : "passed"), \(rule.wcagReference)")
                    }
                }
                .padding(.top, 8)
            }
            .font(.callout)
        }
        .padding(16)
        .frame(width: 340)
        .accessibilityIdentifier("accessibility.report")
    }
}

private struct IssueRow: View {
    let issue: AccessibilityIssue
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: issue.severity == .error ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(issue.severity == .error ? .red : .orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.message).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Text(issue.rule.wcagReference).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if issue.blockID != nil {
                    Image(systemName: "arrow.right.circle").foregroundStyle(.secondary).accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(issue.severity == .error ? "Error" : "Warning"): \(issue.message)")
        .accessibilityHint(issue.blockID == nil ? "" : "Jumps to the block in the editor")
    }
}
