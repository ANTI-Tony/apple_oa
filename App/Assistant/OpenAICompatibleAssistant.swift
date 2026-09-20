import Foundation

/// Talks to any endpoint that implements the OpenAI chat-completions shape:
/// an internal company gateway, a local server, or a public provider such as
/// DeepSeek (the default used to demonstrate this proof of concept).
///
/// The API key and the text are never logged. See ADR 0011 for why a remote
/// provider is acceptable for a demonstration and not for real business data.
struct OpenAICompatibleAssistant: TextAssistant {
    static let defaultBaseURL = "https://api.deepseek.com"
    static let defaultModel = "deepseek-chat"

    let baseURL: URL
    let model: String
    let apiKey: String
    let client: any HTTPClient

    var destination: String {
        baseURL.host() ?? baseURL.absoluteString
    }

    var processesOnDevice: Bool {
        false
    }

    func complete(system: String, user: String, expectsJSON: Bool) async throws -> String {
        let request = try makeRequest(system: system, user: user, expectsJSON: expectsJSON)
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.send(request)
        } catch let error as AssistantError {
            throw error
        } catch {
            throw AssistantError.network(error.localizedDescription)
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
                ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw AssistantError.server(status: response.statusCode, message: message)
        }
        guard let reply = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = reply.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AssistantError.emptyReply
        }
        return content
    }

    func makeRequest(system: String, user: String, expectsJSON: Bool) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body = ChatRequest(
            model: model,
            messages: [ChatMessage(role: "system", content: system), ChatMessage(role: "user", content: user)],
            temperature: 0.2,
            maxTokens: 1500,
            stream: false,
            responseFormat: expectsJSON ? ResponseFormat(type: "json_object") : nil
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        return request
    }

    // MARK: Wire format

    struct ChatMessage: Codable, Equatable {
        var role: String
        var content: String
    }

    struct ResponseFormat: Codable, Equatable {
        var type: String
    }

    struct ChatRequest: Codable, Equatable {
        var model: String
        var messages: [ChatMessage]
        var temperature: Double
        var maxTokens: Int
        var stream: Bool
        var responseFormat: ResponseFormat?
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            var message: ChatMessage
        }

        var choices: [Choice]
    }

    struct ErrorEnvelope: Decodable {
        struct Detail: Decodable {
            var message: String
        }

        var error: Detail
    }
}
