import Foundation

/// Build-time configuration surfaced at runtime.
///
/// Values originate in `Config/*.xcconfig`, flow into Info.plist through
/// `$(VARIABLE)` substitution (see `project.yml`) and are read here. Feature
/// flags therefore differ per build configuration without code changes.
enum AppConfiguration {
    enum Feature: String, CaseIterable {
        /// Vision-powered alt-text suggestions and metric extraction from images.
        case visionAssist = "VisionAssist"
        /// Seed demo cards on first launch.
        case sampleContent = "SampleContent"
        /// Shortcuts integration.
        case appIntents = "AppIntents"

        var label: String {
            switch self {
            case .visionAssist: "Vision assist"
            case .sampleContent: "Sample content"
            case .appIntents: "Shortcuts"
            }
        }
    }

    private static var info: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    static var version: String {
        info["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var build: String {
        info["CFBundleVersion"] as? String ?? "0"
    }

    static var buildFlavor: String {
        info["BuildFlavor"] as? String ?? "Unknown"
    }

    static func isEnabled(_ feature: Feature) -> Bool {
        let flags = info["FeatureFlags"] as? [String: Any] ?? [:]
        switch flags[feature.rawValue] {
        case let string as String: return ["YES", "TRUE", "1"].contains(string.uppercased())
        case let number as NSNumber: return number.boolValue
        default: return false
        }
    }

    static var enabledFeatures: [Feature] {
        Feature.allCases.filter(isEnabled)
    }
}
