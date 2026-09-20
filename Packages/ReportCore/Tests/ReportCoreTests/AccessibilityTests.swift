import Foundation
import Testing
@testable import ReportCore

@Suite("WCAG contrast")
struct ContrastTests {
    @Test("Known contrast ratios")
    func knownRatios() {
        #expect(abs(HexColor.contrastRatio(.black, .white) - 21) < 0.001)
        #expect(abs(HexColor.contrastRatio(.white, .white) - 1) < 0.001)
        let grey: HexColor = "#777777"
        #expect(abs(grey.contrastRatio(against: .white) - 4.48) < 0.01)
        #expect(abs(HexColor.contrastRatio("#0000FF", .white) - 8.59) < 0.01)
    }

    @Test("Hex parsing accepts short and long forms and round-trips")
    func hexParsing() {
        #expect(HexColor(hex: "#FFF") == .white)
        #expect(HexColor(hex: "000000") == .black)
        #expect(HexColor(hex: "#1D1D1F")?.hexString == "#1D1D1F")
        #expect(HexColor(hex: "#GGGGGG") == nil)
        #expect(HexColor(hex: "#12345") == nil)
    }
}

@Suite("AccessibilityLinter")
struct AccessibilityLinterTests {
    @Test("A well-formed card passes every rule")
    func cleanCard() {
        let report = AccessibilityLinter.lint(Fixtures.card())
        #expect(report.isCompliant)
        #expect(report.issues.isEmpty, "\(report.issues.map(\.message))")
        #expect(report.summary.hasPrefix("All "))
    }

    @Test("Every built-in theme meets AA contrast for all status pills and text roles")
    func builtInThemes() {
        for theme in CardTheme.builtIn {
            let issues = AccessibilityLinter.lintTheme(theme)
            #expect(issues.isEmpty, "\(theme.name): \(issues.map(\.message))")
        }
    }

    @Test("Every built-in template is compliant out of the box")
    func builtInTemplates() {
        for template in CardTemplate.builtIn {
            let report = AccessibilityLinter.lint(template.makeCard())
            #expect(report.isCompliant, "\(template.name): \(report.issues.map(\.message))")
        }
    }

    @Test("Missing alt text is an error, decorative images are allowed")
    func altText() {
        var card = Fixtures.card()
        card.blocks = [.image(Fixtures.image(alt: ""))]
        let report = AccessibilityLinter.lint(card)
        #expect(!report.isCompliant)
        #expect(report.errors.first?.rule == .imagesHaveAltText)
        #expect(report.errors.first?.blockID == card.blocks[0].id)

        card.blocks = [.image(Fixtures.image(alt: "", decorative: true))]
        #expect(AccessibilityLinter.lint(card).isCompliant)
    }

    @Test("File-name and generic alt text produce warnings, not errors")
    func weakAltText() {
        var card = Fixtures.card()
        card.blocks = [.image(Fixtures.image(alt: "IMG_2041.png")), .image(Fixtures.image(alt: "Screenshot"))]
        let report = AccessibilityLinter.lint(card)
        #expect(report.isCompliant)
        #expect(report.warnings.count == 2)
        #expect(report.warnings.allSatisfy { $0.rule == .altTextIsMeaningful })
    }

    @Test("Low contrast theme is flagged as an error")
    func lowContrast() {
        var theme = CardTheme.light
        theme.text = "#AAAAAA"
        var card = Fixtures.card()
        card.theme = theme
        let report = AccessibilityLinter.lint(card)
        #expect(report.errors.contains { $0.rule == .textContrast })
    }

    @Test("Missing title and unlabeled metrics are errors")
    func structure() {
        var card = Fixtures.card()
        card.title = "  "
        card.blocks = [.metrics(MetricsBlock(metrics: [Metric(label: "", value: "42")]))]
        let report = AccessibilityLinter.lint(card)
        #expect(report.errors.map(\.rule).sorted { $0.rawValue < $1.rawValue } == [.cardHasTitle, .metricsHaveLabels])
    }

    @Test("Issues are ordered errors first")
    func ordering() {
        var card = Fixtures.card()
        card.blocks = [.text(TextBlock()), .image(Fixtures.image(alt: ""))]
        let report = AccessibilityLinter.lint(card)
        #expect(report.issues.first?.severity == .error)
        #expect(report.issues.last?.severity == .warning)
        #expect(report.summary == "1 error, 1 warning")
    }
}
