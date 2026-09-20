import Foundation
import ReportCore
import Testing
@testable import ReportingBuilder

/// Records requests and replies with canned responses. No test touches the network.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let status: Int
    private let body: String

    init(status: Int = 200, body: String) {
        self.status = status
        self.body = body
    }

    var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { recorded.append(request) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (Data(body.utf8), response)
    }

    /// A successful chat-completions response carrying `content`.
    static func reply(_ content: String) -> StubHTTPClient {
        let payload: [String: Any] = ["choices": [["message": ["role": "assistant", "content": content]]]]
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        return StubHTTPClient(body: String(bytes: data, encoding: .utf8) ?? "{}")
    }
}

@MainActor
@Suite("Writing assistance")
struct AssistantTests {
    private func makeSettings(
        client: any HTTPClient,
        secrets: InMemorySecretStore = InMemorySecretStore()
    ) -> (AssistantSettings, UserDefaults, String) {
        let suite = "com.tonywen.reportingbuilder.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (AssistantSettings(defaults: defaults, secrets: secrets, client: client), defaults, suite)
    }

    @Test("Off by default, and nothing can be sent until it is switched on and configured")
    func offByDefault() throws {
        let (settings, defaults, suite) = makeSettings(client: StubHTTPClient.reply("hi"))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!settings.isEnabled)
        #expect(throws: AssistantError.featureDisabled) { try settings.makeAssistant() }

        settings.isEnabled = true
        settings.provider = .endpoint
        #expect(throws: AssistantError.notConfigured("add an API key in Settings.")) { try settings.makeAssistant() }

