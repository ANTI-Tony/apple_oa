import SwiftUI

/// The pages of the help window. Four, because a guide nobody finishes reading
/// is a guide nobody reads.
enum HelpTopic: String, CaseIterable, Identifiable {
    case shortcuts
    case accessibility
    case storage
    case about

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .shortcuts: "Keyboard Shortcuts"
        case .accessibility: "Accessibility Check"
        case .storage: "Where Your Cards Live"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .shortcuts: "command"
        case .accessibility: "checkmark.shield"
        case .storage: "internaldrive"
        case .about: "info.circle"
        }
    }
}

/// The few sentences in the help window that are written rather than read out
/// of the app. Kept here so they are easy to audit against the README, which
/// must not be duplicated: the README tells you whether to clone the project,
/// this tells you what to press once it is open.
enum HelpText {
    static let deleteFootnote = """
    ⌥⌘⌫ deletes the selected block. ⌘⌫ deletes the whole card. \
    Both can be undone with ⌘Z.
    """

    static let accessibilityIntro = """
    Every change you make is checked against fourteen rules, each mapped to a \
    WCAG success criterion. The shield in the toolbar is the verdict.
    """

    static let accessibilityRules = """
    The Accessibility tab lists the rules themselves, live, marked passed or \
    failed for the card you are looking at. Selecting a finding selects the \
    block it is about.
    """

    static let assistanceIntro = """
    Writing assistance is off until you turn it on in Settings. With it on and \
    pointed at an endpoint rather than Apple's on-device model:
    """

    static let storageIntro = """
    Cards are a file on this Mac. Nothing is uploaded: what this project \
    publishes is the app and a gallery of its built-in templates, never your cards.
    """
}

/// The two addresses the help menu offers. The gallery is the one artefact that
/// can be judged without building anything.
enum HelpLinks {
    static let gallery = URL(string: "https://anti-tony.github.io/apple_oa/")!
    static let repository = URL(string: "https://github.com/ANTI-Tony/apple_oa")!
}
