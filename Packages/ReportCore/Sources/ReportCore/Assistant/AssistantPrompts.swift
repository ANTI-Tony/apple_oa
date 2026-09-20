import Foundation

/// How a text block can be refined.
public enum RefineStyle: String, CaseIterable, Identifiable, Sendable {
    case concise
    case formal
    case grammar

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .concise: "Make Concise"
        case .formal: "More Formal"
        case .grammar: "Fix Grammar"
        }
    }

    var instruction: String {
        switch self {
        case .concise:
            "Rewrite the text to be as short as possible without losing any fact, number, name or date."
        case .formal:
            "Rewrite the text in a neutral, professional tone suitable for a status report to senior stakeholders. Do not add facts."
        case .grammar:
            "Correct spelling, grammar and punctuation only. Do not change wording that is already correct."
        }
    }
}

/// The exact prompts sent to a language model. They live in the core package
/// so they are reviewed and tested like any other behaviour, and so every
/// provider (on-device or remote) receives the same instructions.
public enum AssistantPrompts {

    // MARK: Drafting a card from notes

    public static let draftSystem = """
    You turn rough project notes (meeting minutes, chat logs, bullet dumps) into a structured project status report.

    Reply with a single JSON object and nothing else. Use this shape; omit any key you have no information for:
    {
      "title": "short report title, at most 60 characters",
      "subtitle": "project name and period, if stated",
      "status": "on_track | at_risk | off_track | completed | not_started",
      "summary": "one or two sentences",
      "highlights": ["what went well or was delivered"],
      "metrics": [{"label": "metric name", "value": "value as written, with its unit", "change": "+5% or -3, only if stated"}],
      "risks": ["risks, blockers, decisions needed"],
      "next_steps": ["planned work"]
    }

    Rules:
    - Use only facts, names, dates and numbers that appear in the notes. Never invent or estimate a number.
    - If the notes do not say how the project is doing, omit "status".
    - Each list item is one plain sentence under 140 characters, with no bullet character and no markdown.
    - At most 6 items per list and 6 metrics.
    - Write in the language of the notes.
    """

    public static func draftUser(notes: String) -> String {
        "Notes:\n\"\"\"\n\(notes.trimmingCharacters(in: .whitespacesAndNewlines))\n\"\"\""
    }

    // MARK: Refining text

    public static func refineSystem(_ style: RefineStyle) -> String {
        """
        You edit one section of a project status report. \(style.instruction)

        Rules:
        - Reply with the rewritten text only: no preface, no quotation marks, no markdown.
        - Keep the structure: a line that starts with "• " is a list item and must stay one; keep blank lines between paragraphs.
        - Keep every number, name and date exactly as written.
        - Write in the language of the text.
        """
    }

    public static func refineUser(text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips wrapping a model sometimes adds despite instructions: code
    /// fences and a single pair of surrounding quotes.
    public static func cleanedRefinement(_ reply: String) -> String {
        var text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            var lines = text.components(separatedBy: "\n")
            lines.removeFirst()
            if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
                lines.removeLast()
            }
            text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
        }
        return text
    }
}
