import ReportCore
import SwiftUI

/// Compact pass/fail summary above the preview. Opens the full report in a
/// popover, so accessibility stays one click away without taking a column.
struct AccessibilityBadge: View {
    let report: AccessibilityReport
    @Binding var isReportPresented: Bool
    let onSelectIssue: (AccessibilityIssue) -> Void

    private var title: String {
        if !report.isCompliant {
            return "\(report.errors.count) \(report.errors.count == 1 ? "error" : "errors") to fix"
        }
        if !report.warnings.isEmpty {
            return "AA ready · \(report.warnings.count) \(report.warnings.count == 1 ? "warning" : "warnings")"
        }
        return "AA ready"
    }

    private var symbol: String {
        report.isCompliant ? (report.warnings.isEmpty ? "checkmark.shield.fill" : "exclamationmark.shield.fill") : "xmark.shield.fill"
    }

    private var tint: Color {
        report.isCompliant ? (report.warnings.isEmpty ? .green : .orange) : .red
    }

    var body: some View {
        Button {
            isReportPresented.toggle()
        } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .help("Show the accessibility report (⌥⌘I)")
        .accessibilityIdentifier("preview.accessibilityBadge")
        .popover(isPresented: $isReportPresented, arrowEdge: .bottom) {
            AccessibilityReportView(report: report) { issue in
                isReportPresented = false
                onSelectIssue(issue)
            }
        }
    }
}
