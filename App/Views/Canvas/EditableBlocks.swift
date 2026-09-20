import AppKit
import ReportCore
import SwiftUI

/// One block on the canvas: its editable content, a quiet selection outline,
/// and the context menu. Arrange and delete are also in the Format inspector
/// and the Card menu, so nothing depends on the pointer.
struct EditableBlockView: View {
    @Binding var block: Block
    let theme: CardTheme
    let isSelected: Bool
    /// True while "Hear This Card" is reading this block.
    var isBeingSpoken = false
    var focus: FocusState<CanvasFocus?>.Binding
    let actions: BlockActions
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.accent.color.opacity(isBeingSpoken ? 0.10 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        theme.accent.color.opacity(isSelected ? (contrast == .increased ? 1 : 0.55) : 0),
                        lineWidth: contrast == .increased ? 2.5 : 1.5
                    )
            )
            .padding(-8)
            .contentShape(Rectangle())
            .onTapGesture(perform: actions.select)
            .contextMenu {
                Button("Move Up", action: actions.moveUp).disabled(!actions.canMoveUp)
                Button("Move Down", action: actions.moveDown).disabled(!actions.canMoveDown)
                Button("Format…", action: actions.showInspector)
                Divider()
                Button("Delete", role: .destructive, action: actions.delete)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(block.kind.label) block\(isSelected ? ", selected" : "")")
            // VoiceOver's Actions rotor: arrange and delete without hunting for a button.
            .accessibilityAction(named: "Move Up") {
                if actions.canMoveUp {
                    actions.moveUp()
                }
            }
            .accessibilityAction(named: "Move Down") {
                if actions.canMoveDown {
                    actions.moveDown()
                }
            }
            .accessibilityAction(named: "Format") { actions.select()
                actions.showInspector()
            }
            .accessibilityAction(named: "Delete") { actions.delete() }
    }

    @ViewBuilder
    private var content: some View {
        switch block {
        case .text:
            if let binding = $block.textBlock {
                EditableTextBlock(block: binding, theme: theme, isSelected: isSelected, focus: focus)
            }
        case .metrics:
            if let binding = $block.metricsBlock {
                EditableMetricsBlock(block: binding, theme: theme, isSelected: isSelected, focus: focus)
            }
        case .image:
            if let binding = $block.imageBlock {
                EditableImageBlock(block: binding, theme: theme, isSelected: isSelected, focus: focus, actions: actions)
            }
        }
    }
}

// MARK: - Text

struct EditableTextBlock: View {
    @Environment(\.cardTypography) private var typography
    @Binding var block: TextBlock
    let theme: CardTheme
    let isSelected: Bool
    var focus: FocusState<CanvasFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !block.heading.isEmpty || isSelected {
                TextField("Heading", text: $block.heading)
                    .textFieldStyle(.plain)
                    .font(typography.heading)
                    .frame(height: typography.fieldHeight(15))
                    .foregroundStyle(theme.text.color)
                    .focused(focus, equals: .field(block: block.id, slot: "heading"))
                    .accessibilityLabel("Heading")
            }
            TextField("Write something. Start a line with “- ” for a bullet.", text: bulletedBody, axis: .vertical)
                .textFieldStyle(.plain)
                .font(typography.body)
                .lineSpacing(CardStyle.bodyLineSpacing)
                .foregroundStyle(theme.text.color)
                .focused(focus, equals: .field(block: block.id, slot: "body"))
                .accessibilityLabel("Text")
        }
    }

    /// Typing "- " or "* " at the start of a line turns into a real bullet, the
    /// way Notes does it. `ReportCore` reads "• " as a list item, so every
    /// export gets a proper list.
    private var bulletedBody: Binding<String> {
        Binding(
            get: { Self.bulleted(block.body) },
            set: { block.body = Self.bulleted($0) }
        )
    }

    /// Pure text transformation, so it is callable from any thread (views are
    /// otherwise main-actor isolated).
    nonisolated static func bulleted(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in
                for prefix in ["- ", "* "] where line.hasPrefix(prefix) {
                    return "• " + line.dropFirst(prefix.count)
                }
                return line
            }
            .joined(separator: "\n")
    }
}

// MARK: - Metrics

struct EditableMetricsBlock: View {
    @Environment(\.cardTypography) private var typography
    @Binding var block: MetricsBlock
    let theme: CardTheme
    let isSelected: Bool
    var focus: FocusState<CanvasFocus?>.Binding

