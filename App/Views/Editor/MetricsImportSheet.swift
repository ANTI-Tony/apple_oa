import AppKit
import ReportCore
import SwiftUI
import UniformTypeIdentifiers

/// Paste or open tabular data, preview the parsed metrics, insert.
struct MetricsImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onInsert: (_ metrics: [Metric], _ replace: Bool) -> Void

    @State private var text = ""
    @State private var replaceExisting = false
    @State private var showFilePicker = false

    private var parsed: MetricsParseResult? {
        MetricsParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import metrics").font(.title3.weight(.semibold))
            Text("Paste CSV, cells copied from Numbers or Excel, JSON, or “Label: value” lines. "
                + "Add a “previous” column and the change is computed for you.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                .accessibilityLabel("Data to import")

            HStack {
                Button("Choose File…") { showFilePicker = true }
                Button("Use Clipboard") {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        text = clipboard
                    }
                }
                Spacer()
                Toggle("Replace existing metrics", isOn: $replaceExisting)
            }

            Group {
                if let parsed {
                    MetricsPreviewTable(metrics: parsed.metrics)
                        .frame(minHeight: 140)
                    HStack {
                        Text("\(parsed.metrics.count) metric\(parsed.metrics.count == 1 ? "" : "s") detected · \(parsed.format.rawValue)")
                        if !parsed.warnings.isEmpty {
                            Text("· \(parsed.warnings.joined(separator: " "))").foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Nothing recognisable yet. Try one metric per line, like “Velocity: 42”.", systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 140)
                } else {
                    Color.clear.frame(minHeight: 140)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Insert") {
                    onInsert(parsed?.metrics ?? [], replaceExisting)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsed == nil)
            }
        }
        .padding(20)
        .frame(width: 600, height: 600)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .json, .plainText]
        ) { result in
            if case let .success(url) = result, let contents = TextFileImport.read(url) {
                text = contents
            }
        }
    }
}

/// Compact read-only table used by the import and paste-review sheets.
struct MetricsPreviewTable: View {
    let metrics: [Metric]

    var body: some View {
        Table(metrics) {
            TableColumn("Metric") { Text($0.label) }
            TableColumn("Value") { Text($0.value) }
            TableColumn("Change") { metric in
                Text(metric.change?.display ?? "")
                    .accessibilityLabel(metric.change?.accessibleDescription ?? "No change recorded")
            }
        }
        .accessibilityLabel("Preview of \(metrics.count) metrics")
    }
}

/// Shown when Smart Paste detects tabular data, so the user confirms the
/// interpretation before anything is inserted.
struct PasteReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let payload: PastePayload
    let onInsert: ([Block]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch payload {
            case let .metrics(result, raw):
                Text("Looks like metric data").font(.title3.weight(.semibold))
                Text("\(result.metrics.count) metrics were detected. Insert them as a metrics block, or keep the original text.")
                    .foregroundStyle(.secondary)
                MetricsPreviewTable(metrics: result.metrics).frame(minHeight: 160)
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Insert as Text") {
                        onInsert([.text(TextBlock(body: raw))])
                        dismiss()
                    }
                    Button("Insert as Metrics") {
                        onInsert([.metrics(MetricsBlock(metrics: result.metrics))])
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            case let .text(text):
                Text("Insert text").font(.title3.weight(.semibold))
                ScrollView { Text(text).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 160)
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Insert") { onInsert([.text(TextBlock(body: text))])
                        dismiss()
                    }.keyboardShortcut(.defaultAction)
                }
            case let .image(block):
                Text("Insert image").font(.title3.weight(.semibold))
                if let image = NSImage(data: block.imageData) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                        .accessibilityLabel("Pasted image preview")
                }
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Insert") { onInsert([.image(block)])
                        dismiss()
                    }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
