import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// Apple's on-device language model (Foundation Models, macOS 26 or later with
/// Apple Intelligence). Nothing leaves the Mac, which is the right default for
/// project reports. On older systems this reports itself unavailable and the
/// app offers the configurable endpoint instead.
enum OnDeviceModel {
    /// nil when the model can be used, otherwise why not.
    static var unavailableReason: String? {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                switch SystemLanguageModel.default.availability {
                case .available:
                    return nil
                case let .unavailable(reason):
                    return "Apple Intelligence reports: \(reason)."
                }
            }
        #endif
        return "It needs macOS 26 or later with Apple Intelligence."
    }

    static var isAvailable: Bool {
        unavailableReason == nil
    }

    static func makeAssistant() throws -> any TextAssistant {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *), isAvailable {
                return OnDeviceAssistant()
            }
        #endif
        throw AssistantError.unavailable(unavailableReason ?? "Unknown reason.")
    }
}

#if canImport(FoundationModels)
    @available(macOS 26.0, *)
    struct OnDeviceAssistant: TextAssistant {
        var destination: String {
            "On this Mac"
        }

        var processesOnDevice: Bool {
            true
        }

        func complete(system: String, user: String, expectsJSON: Bool) async throws -> String {
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: user)
            let content = response.content
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AssistantError.emptyReply
            }
            return content
        }
    }
#endif
