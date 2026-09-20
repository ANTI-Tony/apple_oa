import Foundation
import Observation

enum AssistantProvider: String, CaseIterable, Identifiable {
    /// Apple's on-device model. Nothing leaves the Mac.
    case onDevice
    /// An OpenAI-compatible endpoint the user configures.
    case endpoint

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .onDevice: "On This Mac (Apple Intelligence)"
        case .endpoint: "Custom Endpoint"
        }
    }
}

/// Writing assistance is opt-in. It is off until the user turns it on, and a
/// remote endpoint additionally needs a one-time, per-host consent before any
/// text is sent to it.
@MainActor
@Observable
final class AssistantSettings {
    static let shared = AssistantSettings()
    static let apiKeyAccount = "endpoint-api-key"

    private enum Keys {
        static let isEnabled = "assistant.isEnabled"
        static let provider = "assistant.provider"
        static let baseURL = "assistant.baseURL"
        static let model = "assistant.model"
        static let consentedHost = "assistant.consentedHost"
    }

    private let defaults: UserDefaults
    private let secrets: any SecretStore
    private let client: any HTTPClient

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    var provider: AssistantProvider {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }

    var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Keys.baseURL) }
    }

    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    /// The host the user agreed to send text to. Changing the endpoint asks again.
    private(set) var consentedHost: String? {
        didSet { defaults.set(consentedHost, forKey: Keys.consentedHost) }
    }

    private(set) var hasAPIKey: Bool

    init(
        defaults: UserDefaults = .standard,
        secrets: any SecretStore = KeychainSecretStore(),
        client: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.defaults = defaults
        self.secrets = secrets
        self.client = client
        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        let storedProvider = defaults.string(forKey: Keys.provider).flatMap(AssistantProvider.init(rawValue:))
        provider = storedProvider ?? (OnDeviceModel.isAvailable ? .onDevice : .endpoint)
        baseURLString = defaults.string(forKey: Keys.baseURL) ?? OpenAICompatibleAssistant.defaultBaseURL
        model = defaults.string(forKey: Keys.model) ?? OpenAICompatibleAssistant.defaultModel
        consentedHost = defaults.string(forKey: Keys.consentedHost)
        hasAPIKey = secrets.read(Self.apiKeyAccount) != nil
    }

    /// The feature flag can remove the feature from a build entirely.
    var isAvailableInThisBuild: Bool {
        AppConfiguration.isEnabled(.writingAssistance)
    }

    var isActive: Bool {
        isAvailableInThisBuild && (isEnabled || LaunchOverrides.usesStubAssistant)
    }

    var endpointHost: String? {
        URL(string: baseURLString)?.host()
    }

    /// True when text would leave the Mac and the user has not yet agreed to
    /// send it to this particular host.
    var needsRemoteConsent: Bool {
        !LaunchOverrides.usesStubAssistant && provider == .endpoint && consentedHost != endpointHost
    }

    func recordRemoteConsent() {
        consentedHost = endpointHost
    }

    func setAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            secrets.delete(Self.apiKeyAccount)
            hasAPIKey = false
        } else {
            try secrets.write(trimmed, for: Self.apiKeyAccount)
            hasAPIKey = true
        }
    }

    /// Builds the assistant for the current settings, or says what is missing.
    func makeAssistant() throws -> any TextAssistant {
        guard isActive else { throw AssistantError.featureDisabled }
        if LaunchOverrides.usesStubAssistant {
            return StubAssistant()
        }
        switch provider {
        case .onDevice:
            return try OnDeviceModel.makeAssistant()
        case .endpoint:
            guard let url = URL(string: baseURLString), let scheme = url.scheme, url.host() != nil else {
                throw AssistantError.notConfigured("the endpoint address is not a valid URL.")
            }
            guard scheme == "https" || url.host() == "localhost" || url.host() == "127.0.0.1" else {
                throw AssistantError.notConfigured("the endpoint must use HTTPS.")
            }
            guard let key = secrets.read(Self.apiKeyAccount), !key.isEmpty else {
                throw AssistantError.notConfigured("add an API key in Settings.")
            }
            let modelName = model.trimmingCharacters(in: .whitespaces)
            guard !modelName.isEmpty else { throw AssistantError.notConfigured("enter a model name.") }
            return OpenAICompatibleAssistant(baseURL: url, model: modelName, apiKey: key, client: client)
        }
    }
}
