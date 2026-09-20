import ReportCore
import SwiftUI

/// Rough notes in, a structured and linted card out.
///
/// This is the brief's first sentence, "quickly assemble and structure project
/// progress", done with a language model. The reply is treated as untrusted
/// input: it is parsed, bounded and linted before the user sees it, and
/// nothing is added to the library until the user presses Create.
struct DraftFromNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CardStore.self) private var store
    @Environment(UserPreferences.self) private var preferences
    @Environment(AssistantSettings.self) private var assistant

    @State private var notes = ""
    @State private var draft: SnippetCard?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var isAskingConsent = false

    static let sampleNotes = """
    atlas sync thurs - notes (rough)
    pilot is live w/ 3 of the 5 regional teams now, EMEA + APAC still waiting on their SSO config
    vendor finally lifted the api rate limit on tues so integration tests are green again
    velocity 42 this sprint, was 40. open bugs down to 12 from 15. coverage 81% (79 last wk)
    a11y audit: 14 of 16 findings closed, last 2 need design input
    big open q: launch date. steering group has to decide by wed or we lose the marketing slot
    maria worried about load - nobody has run the load test on staging yet, plan is next week
    next: load test, close the 2 audit findings, SSO for EMEA
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Card from Notes").font(.title3.weight(.semibold))
            if assistant.isActive {
                editor
            } else {
                setup
            }
        }
        .padding(20)
        .frame(width: 880, height: 600)
        .onAppear {
            if LaunchOverrides.opensDraftDemo, notes.isEmpty {
                notes = Self.sampleNotes
                generate()
            }
        }
        .confirmationDialog(
            "Send these notes to \(assistant.endpointHost ?? "the endpoint")?",
            isPresented: $isAskingConsent,
            titleVisibility: .visible
        ) {
            Button("Send") {
                assistant.recordRemoteConsent()
                generate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(RemoteProcessingNotice.text)
        }
    }

    // MARK: Off state

    private var setup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writing assistance is off.")
                .font(.headline)
            Text("""
            It can turn meeting notes or a chat log into a structured card. It is off by default because it sends the text \
            you give it to a language model: Apple's on-device model where available, otherwise an endpoint you configure.
            """)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                SettingsLink { Text("Open Settings…") }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Spacer()
        }
    }

    // MARK: On state

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes").font(.headline)
                    TextEditor(text: $notes)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                        .accessibilityLabel("Notes")
                        .accessibilityIdentifier("draft.notes")
                    HStack {
                        Button("Use Sample Notes") { notes = Self.sampleNotes }
                            .buttonStyle(.link)
                        Spacer()
                        Text("\(notes.count) / \(AssistantService.maxNotesLength)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(notes.count > AssistantService.maxNotesLength ? Color.red : Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Card").font(.headline)
                    preview
                }
                .frame(width: 400)
            }
            Divider()
            HStack(spacing: 10) {
                Label(destination, systemImage: destinationSymbol)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .help("Where the notes are processed")
                Spacer()
                if isWorking {
                    ProgressView().controlSize(.small)
                }
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(draft == nil ? "Generate" : "Generate Again") { requestGeneration() }
                    .disabled(isWorking || notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("draft.generate")
                Button("Create Card") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft == nil || isWorking)
                    .accessibilityIdentifier("draft.create")
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let draft {
            let report = AccessibilityLinter.lint(draft)
            ScrollView {
                CardView(card: draft, width: 600, includeFooter: false)
                    .scaleEffect(0.62, anchor: .topLeading)
                    .frame(width: 600 * 0.62, height: nil, alignment: .topLeading)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
            Label(
                report.isCompliant ? report.summary : "Needs attention: \(report.summary)",
                systemImage: report.isCompliant ? "checkmark.shield" : "exclamationmark.shield.fill"
            )
            .font(.callout)
            .foregroundStyle(report.isCompliant ? Color.secondary : Color.red)
            Text("Check every number against your notes before sharing. A model can be wrong.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        } else {
            Text(
                "Paste meeting notes, a chat log or a list of facts. "
                    + "Generate turns them into a title, a status, highlights, metrics, risks and next steps."
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var destinationSymbol: String {
        if LaunchOverrides.usesStubAssistant {
            return "testtube.2"
        }
        return assistant.provider == .onDevice ? "lock.fill" : "network"
    }

    private var destination: String {
        if LaunchOverrides.usesStubAssistant {
            // Say what is true: under UI tests and screenshots nothing is sent anywhere.
            return "Canned reply for UI tests. Nothing is sent."
        }
        return assistant.provider == .onDevice ? "Processed on this Mac" : "Sent to \(assistant.endpointHost ?? "your endpoint")"
    }

    // MARK: Actions

    private func requestGeneration() {
        if assistant.needsRemoteConsent {
            isAskingConsent = true
        } else {
            generate()
        }
    }

    private func generate() {
        isWorking = true
        errorMessage = nil
        let text = notes
        Task {
            defer { isWorking = false }
            do {
                draft = try await AssistantService(settings: assistant)
                    .draftCard(from: text, theme: preferences.defaultTheme, author: preferences.authorName)
            } catch {
                draft = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func create() {
        guard let draft else { return }
        store.add(draft)
        dismiss()
    }
}
