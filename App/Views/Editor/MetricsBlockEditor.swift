import ReportCore
import SwiftUI

/// Heading plus one compact row per metric.
struct MetricsBlockEditor: View {
    @Binding var block: MetricsBlock
    @State private var showImport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Heading", text: $block.heading, prompt: Text("Heading"))
                .font(.headline)
                .textFieldStyle(.plain)
                .accessibilityLabel("Metrics heading")

            ForEach($block.metrics) { $metric in
                MetricRowEditor(metric: $metric) {
                    block.metrics.removeAll { $0.id == metric.id }
                }
            }

            HStack(spacing: 14) {
                Button { block.metrics.append(Metric(label: "", value: "")) } label: {
                    Label("Add Metric", systemImage: "plus")
                }
                Button { showImport = true } label: {
                    Label("Import Data…", systemImage: "tablecells")
                }
                .help("Paste CSV, spreadsheet cells, JSON or “Label: value” lines")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.top, 2)
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

/// One line: label, value, change. The change field understands "+5%", "-3",
/// "▲ 2 pts" or "0"; whether that is good or bad news is inferred from the
/// label and can be flipped with the arrow button.
struct MetricRowEditor: View {
    @Binding var metric: Metric
    let onDelete: () -> Void

    @State private var changeText = ""
    @State private var manualSentiment: MetricChange.Sentiment?
    @State private var isHovering = false
    @FocusState private var deleteFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Label", text: $metric.label, prompt: Text("Label"))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 96)
                .accessibilityLabel("Metric label")
            TextField("Value", text: $metric.value, prompt: Text("Value"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 88)
                .accessibilityLabel("Metric value")
            TextField("Change", text: $changeText, prompt: Text("+5%"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .accessibilityLabel("Change versus previous")
                .accessibilityHint("For example plus 5 percent or minus 3. Leave empty for none.")
            sentimentButton
                .frame(width: 18)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .focused($deleteFocused)
            .opacity(isHovering || deleteFocused ? 1 : 0)
            .accessibilityLabel("Remove metric \(metric.label)")
        }
        .onHover { isHovering = $0 }
        .onAppear { changeText = Self.displayText(for: metric.change) }
        .onChange(of: changeText) { _, text in applyChangeText(text) }
        .onChange(of: metric.label) { _, _ in refreshSentiment() }
        .onChange(of: metric.change) { _, change in syncText(with: change) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Metric \(metric.label.isEmpty ? "unnamed" : metric.label)")
    }

    @ViewBuilder
    private var sentimentButton: some View {
        if let change = metric.change {
            Button {
                let flipped = change.flippedSentiment
                manualSentiment = flipped.sentiment
                metric.change = flipped
            } label: {
                Text(change.direction.glyph)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Self.color(for: change.sentiment))
            }
            .buttonStyle(.borderless)
            .disabled(change.direction == .flat)
            .help("Shown as \(change.sentiment.label.lowercased()) news. Click to flip.")
            .accessibilityLabel("Change is \(change.sentiment.label.lowercased()) news")
            .accessibilityHint("Flips between good and bad news")
        } else {
            Color.clear
        }
    }

    // MARK: Change text <-> model

    static func displayText(for change: MetricChange?) -> String {
        guard let change else { return "" }
        switch change.direction {
        case .up: return "+\(change.text)"
        case .down: return "-\(change.text)"
        case .flat: return change.text.isEmpty ? "0" : change.text
        }
    }

    private static func color(for sentiment: MetricChange.Sentiment) -> Color {
        switch sentiment {
        case .positive: .green
        case .negative: .red
        case .neutral: .secondary
        }
    }

    private func sentiment(for direction: MetricChange.Direction) -> MetricChange.Sentiment {
        if direction != .flat, let manualSentiment {
            return manualSentiment
        }
        return SentimentHeuristics.sentiment(for: direction, label: metric.label)
    }

    private func applyChangeText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if metric.change != nil {
                metric.change = nil
            }
            manualSentiment = nil
            return
        }
        // Partial input such as "+" does not parse yet; keep what the model has.
        guard var parsed = MetricsParser.parseChange(trimmed) else { return }
        if parsed.direction != metric.change?.direction {
            manualSentiment = nil
        }
        parsed.sentiment = sentiment(for: parsed.direction)
        if parsed != metric.change {
            metric.change = parsed
        }
    }

    private func refreshSentiment() {
        guard manualSentiment == nil, var change = metric.change else { return }
        change.sentiment = sentiment(for: change.direction)
        if change != metric.change {
            metric.change = change
        }
    }

    /// Reflects model changes made elsewhere (import, undo) without fighting
    /// the user's typing: the text is replaced only when it no longer means
    /// the same thing as the model.
    private func syncText(with change: MetricChange?) {
        let typed = MetricsParser.parseChange(changeText.trimmingCharacters(in: .whitespaces))
        let sameMeaning = typed?.direction == change?.direction && typed?.text == change?.text
        if !sameMeaning {
            changeText = Self.displayText(for: change)
        }
    }
}