        try settings.setAPIKey("  sk-test  ")
        #expect(settings.hasAPIKey)
        let assistant = try settings.makeAssistant()
        #expect(assistant.destination == "api.deepseek.com")
        #expect(!assistant.processesOnDevice)
    }

    @Test("The key lives in the secret store, never in UserDefaults")
    func keyStorage() throws {
        let secrets = InMemorySecretStore()
        let (settings, defaults, suite) = makeSettings(client: StubHTTPClient.reply("hi"), secrets: secrets)
        defer { defaults.removePersistentDomain(forName: suite) }
        try settings.setAPIKey("sk-secret-value")
        #expect(secrets.read(AssistantSettings.apiKeyAccount) == "sk-secret-value")
        let persisted = defaults.persistentDomain(forName: suite) ?? [:]
        #expect(!persisted.values.contains { "\($0)".contains("sk-secret-value") })
        try settings.setAPIKey("")
        #expect(!settings.hasAPIKey)
        #expect(secrets.read(AssistantSettings.apiKeyAccount) == nil)
    }

    @Test("Plain HTTP and malformed endpoints are refused")
    func endpointValidation() throws {
        let (settings, defaults, suite) = makeSettings(client: StubHTTPClient.reply("hi"))
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.isEnabled = true
        settings.provider = .endpoint
        try settings.setAPIKey("sk-test")

        settings.baseURLString = "http://example.com"
        #expect(throws: AssistantError.notConfigured("the endpoint must use HTTPS.")) { try settings.makeAssistant() }
        settings.baseURLString = "not a url"
        #expect(throws: AssistantError.self) { try settings.makeAssistant() }
        settings.baseURLString = "http://localhost:11434/v1"
        #expect((try? settings.makeAssistant()) != nil, "a local model server is allowed over HTTP")
    }

    @Test("Consent is per host and asked again when the endpoint changes")
    func consent() {
        let (settings, defaults, suite) = makeSettings(client: StubHTTPClient.reply("hi"))
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.provider = .endpoint
        #expect(settings.needsRemoteConsent)
        settings.recordRemoteConsent()
        #expect(!settings.needsRemoteConsent)
        settings.baseURLString = "https://gateway.example.com/v1"
        #expect(settings.needsRemoteConsent)
        settings.provider = .onDevice
        #expect(!settings.needsRemoteConsent, "nothing leaves the Mac, so there is nothing to consent to")
    }

    @Test("The request follows the chat-completions shape and asks for JSON when needed")
    func requestShape() async throws {
        let client = StubHTTPClient.reply("{}")
        let assistant = try OpenAICompatibleAssistant(
            baseURL: #require(URL(string: "https://api.deepseek.com")), model: "deepseek-chat", apiKey: "sk-test", client: client
        )
        _ = try await assistant.complete(system: "SYS", user: "USER", expectsJSON: true)
        let request = try #require(client.requests.first)
        #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "deepseek-chat")
        #expect(json["stream"] as? Bool == false)
        #expect((json["response_format"] as? [String: String])?["type"] == "json_object")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["system", "user"])
        let bodyText = try #require(String(bytes: body, encoding: .utf8))
        #expect(!bodyText.contains("sk-test"), "the key travels in the header only")

        _ = try await assistant.complete(system: "SYS", user: "USER", expectsJSON: false)
        let plainBody = try #require(client.requests.last?.httpBody)
        let plain = try #require(try JSONSerialization.jsonObject(with: plainBody) as? [String: Any])
        #expect(plain["response_format"] == nil)
    }

    @Test("Provider errors and empty replies become readable errors")
    func errors() async throws {
        let failing = try OpenAICompatibleAssistant(
            baseURL: #require(URL(string: "https://api.deepseek.com")), model: "m", apiKey: "k",
            client: StubHTTPClient(status: 401, body: #"{"error":{"message":"Authentication Fails"}}"#)
        )
        await #expect(throws: AssistantError.server(status: 401, message: "Authentication Fails")) {
            try await failing.complete(system: "s", user: "u", expectsJSON: false)
        }
        let empty = try OpenAICompatibleAssistant(
            baseURL: #require(URL(string: "https://api.deepseek.com")), model: "m", apiKey: "k", client: StubHTTPClient.reply("   ")
        )
        await #expect(throws: AssistantError.emptyReply) {
            try await empty.complete(system: "s", user: "u", expectsJSON: false)
        }
    }

    @Test("Notes become a linted card; the reply is parsed, not trusted")
    func draft() async throws {
        let reply = """
        {"title":"Atlas weekly","status":"at_risk","highlights":["Pilot live in 3 regions"],
         "metrics":[{"label":"Open bugs","value":"12","change":"-3"}]}
        """
        let (settings, defaults, suite) = makeSettings(client: StubHTTPClient.reply("Sure!\n```json\n\(reply)\n```"))
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.isEnabled = true
        settings.provider = .endpoint
        try settings.setAPIKey("sk-test")

        let card = try await AssistantService(settings: settings).draftCard(from: "rough notes", theme: .paper, author: "Alex")
        #expect(card.title == "Atlas weekly")
        #expect(card.status == .atRisk)
        #expect(card.theme == .paper)
        #expect(card.author == "Alex")
        #expect(card.blocks.map(\.kind) == [.text, .metrics])
        #expect(AccessibilityLinter.lint(card).isCompliant)

        let long = String(repeating: "x", count: AssistantService.maxNotesLength + 1)
        await #expect(throws: AssistantError.inputTooLong(limit: AssistantService.maxNotesLength)) {
            try await AssistantService(settings: settings).draftCard(from: long, theme: .light, author: "")
        }
    }

    @Test("Refined text is unwrapped from fences")
    func refine() async throws {
        let (settings, defaults, suite) = makeSettings(client: StubHTTPClient.reply("```\n• Shorter\n• Tighter\n```"))
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.isEnabled = true
        settings.provider = .endpoint
        try settings.setAPIKey("sk-test")
        let refined = try await AssistantService(settings: settings).refine("• A much longer sentence\n• Another one", style: .concise)
        #expect(refined == "• Shorter\n• Tighter")
    }
}