    private var hasChange: Bool {
        block.metrics.contains { $0.change != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !block.heading.isEmpty || isSelected {
                TextField("Heading", text: $block.heading)
                    .textFieldStyle(.plain)
                    .font(typography.heading)
                    .frame(height: typography.fieldHeight(15))
                    .foregroundStyle(theme.text.color)
                    .focused(focus, equals: .field(block: block.id, slot: "heading"))
                    .accessibilityLabel("Heading")
            }
            if block.metrics.isEmpty {
                Text("No metrics yet. Add one in the Format inspector, or import a table.")
                    .font(typography.body)
                    .foregroundStyle(theme.secondaryText.color)
            } else {
                switch block.layout {
                case .tiles:
                    MetricsGroup(count: block.metrics.count, theme: theme) { index in
                        EditableMetricTile(metric: $block.metrics[index], blockID: block.id, theme: theme, focus: focus) {
                            removeMetric(at: index)
                        }
                    }
                case .table:
                    VStack(spacing: 0) {
                        ForEach(block.metrics.indices, id: \.self) { index in
                            EditableMetricRow(
                                metric: $block.metrics[index],
                                blockID: block.id,
                                theme: theme,
                                showsChange: hasChange || isSelected,
                                focus: focus
                            ) {
                                removeMetric(at: index)
                            }
                            Rectangle().fill(theme.border.color).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func removeMetric(at index: Int) {
        guard block.metrics.indices.contains(index) else { return }
        block.metrics.remove(at: index)
    }
}

/// Keeps the text the user types for a change ("+5%", "-3", "▲ 2 pts") in step
/// with the model, without rewriting it under the caret.
@MainActor
struct ChangeTextSync {
    static func display(_ change: MetricChange?) -> String {
        change?.display ?? ""
    }

    /// Applies typed text to the metric. Unparseable partial input ("+") is
    /// left alone so typing is never interrupted.
    static func apply(_ text: String, to metric: inout Metric) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if metric.change != nil {
                metric.change = nil
            }
            return
        }
        guard var parsed = MetricsParser.parseChange(trimmed) else { return }
        if let existing = metric.change, existing.direction == parsed.direction, existing.sentiment != .neutral {
            // Keep a sentiment the user set by hand in the inspector.
            parsed.sentiment = existing.sentiment
        } else {
            parsed.sentiment = SentimentHeuristics.sentiment(for: parsed.direction, label: metric.label)
        }
        if parsed != metric.change {
            metric.change = parsed
        }
    }
}

struct EditableMetricTile: View {
    @Environment(\.cardTypography) private var typography
    @Binding var metric: Metric
    let blockID: UUID
    let theme: CardTheme
    var focus: FocusState<CanvasFocus?>.Binding
    let onRemove: () -> Void

    @State private var changeText = ""

    private var changeSlot: CanvasFocus {
        .field(block: blockID, slot: "change-\(metric.id)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField("Label", text: $metric.label)
                .textFieldStyle(.plain)
                .font(typography.metricLabel)
                .frame(height: typography.fieldHeight(12))
                .foregroundStyle(theme.secondaryText.color)
                .focused(focus, equals: .field(block: blockID, slot: "label-\(metric.id)"))
                .accessibilityLabel("Metric label")
            TextField("0", text: $metric.value)
                .textFieldStyle(.plain)
                .font(typography.metricValue)
                .frame(height: typography.fieldHeight(28))
                .foregroundStyle(theme.text.color)
                .focused(focus, equals: .field(block: blockID, slot: "value-\(metric.id)"))
                .accessibilityLabel("Value of \(metric.label)")
            HStack(spacing: 6) {
                TextField("+0%", text: $changeText)
                    .textFieldStyle(.plain)
                    .font(typography.metricChange)
                    .frame(height: typography.fieldHeight(12))
                    .foregroundStyle(metric.trendColor(in: theme))
                    .focused(focus, equals: changeSlot)
                    .accessibilityLabel("Change of \(metric.label)")
                    .accessibilityHint("For example plus 5 percent or minus 3. Leave empty for none.")
                if metric.trend.count >= 2 {
                    Sparkline(values: metric.trend, color: metric.trendColor(in: theme))
                        .frame(width: 52, height: 16)
                }
            }
            .frame(minHeight: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .trendAudioGraph(for: metric)
        .onAppear { changeText = ChangeTextSync.display(metric.change) }
        .onChange(of: changeText) { _, text in ChangeTextSync.apply(text, to: &metric) }
        .onChange(of: focus.wrappedValue) { _, newFocus in
            // Tidy "+5%" into "▲ 5%" once the caret leaves the field.
            if newFocus != changeSlot {
                changeText = ChangeTextSync.display(metric.change)
            }
        }
        .onChange(of: metric.change) { _, change in
            if focus.wrappedValue != changeSlot {
                changeText = ChangeTextSync.display(change)
            }
        }
        .contextMenu {
            MetricSentimentMenu(metric: $metric)
            Divider()
            Button("Remove Metric", role: .destructive, action: onRemove)
        }
    }
}

struct EditableMetricRow: View {
    @Environment(\.cardTypography) private var typography
    @Binding var metric: Metric
    let blockID: UUID
    let theme: CardTheme
    let showsChange: Bool
    var focus: FocusState<CanvasFocus?>.Binding
    let onRemove: () -> Void

    @State private var changeText = ""

    private var changeSlot: CanvasFocus {
        .field(block: blockID, slot: "change-\(metric.id)")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            TextField("Label", text: $metric.label)
                .textFieldStyle(.plain)
                .font(typography.body)
                .frame(height: typography.fieldHeight(15))
                .focused(focus, equals: .field(block: blockID, slot: "label-\(metric.id)"))
                .accessibilityLabel("Metric label")
            TextField("0", text: $metric.value)
                .textFieldStyle(.plain)
                .font(typography.tableValue)
                .frame(height: typography.fieldHeight(15))
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
                .focused(focus, equals: .field(block: blockID, slot: "value-\(metric.id)"))
                .accessibilityLabel("Value of \(metric.label)")
            if showsChange {
                TextField("+0%", text: $changeText)
                    .textFieldStyle(.plain)
                    .font(typography.tableChange)
                    .frame(height: typography.fieldHeight(13))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(metric.trendColor(in: theme))
                    .frame(width: 84)
                    .focused(focus, equals: changeSlot)
                    .accessibilityLabel("Change of \(metric.label)")
            }
        }
        .foregroundStyle(theme.text.color)
        .padding(.vertical, 9)
        .onAppear { changeText = ChangeTextSync.display(metric.change) }
        .onChange(of: changeText) { _, text in ChangeTextSync.apply(text, to: &metric) }
        .onChange(of: focus.wrappedValue) { _, newFocus in
            if newFocus != changeSlot {
                changeText = ChangeTextSync.display(metric.change)
            }
        }
        .onChange(of: metric.change) { _, change in
            if focus.wrappedValue != changeSlot {
                changeText = ChangeTextSync.display(change)
            }
        }
        .contextMenu {
            MetricSentimentMenu(metric: $metric)
            Divider()
            Button("Remove Metric", role: .destructive, action: onRemove)
        }
    }
}

/// "Open bugs ▼" is good news; "Velocity ▼" is not. The parser guesses from the
/// label and this menu overrides the guess.
struct MetricSentimentMenu: View {
    @Binding var metric: Metric

    var body: some View {
        if let change = metric.change, change.direction != .flat {
            Picker("This Change Is", selection: Binding(
                get: { change.sentiment },
                set: { metric.change?.sentiment = $0 }
            )) {
                Text("Good News").tag(MetricChange.Sentiment.positive)
                Text("Bad News").tag(MetricChange.Sentiment.negative)
                Text("Neutral").tag(MetricChange.Sentiment.neutral)
            }
            .pickerStyle(.inline)
        }
    }
}

// MARK: - Image

struct EditableImageBlock: View {
    @Environment(\.cardTypography) private var typography
    @Binding var block: ImageBlock
    let theme: CardTheme
    let isSelected: Bool
    var focus: FocusState<CanvasFocus?>.Binding
    let actions: BlockActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = ImageCache.shared.image(for: block) {
                let shape = RoundedRectangle(cornerRadius: CardStyle.imageCornerRadius, style: .continuous)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(theme.border.color, lineWidth: 1))
                    .accessibilityLabel(block
                        .isDecorative ? "Decorative image" : (block.altText.isEmpty ? "Image without a description" : block.altText))
            }
            if !block.hasAcceptableAltText {
                // The one place the canvas nags: an image nobody described. It sits under the
                // picture rather than on it, so it never hides part of a chart, and its words
                // are in the label colour because white on orange fails contrast.
                Button {
                    actions.select()
                    actions.showInspector()
                } label: {
                    Label {
                        Text("Add Description")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Describe this image for people who cannot see it")
                .accessibilityIdentifier("canvas.addDescription")
            }
            if !block.caption.isEmpty || isSelected {
                TextField("Caption", text: $block.caption)
                    .textFieldStyle(.plain)
                    .font(typography.caption)
                    .frame(height: typography.fieldHeight(12))
                    .foregroundStyle(theme.secondaryText.color)
                    .focused(focus, equals: .field(block: block.id, slot: "caption"))
                    .accessibilityLabel("Caption")
            }
        }
    }
}

// MARK: - Binding projections

/// Projects a `Binding<Block>` onto the payload of one case.
extension Binding where Value == Block {
    var textBlock: Binding<TextBlock>? {
        guard case let .text(initial) = wrappedValue else { return nil }
        return Binding<TextBlock>(
            get: {
                if case let .text(block) = wrappedValue {
                    block
                } else {
                    initial
                }
            },
            set: { wrappedValue = .text($0) }
        )
    }

    var metricsBlock: Binding<MetricsBlock>? {
        guard case let .metrics(initial) = wrappedValue else { return nil }
        return Binding<MetricsBlock>(
            get: {
                if case let .metrics(block) = wrappedValue {
                    block
                } else {
                    initial
                }
            },
            set: { wrappedValue = .metrics($0) }
        )
    }

    var imageBlock: Binding<ImageBlock>? {
        guard case let .image(initial) = wrappedValue else { return nil }
        return Binding<ImageBlock>(
            get: {
                if case let .image(block) = wrappedValue {
                    block
                } else {
                    initial
                }
            },
            set: { wrappedValue = .image($0) }
        )
    }
}
