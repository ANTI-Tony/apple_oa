import Foundation

/// A language model that turns a system instruction and a user message into
/// text. Two implementations exist: Apple's on-device model, and any
/// OpenAI-compatible HTTP endpoint (a company gateway, or a public provider
/// for demonstration). Everything above this protocol is provider-agnostic.
protocol TextAssistant: Sendable {
    /// Where the text is processed, for the disclosure shown to the user:
    /// "On this Mac", or the host name of the endpoint.
    var destination: String { get }
    /// True when nothing leaves the Mac.
    var processesOnDevice: Bool { get }

    func complete(system: String, user: String, expectsJSON: Bool) async throws -> String
}

enum AssistantError: LocalizedError, Equatable {
    case featureDisabled
    case notConfigured(String)
    case unavailable(String)
    case inputTooLong(limit: Int)
    case network(String)
    case server(status: Int, message: String)
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .featureDisabled: "Writing assistance is turned off. Turn it on in Settings."
        case let .notConfigured(what): "Writing assistance is not set up: \(what)"
        case let .unavailable(reason): "The on-device model is not available: \(reason)"
        case let .inputTooLong(limit): "That is too much text for one request. Keep it under \(limit) characters."
        case let .network(detail): "The request could not be sent: \(detail)"
        case let .server(status, message): "The provider replied with an error (\(status)): \(message)"
        case .emptyReply: "The model returned an empty reply."
        }
    }
}

/// The one network call the app can make, behind a protocol so tests never
/// touch the network.
protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Ephemeral session: no cookies, no cache, nothing about the request written to disk.
struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AssistantError.network("The server did not reply over HTTP.")
        }
        return (data, http)
    }
}
