import ReportCore
import SwiftUI

/// The linter's verdict, its findings (each selects the block at fault) and
/// every rule it checks.
struct AccessibilityInspector: View {
    let card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace
    @Environment(UserPreferences.self) private var preferences
    @State private var showTranscript = false

    private var report: AccessibilityReport {
        AccessibilityLinter.lint(card)
    }

    var body: some View {
        let report = report
        let failedRules = Set(report.issues.map(\.rule))
        @Bindable var workspace = workspace
        Form {
            Section {
                // Stacked, not side by side: the summary is a sentence, and a sentence
                // squeezed into a trailing column wraps ragged-left.
                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        report.isCompliant ? "Ready to Share" : "Needs Attention",
                        systemImage: report.isCompliant ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(report.isCompliant ? Color.primary : Color.red)
                    Text(report.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("inspector.accessibilityVerdict")
            }
            if !report.issues.isEmpty {
                Section("Issues") {
                    ForEach(report.issues) { issue in
                        Button {
                            if let blockID = issue.blockID {
                                workspace.selectedBlockID = blockID
                                workspace.scrollTarget = blockID
                                workspace.inspectorTab = .block
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.message)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(issue.rule.wcagReference)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(issue.severity == .error ? "Error" : "Warning"): \(issue.message)")
                        .accessibilityHint(issue.blockID == nil ? "" : "Shows the block in the inspector")
                    }
                }
            }
            Section {
                Button {
                    workspace.toggleSpeech(for: card, includeFooter: preferences.includeFooter)
                } label: {
                    Label(
                        workspace.speech.isSpeaking ? "Stop" : "Hear This Card",
                        systemImage: workspace.speech.isSpeaking ? "stop.fill" : "play.fill"
                    )
                }
                .accessibilityIdentifier("inspector.listen")
                DisclosureGroup("Transcript", isExpanded: $showTranscript) {
                    SpokenTranscript(
                        segments: SpokenRenderer(includeFooter: preferences.includeFooter).segments(for: card),
                        current: workspace.speech.currentSegment
                    )
                }
            } header: {
                Text("Listen")
            } footer: {
                Text(
                    "Reads the card in the order and words a screen reader presents it, "
                        + "so you hear what a colleague who cannot see it will hear."
                )
                .sectionFooterStyle()
            }
            Section {
                Picker("Simulate", selection: $workspace.visionSimulation) {
                    ForEach(VisionSimulation.allCases) { simulation in
                        Text(simulation.label).tag(simulation)
                    }
                }
                .accessibilityIdentifier("inspector.visionSimulation")
            } header: {
                Text("Colour Vision")
            } footer: {
                Text(workspace.visionSimulation.detail + ". An approximation, for checking that nothing depends on colour alone.")
                    .sectionFooterStyle()
            }
            Section("Checks") {
                ForEach(AccessibilityRule.allCases, id: \.self) { rule in
                    let failed = failedRules.contains(rule)
                    LabeledContent {
                        Image(systemName: failed ? "xmark" : "checkmark")
                            .foregroundStyle(failed ? Color.red : Color.secondary)
                            .accessibilityHidden(true)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rule.title)
                            Text(rule.wcagReference).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(rule.title), \(failed ? "failed" : "passed"), \(rule.wcagReference)")
                }
            }
        }
        .formStyle(.grouped)
        // Pressing play shows the words as they are spoken; closing it again is the user's call.
        .onChange(of: workspace.speech.isSpeaking, initial: true) { _, isSpeaking in
            if isSpeaking {
                showTranscript = true
            }
        }
    }
}

/// What the listener hears, line by line. Gaps (an image nobody described) stand out.
struct SpokenTranscript: View {
    let segments: [SpokenSegment]
    let current: SpokenSegment?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(segments) { segment in
                let isCurrent = segment.id == current?.id
                // The line being spoken is marked by a glyph as well as by colour.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .opacity(isCurrent ? 1 : 0)
                        .accessibilityHidden(true)
                    Text(segment.text)
                        .font(.callout)
                        .fontWeight(segment.kind == .heading ? .semibold : .regular)
                        .foregroundStyle(segment.kind == .gap ? Color.red : (isCurrent ? Color.accentColor : Color.primary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 4)
        .textSelection(.enabled)
    }
}
