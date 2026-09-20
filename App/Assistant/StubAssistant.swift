import Foundation

/// A canned assistant for UI tests and screenshots (`-stubAssistant YES
/// -uiTesting`). It lets the whole "notes to card" flow run deterministically
/// with no model and no network. Its reply still goes through the real parser
/// and linter, so the flow under test is the production one.
struct StubAssistant: TextAssistant {
    var destination: String {
        "Canned reply (UI testing)"
    }

    var processesOnDevice: Bool {
        true
    }

    static let draftReply = """
    {
      "title": "Atlas weekly status",
      "subtitle": "Project Atlas · Week 38",
      "status": "at_risk",
      "summary": "The pilot is live in three of five regions. The launch date needs a decision by Wednesday.",
      "highlights": [
        "Pilot live with 3 of 5 regional teams",
        "Vendor lifted the API rate limit; integration tests are green again",
        "Accessibility audit: 14 of 16 findings closed"
      ],
      "metrics": [
        {"label": "Velocity", "value": "42", "change": "+5%"},
        {"label": "Open bugs", "value": "12", "change": "-3"},
        {"label": "Test coverage", "value": "81%", "change": "+2 pts"}
      ],
      "risks": [
        "Launch date undecided; steering group must decide by Wednesday or the marketing slot is lost",
        "Load test on staging has not been run yet"
      ],
      "next_steps": ["Run the load test on staging", "Close the last two audit findings", "Configure SSO for EMEA"]
    }
    """

    func complete(system _: String, user: String, expectsJSON: Bool) async throws -> String {
        try? await Task.sleep(for: .milliseconds(150))
        if expectsJSON {
            return Self.draftReply
        }
        // "Refine": keep structure, trim each line, so tests can see a change.
        return user.components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: " again", with: "").trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }
}
