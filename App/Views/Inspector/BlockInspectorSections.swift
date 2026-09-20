import ReportCore
import SwiftUI

/// Inspector sections for the metrics and image blocks.
struct MetricsInspectorSections: View {
    @Binding var block: MetricsBlock
    @State private var showImport = false

    var body: some View {
        Section("Layout") {
            Picker("Layout", selection: $block.layout) {
                ForEach(MetricsLayout.allCases, id: \.self) { layout in
                    Text(layout.label).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        Section {
            ForEach($block.metrics) { $metric in
                HStack {
                    Text(metric.label.isEmpty ? "Untitled" : metric.label)
                        .lineLimit(1)
                    Spacer()
                    if let change = metric.change, change.direction != .flat {
                        Picker("Reads as", selection: Binding(
                            get: { change.sentiment },
                            set: { metric.change?.sentiment = $0 }
                        )) {
                            Text("Good").tag(MetricChange.Sentiment.positive)
                            Text("Bad").tag(MetricChange.Sentiment.negative)
                            Text("Neutral").tag(MetricChange.Sentiment.neutral)
                        }
                        .labelsHidden()
                        .fixedSize()
                        .help("Whether this change is good or bad news. Guessed from the label.")
                    }
                    Button(role: .destructive) {
                        block.metrics.removeAll { $0.id == metric.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(metric.label.isEmpty ? "metric" : metric.label)")
                }
            }
            HStack {
                Button("Add Metric") { block.metrics.append(Metric(label: "", value: "")) }
                Spacer()
                Button("Import Data…") { showImport = true }
                    .help("Paste CSV, spreadsheet cells, JSON or “Label: value” lines")
            }
        } header: {
            Text("Metrics")
        } footer: {
            Text("Edit labels, values and changes on the card. A change can be typed as +5%, -3 or 0.")
                .sectionFooterStyle()
        }
        .sheet(isPresented: $showImport) {
            MetricsImportSheet { metrics, replace in
                if replace {
                    block.metrics = metrics
                } else {
                    block.metrics.append(contentsOf: metrics)
                }
            }
        }
    }
}

struct ImageInspectorSections: View {
    @Binding var block: ImageBlock
    let onInsertBlock: (Block) -> Void
    @Environment(WorkspaceState.self) private var workspace

    @State private var showReplace = false
    @State private var isWorking = false

    var body: some View {
        Section {
            TextField("Description", text: $block.altText, prompt: Text("What does the image show?"), axis: .vertical)
                .lineLimit(3 ... 8)
                .labelsHidden()
                .disabled(block.isDecorative)
                .accessibilityLabel("Image description")
                .accessibilityIdentifier("inspector.imageDescription")
            Toggle("Decorative", isOn: $block.isDecorative)
                .help("Decorative images carry no information, so screen readers skip them")
            if AppConfiguration.isEnabled(.visionAssist) {
                Button("Suggest Description") { suggestDescription() }
                    .disabled(isWorking || block.isDecorative)
            }
        } header: {
            Text("Description")
        } footer: {
            Text("Read aloud by VoiceOver and shown when the image cannot load. Say what matters, not “chart”.")
                .sectionFooterStyle()
        }
        Section("Image") {
            HStack {
                Button("Replace…") { showReplace = true }
                if AppConfiguration.isEnabled(.visionAssist) {
                    Button("Extract Metrics") { extractMetrics() }
                        .disabled(isWorking)
                        .help("Read numbers from a screenshot into a new metrics block")
                }
                if isWorking {
                    ProgressView().controlSize(.small)
                }
            }
            if let size = block.pixelSize {
                LabeledContent("Size", value: "\(size.width) × \(size.height)")
            }
        }
        .fileImporter(isPresented: $showReplace, allowedContentTypes: [.image]) { result in
            guard case let .success(url) = result, let replacement = ImageImport.imageBlock(from: url) else { return }
            block.imageData = replacement.imageData
            block.contentType = replacement.contentType
            block.pixelSize = replacement.pixelSize
            block.fileName = replacement.fileName
        }
    }

    private func suggestDescription() {
        isWorking = true
        let data = block.imageData
        Task {
            defer { isWorking = false }
            if let suggestion = await VisionServices.suggestAltText(for: data) {
                block.altText = suggestion
                workspace.announce("Description suggested. Edit it so it says what matters.")
            } else {
                workspace.announce("No suggestion available for this image", isError: true)
            }
        }
    }

    private func extractMetrics() {
        isWorking = true
        let data = block.imageData
        Task {
            defer { isWorking = false }
            do {
                if let result = try await VisionServices.extractMetrics(from: data), !result.metrics.isEmpty {
                    onInsertBlock(.metrics(MetricsBlock(heading: "From image", metrics: result.metrics)))
                    workspace.announce("Extracted \(result.metrics.count) metric\(result.metrics.count == 1 ? "" : "s"). Check the values.")
                } else {
                    workspace.announce("No labelled numbers were recognised", isError: true)
                }
            } catch {
                workspace.announce("Text recognition failed: \(error.localizedDescription)", isError: true)
            }
        }
    }
}
