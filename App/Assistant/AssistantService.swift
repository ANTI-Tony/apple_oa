import Foundation
import ReportCore

/// The two things the app asks a model to do. Prompts and reply parsing live
/// in `ReportCore`; this type adds input limits and wires up the provider.
@MainActor
struct AssistantService {
    static let maxNotesLength = 12000
    static let maxRefineLength = 4000

    let settings: AssistantSettings

    /// Notes in, a validated and linted card out. The reply is never trusted:
    /// `CardDraftParser` bounds and sanitises every field.
    func draftCard(from notes: String, theme: CardTheme, author: String) async throws -> SnippetCard {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= Self.maxNotesLength else { throw AssistantError.inputTooLong(limit: Self.maxNotesLength) }
        let assistant = try settings.makeAssistant()
        let reply = try await assistant.complete(
            system: AssistantPrompts.draftSystem,
            user: AssistantPrompts.draftUser(notes: trimmed),
            expectsJSON: true
        )
        let draft = try CardDraftParser.parse(reply)
        return try CardDraftParser.makeCard(from: draft, theme: theme, author: author)
    }

    func refine(_ text: String, style: RefineStyle) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= Self.maxRefineLength else { throw AssistantError.inputTooLong(limit: Self.maxRefineLength) }
        let assistant = try settings.makeAssistant()
        let reply = try await assistant.complete(
            system: AssistantPrompts.refineSystem(style),
            user: AssistantPrompts.refineUser(text: trimmed),
            expectsJSON: false
        )
        let cleaned = AssistantPrompts.cleanedRefinement(reply)
        guard !cleaned.isEmpty else { throw AssistantError.emptyReply }
        return cleaned
    }
}
