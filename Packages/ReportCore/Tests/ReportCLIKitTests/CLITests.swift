import Foundation
import ReportCore
import Testing
@testable import ReportCLIKit

/// Collects CLI output so tests can assert on it.
final class OutputSink: @unchecked Sendable {
    private(set) var lines: [String] = []

    func write(_ line: String) {
        lines.append(line)
    }

    var text: String {
        lines.joined(separator: "\n")
    }
}

@Suite("reportcard CLI")
struct CLITests {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeCLI() -> (CLI, OutputSink) {
        let sink = OutputSink()
        return (CLI(now: fixedDate, output: sink.write), sink)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reportcard-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("No arguments and help print usage")
    func usage() throws {
        let (cli, sink) = makeCLI()
        #expect(try cli.run([]) == 0)
        #expect(try cli.run(["help"]) == 0)
        #expect(sink.text.contains("USAGE"))
    }

    @Test("templates and themes list every built-in")
    func listings() throws {
        let (cli, sink) = makeCLI()
        #expect(try cli.run(["templates"]) == 0)
        #expect(sink.lines.count == CardTemplate.builtIn.count)
        #expect(sink.text.contains("weekly_status\tWeekly status"))
        let (themeCLI, themeSink) = makeCLI()
        #expect(try themeCLI.run(["themes"]) == 0)
        #expect(themeSink.lines.count == CardTheme.builtIn.count)
    }

    @Test("render writes each format to stdout")
    func renderFormats() throws {
        let expectations: [(format: String, marker: String)] = [
            ("html", "<!doctype html>"),
            ("email", "<article lang=\"en\""),
            ("markdown", "# Weekly status"),
            ("slack", "*Weekly status*"),
            ("text", "WEEKLY STATUS"),
            ("json", "\"schemaVersion\""),
        ]
        for expectation in expectations {
            let (cli, sink) = makeCLI()
            #expect(try cli.run(["render", "--template", "weekly_status", "--format", expectation.format]) == 0)
            #expect(sink.text.contains(expectation.marker), "\(expectation.format)")
        }
    }

    @Test("Dates in templates and footers follow --locale, English by default")
    func locale() throws {
        let (cli, sink) = makeCLI()
        #expect(try cli.run(["render", "--template", "weekly_status", "--format", "text"]) == 0)
        #expect(sink.text.contains("Week of Nov 1"), "fixed date is 14 or 15 Nov 2023 depending on the time zone")
        #expect(sink.text.contains("Updated Nov 1"))

        let (french, frenchSink) = makeCLI()
        #expect(try french.run(["render", "--template", "weekly_status", "--format", "text", "--locale", "fr_FR"]) == 0)
        #expect(frenchSink.text.contains("nov. 2023"))
    }

    @Test("render applies theme and author, and writes to a file")
    func renderToFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let out = directory.appendingPathComponent("nested/card.html").path
        let (cli, sink) = makeCLI()
        let code = try cli.run(["render", "--template", "risks", "--theme", "dark", "--author", "Alex Chen", "--out", out])
        #expect(code == 0)
        #expect(sink.text == "Wrote \(out)")
        let html = try String(contentsOfFile: out, encoding: .utf8)
        #expect(html.contains("background:#1D1D1F"))
        #expect(html.contains("· Alex Chen</p></footer>"))
    }

    @Test("render accepts a card exported by the app")
    func renderFromJSON() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("card.json")
        try CardCodec.encode(SnippetCard(title: "From JSON", blocks: [.text(TextBlock(body: "Hello"))])).write(to: input)
        let (cli, sink) = makeCLI()
        #expect(try cli.run(["render", "--input", input.path, "--format", "text"]) == 0)
        #expect(sink.text.hasPrefix("FROM JSON"))
    }

    @Test("lint passes templates and fails cards with accessibility errors")
    func lint() throws {
        let (cli, sink) = makeCLI()
        #expect(try cli.run(["lint", "--template", "weekly_status"]) == 0)
        #expect(sink.text.contains("accessibility checks passed"))

        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let png = try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="))
        let broken = SnippetCard(title: "No alt", blocks: [.image(ImageBlock(imageData: png, contentType: .png))])
        let input = directory.appendingPathComponent("broken.json")
        try CardCodec.encode(broken).write(to: input)
        let (failingCLI, failingSink) = makeCLI()
        #expect(try failingCLI.run(["lint", "--input", input.path]) == 1)
        #expect(failingSink.text.contains("error: Describe this image"))
        #expect(failingSink.text.contains("WCAG 1.1.1"))
    }

    @Test("--strict turns warnings into a failure")
    func lintStrict() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let card = SnippetCard(title: "Has an empty block", blocks: [.text(TextBlock())])
        let input = directory.appendingPathComponent("warn.json")
        try CardCodec.encode(card).write(to: input)
        let (cli, _) = makeCLI()
        #expect(try cli.run(["lint", "--input", input.path]) == 0)
        #expect(try cli.run(["lint", "--input", input.path, "--strict"]) == 1)
    }

    @Test("Bad input produces typed errors")
    func errors() {
        let (cli, _) = makeCLI()
        #expect(throws: CLIError.notFound("Template \"nope\"")) { try cli.run(["render", "--template", "nope"]) }
        #expect(throws: CLIError.notFound("Theme \"neon\"")) { try cli.run(["render", "--template", "risks", "--theme", "neon"]) }
        #expect(throws: CLIError.usage("Unknown format \"pdf\".")) { try cli.run(["render", "--template", "risks", "--format", "pdf"]) }
        #expect(throws: CLIError.usage("Unknown command \"deploy\".")) { try cli.run(["deploy"]) }
        #expect(throws: CLIError.usage("--out needs a value.")) { try cli.run(["site", "--out"]) }
        #expect(throws: CLIError.usage("Give --template <id> or --input <card.json>.")) { try cli.run(["lint"]) }
        #expect(throws: CLIError.notFound("File /definitely/missing.json")) { try cli.run(["lint", "--input", "/definitely/missing.json"]) }
    }

    @Test("site writes an accessible index plus every template in every theme")
    func site() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (cli, sink) = makeCLI()
        #expect(try cli.run(["site", "--out", directory.path, "--repo-url", "https://example.com/repo"]) == 0)

        let templates = CardTemplate.builtIn.filter { $0.id != CardTemplate.blank.id }
        let expectedFiles = 1 + templates.count * (CardTheme.builtIn.count + 2)
        #expect(sink.text == "Wrote \(expectedFiles) files to \(directory.path)")

        let index = try String(contentsOf: directory.appendingPathComponent("index.html"), encoding: .utf8)
        #expect(index.hasPrefix("<!doctype html>"))
        #expect(index.contains("<html lang=\"en\">"))
        #expect(index.contains("name=\"viewport\""))
        #expect(index.contains("class=\"skip\" href=\"#main\""))
        #expect(index.contains("https://example.com/repo"))
        #expect(index.components(separatedBy: "<h1").count - 1 == 1, "embedded cards must not add more h1 elements")
        for template in templates {
            #expect(index.contains("<h2 id=\"t-\(template.id)\">"))
            for theme in CardTheme.builtIn {
                let path = directory.appendingPathComponent("cards/\(template.id)-\(theme.id).html").path
                #expect(FileManager.default.fileExists(atPath: path))
            }
        }
        let json = try Data(contentsOf: directory.appendingPathComponent("cards/weekly_status.json"))
        #expect(try CardCodec.decodeCard(json).title == "Weekly status")
    }
}
