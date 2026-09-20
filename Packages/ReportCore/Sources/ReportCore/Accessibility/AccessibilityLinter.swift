import Foundation

/// One rule the linter evaluates. Each rule maps to a WCAG success criterion
/// so the UI can link users to the underlying requirement.
public enum AccessibilityRule: String, CaseIterable, Sendable {
    case cardHasTitle
    case imagesHaveAltText
    case altTextIsMeaningful
    case textContrast
    case secondaryTextContrast
    case accentContrast
    case statusContrast
    case metricsHaveLabels
    case blocksHaveContent
    case sectionsHaveHeadings
    case meaningNotByColorAlone
    case noImagesOfText
    case noLongRunsOfCapitals
    case sentencesAreReadable

    public var title: String {
        switch self {
        case .cardHasTitle: "Card has a title"
        case .imagesHaveAltText: "Images have text alternatives"
        case .altTextIsMeaningful: "Alt text is descriptive"
        case .textContrast: "Body text contrast is at least 4.5:1"
        case .secondaryTextContrast: "Secondary text contrast is at least 4.5:1"
        case .accentContrast: "Accent contrast is at least 3:1"
        case .statusContrast: "Status indicator contrast is at least 3:1"
        case .metricsHaveLabels: "Every metric has a label"
        case .blocksHaveContent: "No empty blocks"
        case .sectionsHaveHeadings: "Sections have headings to navigate by"
        case .meaningNotByColorAlone: "Text does not rely on colour words alone"
        case .noImagesOfText: "Images are not used in place of text"
        case .noLongRunsOfCapitals: "No long runs of capital letters"
        case .sentencesAreReadable: "Sentences are a readable length"
        }
    }

    public var wcagReference: String {
        switch self {
        case .cardHasTitle: "WCAG 2.4.6 Headings and Labels"
        case .imagesHaveAltText: "WCAG 1.1.1 Non-text Content"
        case .altTextIsMeaningful: "WCAG 1.1.1 Non-text Content"
        case .textContrast, .secondaryTextContrast: "WCAG 1.4.3 Contrast (Minimum)"
        case .accentContrast, .statusContrast: "WCAG 1.4.11 Non-text Contrast"
        case .metricsHaveLabels: "WCAG 1.3.1 Info and Relationships"
        case .blocksHaveContent: "Best practice"
        case .sectionsHaveHeadings: "WCAG 2.4.10 Section Headings"
        case .meaningNotByColorAlone: "WCAG 1.4.1 Use of Color"
        case .noImagesOfText: "WCAG 1.4.5 Images of Text"
        case .noLongRunsOfCapitals: "Best practice (readability, screen readers)"
        case .sentencesAreReadable: "WCAG 3.1.5 Reading Level"
        }
    }
}

/// A single finding.
public struct AccessibilityIssue: Identifiable, Hashable, Sendable {
    public enum Severity: Int, Comparable, Sendable {
        case info = 0
        case warning = 1
        case error = 2

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public var rule: AccessibilityRule
    public var severity: Severity
    public var message: String
    /// The offending block, when the issue is block-specific.
    public var blockID: UUID?

    public var id: String {
        "\(rule.rawValue)-\(blockID?.uuidString ?? "card")-\(message.hashValue)"
    }

    public init(rule: AccessibilityRule, severity: Severity, message: String, blockID: UUID? = nil) {
        self.rule = rule
        self.severity = severity
        self.message = message
        self.blockID = blockID
    }
}

/// The outcome of linting one card.
public struct AccessibilityReport: Hashable, Sendable {
    public var issues: [AccessibilityIssue]
    public var rulesEvaluated: Int

    public init(issues: [AccessibilityIssue], rulesEvaluated: Int) {
        self.issues = issues.sorted { $0.severity > $1.severity }
        self.rulesEvaluated = rulesEvaluated
    }

    public var errors: [AccessibilityIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [AccessibilityIssue] {
        issues.filter { $0.severity == .warning }
    }

    /// True when no error-level issue remains. Warnings do not block export.
    public var isCompliant: Bool {
        errors.isEmpty
    }

    public var summary: String {
        if issues.isEmpty {
            return "All \(rulesEvaluated) accessibility checks passed"
        }
        var parts: [String] = []
        if !errors.isEmpty {
            parts.append("\(errors.count) \(errors.count == 1 ? "error" : "errors")")
        }
        if !warnings.isEmpty {
            parts.append("\(warnings.count) \(warnings.count == 1 ? "warning" : "warnings")")
        }
        return parts.joined(separator: ", ")
    }
}

/// Evaluates a card against a fixed set of accessibility rules.
///
/// The linter is a product feature, not just a test helper: the editor shows
/// its findings live, and export buttons surface the compliance state, so
/// accessibility is enforced at the moment content is created rather than
/// audited after the fact.
public enum AccessibilityLinter {
    public static func lint(_ card: SnippetCard) -> AccessibilityReport {
        var issues: [AccessibilityIssue] = []
        issues += lintTitle(card)
        issues += lintTheme(card.theme)
        for block in card.blocks {
            issues += lint(block, theme: card.theme)
            issues += ContentChecks.lint(block)
        }
        issues += ContentChecks.lintHeadings(card)
        return AccessibilityReport(issues: issues, rulesEvaluated: AccessibilityRule.allCases.count)
    }

    // MARK: Rules

    private static func lintTitle(_ card: SnippetCard) -> [AccessibilityIssue] {
        guard card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let issue = AccessibilityIssue(
            rule: .cardHasTitle,
            severity: .error,
            message: "Add a title so the card has a heading to navigate to."
        )
        return [issue]
    }

    /// One foreground/background pair to verify against a minimum ratio.
    struct ContrastCheck {
        var rule: AccessibilityRule
        var severity: AccessibilityIssue.Severity
        var foreground: HexColor
        var background: HexColor
        var minimum: Double
        var subject: String
    }

