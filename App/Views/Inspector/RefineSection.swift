import ReportCore
import SwiftUI

/// Refine a text block with a language model. Opt-in; see ADR 0011.
struct RefineSection: View {
    @Binding var block: TextBlock
    @Binding var card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace
    @Environment(AssistantSettings.self) private var assistant
    @Environment(CardStore.self) private var store
    @Environment(\.undoManager) private var undoManager

    @State private var isWorking = false
    @State private var pendingStyle: RefineStyle?

    var body: some View {
        if assistant.isAvailableInThisBuild {
            Section {
                if assistant.isActive {
                    HStack {
                        ForEach(RefineStyle.allCases) { style in
                            Button(style.label) { request(style) }
                                .disabled(isWorking || block.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if isWorking {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .controlSize(.small)
                } else {
                    SettingsLink { Text("Set Up Writing Assistance…") }
                }
            } header: {
                Text("Refine")
            } footer: {
                Text(footer)
                    .sectionFooterStyle()
            }
            .confirmationDialog(
                "Send this text to \(assistant.endpointHost ?? "the endpoint")?",
                isPresented: Binding(get: { pendingStyle != nil && !isWorking }, set: {
                    if !$0 {
                        pendingStyle = nil
                    }
                }),
                titleVisibility: .visible
            ) {
                Button("Send") {
                    assistant.recordRemoteConsent()
                    if let style = pendingStyle {
                        run(style)
                    }
                }
                Button("Cancel", role: .cancel) { pendingStyle = nil }
            } message: {
                Text(RemoteProcessingNotice.text)
            }
        }
    }

    private var footer: String {
        let system = "With Apple Intelligence, Writing Tools are also in the context menu of any text on the card."
        guard assistant.isActive else { return "Off by default. " + system }
        let place = assistant.provider == .onDevice
            ? "Processed on this Mac."
            : "Sent to \(assistant.endpointHost ?? "your endpoint") when you press a button."
        return "\(place) ⌘Z undoes it. \(system)"
    }

    private func request(_ style: RefineStyle) {
        if assistant.needsRemoteConsent {
            pendingStyle = style
        } else {
            run(style)
        }
    }

    private func run(_ style: RefineStyle) {
        pendingStyle = nil
        isWorking = true
        let original = block.body
        let blockID = block.id
        Task {
            defer { isWorking = false }
            do {
                let refined = try await AssistantService(settings: assistant).refine(original, style: style)
                // Apply through the store so the rewrite is one undoable step.
                guard var updated = store.card(withID: card.id), let index = updated.index(ofBlock: blockID),
                      case var .text(text) = updated.blocks[index] else { return }
                text.body = EditableTextBlock.bulleted(refined)
                updated.blocks[index] = .text(text)
                store.update(updated, undoManager: undoManager, actionName: style.label)
                workspace.announce("Text refined. Press ⌘Z to undo.")
            } catch {
                workspace.announce(error.localizedDescription, isError: true)
            }
        }
    }
}

/// The disclosure shown before text first leaves the Mac for a given host.
enum RemoteProcessingNotice {
    static let text = """
    The text leaves this Mac and is processed by the provider you configured, under that provider's terms. \
    Do not send confidential or personal information. You will not be asked again for this endpoint.
    """
}
