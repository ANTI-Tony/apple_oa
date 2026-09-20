import Foundation
import Observation
import ReportCore

/// User-adjustable defaults, backed by `UserDefaults` and edited in Settings.
@MainActor
@Observable
final class UserPreferences {
    static let shared = UserPreferences()

    enum Keys {
        static let authorName = "authorName"
        static let defaultTheme = "defaultThemeID"
        static let defaultTemplate = "defaultTemplateID"
        static let exportScale = "exportScale"
        static let includeFooter = "includeFooter"
    }

    private let defaults: UserDefaults

    var authorName: String {
        didSet { defaults.set(authorName, forKey: Keys.authorName) }
    }

    var defaultThemeID: String {
        didSet { defaults.set(defaultThemeID, forKey: Keys.defaultTheme) }
    }

    var defaultTemplateID: String {
        didSet { defaults.set(defaultTemplateID, forKey: Keys.defaultTemplate) }
    }

    /// Pixel density of PNG exports: 1, 2 or 3.
    var exportScale: Int {
        didSet { defaults.set(exportScale, forKey: Keys.exportScale) }
    }

    var includeFooter: Bool {
        didSet { defaults.set(includeFooter, forKey: Keys.includeFooter) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        authorName = defaults.string(forKey: Keys.authorName) ?? ""
        defaultThemeID = defaults.string(forKey: Keys.defaultTheme) ?? CardTheme.light.id
        defaultTemplateID = defaults.string(forKey: Keys.defaultTemplate) ?? CardTemplate.weeklyStatus.id
        let scale = defaults.integer(forKey: Keys.exportScale)
        exportScale = (1 ... 3).contains(scale) ? scale : 2
        includeFooter = defaults.object(forKey: Keys.includeFooter) == nil ? true : defaults.bool(forKey: Keys.includeFooter)
    }

    var defaultTheme: CardTheme {
        CardTheme.builtIn(id: defaultThemeID) ?? .light
    }

    var defaultTemplate: CardTemplate {
        CardTemplate.builtIn(id: defaultTemplateID) ?? .weeklyStatus
    }

    var exportPreferences: ExportPreferences {
        ExportPreferences(scale: exportScale, includeFooter: includeFooter)
    }
}