    static func contrastChecks(for theme: CardTheme) -> [ContrastCheck] {
        var checks: [ContrastCheck] = [
            ContrastCheck(
                rule: .textContrast,
                severity: .error,
                foreground: theme.text,
                background: theme.background,
                minimum: ContrastLevel.aaNormalText,
                subject: "Body text on background"
            ),
            ContrastCheck(
                rule: .textContrast,
                severity: .error,
                foreground: theme.text,
                background: theme.surface,
                minimum: ContrastLevel.aaNormalText,
                subject: "Body text on tiles"
            ),
            ContrastCheck(
                rule: .secondaryTextContrast,
                severity: .warning,
                foreground: theme.secondaryText,
                background: theme.background,
                minimum: ContrastLevel.aaNormalText,
                subject: "Secondary text on background"
            ),
            ContrastCheck(
                rule: .secondaryTextContrast,
                severity: .warning,
                foreground: theme.secondaryText,
                background: theme.surface,
                minimum: ContrastLevel.aaNormalText,
                subject: "Secondary text on tiles"
            ),
            ContrastCheck(
                rule: .accentContrast,
                severity: .warning,
                foreground: theme.accent,
                background: theme.background,
                minimum: ContrastLevel.aaLargeText,
                subject: "Accent on background"
            ),
        ]
        for status in ReportStatus.allCases {
            checks.append(ContrastCheck(
                rule: .statusContrast,
                severity: .warning,
                foreground: theme.statusColor(for: status),
                background: theme.background,
                minimum: ContrastLevel.aaLargeText,
                subject: "\"\(status.label)\" status indicator"
            ))
        }
        for sentiment in MetricChange.Sentiment.allCases {
            checks.append(ContrastCheck(
                rule: .textContrast,
                severity: .warning,
                foreground: theme.changeColor(for: sentiment),
                background: theme.surface,
                minimum: ContrastLevel.aaNormalText,
                subject: "\(sentiment.label) change indicator on tiles"
            ))
        }
        return checks
    }

    static func lintTheme(_ theme: CardTheme) -> [AccessibilityIssue] {
        contrastChecks(for: theme).compactMap { check in
            let ratio = HexColor.contrastRatio(check.foreground, check.background)
            guard ratio < check.minimum else { return nil }
            return AccessibilityIssue(
                rule: check.rule, severity: check.severity,
                message: "\(check.subject) contrast is \(format(ratio)):1, below the \(format(check.minimum)):1 minimum."
            )
        }
    }

    private static func lint(_ block: Block, theme: CardTheme) -> [AccessibilityIssue] {
        switch block {
        case let .text(text):
            guard text.isEmpty else { return [] }
            let issue = AccessibilityIssue(
                rule: .blocksHaveContent,
                severity: .warning,
                message: "This text block is empty. Fill it in or remove it.",
                blockID: text.id
            )
            return [issue]

        case let .metrics(metrics):
            var issues: [AccessibilityIssue] = []
            if metrics.isEmpty {
                issues.append(AccessibilityIssue(
                    rule: .blocksHaveContent,
                    severity: .warning,
                    message: "This metrics block has no metrics.",
                    blockID: metrics.id
                ))
            }
            let unlabeled = metrics.metrics.filter { $0.label.trimmingCharacters(in: .whitespaces).isEmpty }
            if !unlabeled.isEmpty {
                let subject = unlabeled.count == 1 ? "1 metric has" : "\(unlabeled.count) metrics have"
                issues.append(AccessibilityIssue(
                    rule: .metricsHaveLabels, severity: .error,
                    message: "\(subject) no label, so the number has no meaning to a screen reader.",
                    blockID: metrics.id
                ))
            }
            return issues

        case let .image(image):
            var issues: [AccessibilityIssue] = []
            if !image.hasAcceptableAltText {
                issues.append(AccessibilityIssue(
                    rule: .imagesHaveAltText, severity: .error,
                    message: "Describe this image for people who cannot see it, or mark it decorative.",
                    blockID: image.id
                ))
            } else if !image.isDecorative {
                let alt = image.altText.trimmingCharacters(in: .whitespacesAndNewlines)
                if looksLikeFileName(alt) {
                    issues.append(AccessibilityIssue(
                        rule: .altTextIsMeaningful, severity: .warning,
                        message: "Alt text \"\(alt)\" looks like a file name. Describe what the image shows instead.",
                        blockID: image.id
                    ))
                } else if alt.count > 200 {
                    issues.append(AccessibilityIssue(
                        rule: .altTextIsMeaningful, severity: .warning,
                        message: "Alt text is \(alt.count) characters. Keep it under 200 and move detail into the caption.",
                        blockID: image.id
                    ))
                } else if ["image", "picture", "photo", "screenshot", "chart", "graph"].contains(alt.lowercased()) {
                    issues.append(AccessibilityIssue(
                        rule: .altTextIsMeaningful, severity: .warning,
                        message: "Alt text \"\(alt)\" only names the type of image. Say what it shows.",
                        blockID: image.id
                    ))
                }
            }
            return issues
        }
    }

    // MARK: Helpers

    static func looksLikeFileName(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let extensions = [".png", ".jpg", ".jpeg", ".gif", ".heic", ".tiff", ".bmp", ".webp"]
        if extensions.contains(where: { lowered.hasSuffix($0) }) {
            return true
        }
        let pattern = #"^(img|image|screenshot|screen shot|dsc|photo)[ _-]?[0-9]{2,}$"#
        return lowered.range(of: pattern, options: .regularExpression) != nil
    }

    private static func format(_ ratio: Double) -> String {
        String(format: "%.2f", ratio)
    }
}
