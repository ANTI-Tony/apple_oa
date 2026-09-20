import ReportCore
import SwiftUI

/// The Format inspector, in the manner of Pages and Keynote: properties of the
/// card, of the selected block, and the accessibility check. Everything here
/// uses stock controls in a grouped form.
struct FormatInspector: View {
    @Binding var card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace
        VStack(spacing: 0) {
            Picker("Inspector", selection: $workspace.inspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .accessibilityIdentifier("inspector.tabs")
            Divider()
            switch workspace.inspectorTab {
            case .card: CardInspector(card: $card)
            case .block: BlockInspector(card: $card)
            case .accessibility: AccessibilityInspector(card: card)
            }
        }
        .accessibilityIdentifier("inspector")
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case card, block, accessibility

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .card: "Card"
        case .block: "Block"
        case .accessibility: "Accessibility"
        }
    }
}

// MARK: - Card

struct CardInspector: View {
    @Binding var card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        @Bindable var workspace = workspace
        Form {
            Section("Theme") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(CardTheme.builtIn) { theme in
                        ThemeSwatch(theme: theme, isSelected: card.theme.id == theme.id) {
                            card.theme = theme
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            Section("Status") {
                Picker("Status", selection: $card.status) {
                    ForEach(ReportStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
                .labelsHidden()
            }
            Section("Details") {
                TextField("Author", text: $card.author, prompt: Text("Shown in the footer"))
                Picker("Width", selection: $workspace.cardWidth) {
                    ForEach(CardWidth.allCases) { width in
                        Text(width.label).tag(width)
                    }
                }
                .help("Email clients wrap around 600 points; chat tools show narrower cards")
            }
        }
        .formStyle(.grouped)
    }
}

/// A theme shown as a tiny card: its background, its text colour, its accent.
struct ThemeSwatch: View {
    let theme: CardTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.background.color)
                    .frame(height: 40)
                    .overlay {
                        Text("Aa")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.text.color)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                Text(theme.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Block

struct BlockInspector: View {
    @Binding var card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace

    private var selectedIndex: Int? {
        workspace.selectedBlockID.flatMap { card.index(ofBlock: $0) }
    }

    var body: some View {
        if let index = selectedIndex {
            Form {
                switch card.blocks[index] {
                case .text:
                    Section("Text") {
                        Text("Type on the card. Start a line with “- ” for a bullet; leave a blank line between paragraphs.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                case .metrics:
                    if let binding = $card.blocks[index].metricsBlock {
                        MetricsInspectorSections(block: binding)
                    }
                case .image:
                    if let binding = $card.blocks[index].imageBlock {
                        ImageInspectorSections(block: binding) { newBlock in
                            card.append(newBlock)
                            workspace.selectedBlockID = newBlock.id
                            workspace.scrollTarget = newBlock.id
                        }
                    }
                }
                arrangeSection(index: index)
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView(
                "No Block Selected",
                systemImage: "rectangle.dashed",
                description: Text("Click part of the card to format it.")
            )
        }
    }

    private func arrangeSection(index: Int) -> some View {
        let blockID = card.blocks[index].id
        return Section("Arrange") {
            HStack {
                Button("Move Up") { card.moveBlock(withID: blockID, by: -1) }
                    .disabled(index == 0)
                Button("Move Down") { card.moveBlock(withID: blockID, by: 1) }
                    .disabled(index >= card.blocks.count - 1)
                Spacer()
                Button("Delete", role: .destructive) {
                    card.removeBlock(withID: blockID)
                    workspace.selectedBlockID = nil
                }
            }
        }
    }
}

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

// MARK: - Accessibility

/// The linter's verdict, its findings (each selects the block at fault) and
/// every rule it checks.
struct AccessibilityInspector: View {
    let card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace

    private var report: AccessibilityReport {
        AccessibilityLinter.lint(card)
    }

    var body: some View {
        let report = report
        let failedRules = Set(report.issues.map(\.rule))
        Form {
            Section {
                LabeledContent {
                    Text(report.summary)
                } label: {
                    Label(
                        report.isCompliant ? "Ready to Share" : "Needs Attention",
                        systemImage: report.isCompliant ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(report.isCompliant ? Color.primary : Color.red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("inspector.accessibilityVerdict")
            }
            if !report.issues.isEmpty {
                Section("Issues") {
                    ForEach(report.issues) { issue in
                        Button {
                            if let blockID = issue.blockID {
                                workspace.selectedBlockID = blockID
                                workspace.scrollTarget = blockID
                                workspace.inspectorTab = .block
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.message)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(issue.rule.wcagReference)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(issue.severity == .error ? "Error" : "Warning"): \(issue.message)")
                        .accessibilityHint(issue.blockID == nil ? "" : "Shows the block in the inspector")
                    }
                }
            }
            Section("Checks") {
                ForEach(AccessibilityRule.allCases, id: \.self) { rule in
                    let failed = failedRules.contains(rule)
                    LabeledContent {
                        Image(systemName: failed ? "xmark" : "checkmark")
                            .foregroundStyle(failed ? Color.red : Color.secondary)
                            .accessibilityHidden(true)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rule.title)
                            Text(rule.wcagReference).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(rule.title), \(failed ? "failed" : "passed"), \(rule.wcagReference)")
                }
            }
        }
        .formStyle(.grouped)
    }
}
