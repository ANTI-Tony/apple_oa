import Foundation
import ReportCore

/// Errors reported to the user with exit code 2.
public enum CLIError: Error, Equatable, CustomStringConvertible {
    case usage(String)
    case notFound(String)
    case invalidInput(String)

    public var description: String {
        switch self {
        case let .usage(message): "\(message)\nRun `reportcard help` for usage."
        case let .notFound(what): "\(what) not found"
        case let .invalidInput(message): message
        }
    }
}

/// `reportcard`: the same renderers and accessibility linter as the macOS app,
/// without a window. Useful in automation (render a card from JSON), in CI
/// (fail a pipeline when a card is not accessible) and to publish the static
/// gallery.
public struct CLI {
    public static let usage = """
    reportcard: render and check Snippet Cards from the command line.

    USAGE
      reportcard templates
      reportcard themes
      reportcard render (--template <id> | --input <card.json>) [--theme <id>] [--author <name>]
                        [--format html|email|markdown|slack|text|json] [--locale <id>] [--out <file>]
      reportcard lint   (--template <id> | --input <card.json>) [--strict]
      reportcard site   --out <directory> [--repo-url <url>]
      reportcard help

    FORMATS
      html      standalone, responsive, accessible page (default)
      email     inline-styled <article> fragment for mail clients
      markdown  CommonMark with a GFM table
      slack     Slack mrkdwn
      text      plain text
      json      the card itself

    OPTIONS
      --locale  locale for dates in the output, e.g. en_AU (default en_US, so CI output is stable)

    EXIT CODES
      0 success · 1 lint found errors (or warnings with --strict) · 2 usage or I/O error
    """

    private let output: (String) -> Void
    private let now: Date

    public init(now: Date = Date(), output: @escaping (String) -> Void = { print($0) }) {
        self.now = now
        self.output = output
    }

    /// Runs one command. Returns the process exit code.
    public func run(_ arguments: [String]) throws -> Int32 {
        guard let command = arguments.first else {
            output(Self.usage)
            return 0
        }
        let options = try Options(Array(arguments.dropFirst()))
        switch command {
        case "help", "--help", "-h":
            output(Self.usage)
            return 0
        case "templates":
            for template in CardTemplate.builtIn {
                output("\(template.id)\t\(template.name): \(template.summary)")
            }
            return 0
        case "themes":
            for theme in CardTheme.builtIn {
                output("\(theme.id)\t\(theme.name)")
            }
            return 0
        case "render":
            return try render(options)
        case "lint":
            return try lint(options)
        case "site":
            return try site(options)
        default:
            throw CLIError.usage("Unknown command \"\(command)\".")
        }
    }

    // MARK: Commands

    private func render(_ options: Options) throws -> Int32 {
        let card = try loadCard(options)
        let locale = Self.locale(from: options)
        let format = options.value("format") ?? "html"
        let rendered: String
        switch format {
        case "html": rendered = HTMLRenderer(options: .init(mode: .standaloneDocument, locale: locale)).render(card)
        case "email": rendered = HTMLRenderer(options: .init(mode: .emailFragment, locale: locale)).render(card)
        case "markdown": rendered = MarkdownRenderer(flavor: .commonMark, locale: locale).render(card)
        case "slack": rendered = MarkdownRenderer(flavor: .slack, locale: locale).render(card)
        case "text": rendered = PlainTextRenderer(locale: locale).render(card)
        case "json":
            guard let json = try String(data: CardCodec.encode(card), encoding: .utf8) else {
                throw CLIError.invalidInput("The card could not be encoded.")
            }
            rendered = json
        default:
            throw CLIError.usage("Unknown format \"\(format)\".")
        }
        if let path = options.value("out") {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(rendered.utf8).write(to: url, options: .atomic)
            output("Wrote \(path)")
        } else {
            output(rendered)
        }
        return 0
    }

    private func lint(_ options: Options) throws -> Int32 {
        let card = try loadCard(options)
        let report = AccessibilityLinter.lint(card)
        output("\(card.title.isEmpty ? "Untitled" : card.title): \(report.summary)")
        for issue in report.issues {
            let level = issue.severity == .error ? "error" : "warning"
            output("  \(level): \(issue.message) [\(issue.rule.wcagReference)]")
        }
        if !report.isCompliant {
            return 1
        }
        if options.flag("strict"), !report.warnings.isEmpty {
            return 1
        }
        return 0
    }

    private func site(_ options: Options) throws -> Int32 {
        guard let path = options.value("out") else {
            throw CLIError.usage("site needs --out <directory>.")
        }
        let generator = SiteGenerator(
            generatedAt: now,
            repositoryURL: options.value("repo-url"),
            locale: Self.locale(from: options)
        )
        let files = try generator.generate(into: URL(fileURLWithPath: path, isDirectory: true))
        output("Wrote \(files.count) files to \(path)")
        return 0
    }

    // MARK: Helpers

    private static func locale(from options: Options) -> Locale {
        Locale(identifier: options.value("locale") ?? "en_US")
    }

    private func loadCard(_ options: Options) throws -> SnippetCard {
        var card: SnippetCard
        if let templateID = options.value("template") {
            guard let template = CardTemplate.builtIn(id: templateID) else {
                throw CLIError.notFound("Template \"\(templateID)\"")
            }
            card = template.makeCard(now: now, locale: Self.locale(from: options))
        } else if let path = options.value("input") {
            guard let data = FileManager.default.contents(atPath: path) else {
                throw CLIError.notFound("File \(path)")
            }
            do {
                card = try CardCodec.decodeCard(data)
            } catch {
                throw CLIError.invalidInput("\(path) is not a card: \(error.localizedDescription)")
            }
        } else {
            throw CLIError.usage("Give --template <id> or --input <card.json>.")
        }
        if let themeID = options.value("theme") {
            guard let theme = CardTheme.builtIn(id: themeID) else {
                throw CLIError.notFound("Theme \"\(themeID)\"")
            }
            card.theme = theme
        }
        if let author = options.value("author") {
            card.author = author
        }
        return card
    }
}

/// Minimal `--key value` / `--flag` parser. Kept dependency-free on purpose.
struct Options {
    private static let flags: Set<String> = ["strict"]
    private var values: [String: String] = [:]
    private var enabledFlags: Set<String> = []

    init(_ arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else {
                throw CLIError.usage("Unexpected argument \"\(argument)\".")
            }
            let key = String(argument.dropFirst(2))
            if Self.flags.contains(key) {
                enabledFlags.insert(key)
                index += 1
                continue
            }
            guard index + 1 < arguments.count else {
                throw CLIError.usage("--\(key) needs a value.")
            }
            values[key] = arguments[index + 1]
            index += 2
        }
    }

    func value(_ key: String) -> String? {
        values[key]
    }

    func flag(_ key: String) -> Bool {
        enabledFlags.contains(key)
    }
}
