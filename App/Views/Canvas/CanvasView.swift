import AppKit
import ReportCore
import SwiftUI
import UniformTypeIdentifiers

/// The document area: the card on a neutral desk, edited in place. Content
/// comes in by typing, from the toolbar, by pasting (⇧⌘V) or by dropping files.
struct CanvasView: View {
    @Binding var card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDropTargeted = false
    @State private var simulatedImage: CGImage?

    var body: some View {
        @Bindable var workspace = workspace
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    if workspace.visionSimulation == .none {
                        EditableCardView(card: $card, maxWidth: workspace.cardWidth.points, includeFooter: preferences.includeFooter)
                            .draggable(CardTransfer(card: card, width: workspace.cardWidth.points)) {
                                Label("Card Image", systemImage: "photo")
                                    .padding(8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                        InsertBar(actions: insertActions)
                    } else {
                        simulationView
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: workspace.scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(reduceMotion ? nil : .default) {
                    proxy.scrollTo(target, anchor: .center)
                }
                workspace.scrollTarget = nil
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onTapGesture { workspace.selectedBlockID = nil }
        .onDrop(of: DropIngestor.supportedTypes, isTargeted: $isDropTargeted) { providers in
            Task {
                let blocks = await DropIngestor.blocks(from: providers)
                guard !blocks.isEmpty else {
                    workspace.announce("Nothing usable was dropped", isError: true)
                    return
                }
                insert(blocks)
            }
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .fileImporter(isPresented: $workspace.isImportingImage, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            guard case let .success(urls) = result else { return }
            let blocks = urls.compactMap { ImageImport.imageBlock(from: $0) }.map(Block.image)
            if blocks.isEmpty {
                workspace.announce("No images could be read", isError: true)
            } else {
                insert(blocks)
            }
        }
        .sheet(item: $workspace.pendingPaste) { payload in
            PasteReviewSheet(payload: payload) { blocks in insert(blocks) }
        }
        // File ▸ Import from iPhone or iPad (Continuity Camera).
        .importsItemProviders([.image]) { providers in
            Task {
                let blocks = await DropIngestor.blocks(from: providers)
                if !blocks.isEmpty {
                    insert(blocks)
                }
            }
            return true
        }
        .task(id: SimulationKey(card: card, simulation: workspace.visionSimulation, width: workspace.cardWidth)) {
            renderSimulation()
        }
        .onChange(of: workspace.insertRequest) { _, request in
            guard let request else { return }
            perform(request)
            workspace.insertRequest = nil
        }
        .onAppear { Self.resignInitialFocus() }
        .onChange(of: card.id) { _, _ in Self.resignInitialFocus() }
        .navigationTitle(card.title.isEmpty ? "Untitled" : card.title)
        .navigationSubtitle(card.subtitle)
        .accessibilityIdentifier("canvas")
    }

    /// AppKit gives the first text field focus, and selects its text, when a
    /// window opens. A document should open at rest, as in Pages.
    private static func resignInitialFocus() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private var insertActions: InsertBar.Actions {
        InsertBar.Actions(
            text: { perform(.text) },
            metrics: { perform(.metrics) },
            image: { perform(.image) },
            paste: { perform(.paste) }
        )
    }

    private func perform(_ request: InsertRequest) {
        switch request {
        case .text: insert([.text(TextBlock())])
        case .metrics: insert([.metrics(MetricsBlock(metrics: [Metric(label: "", value: "")]))])
        case .image: workspace.isImportingImage = true
        case .paste: smartPaste()
        }
    }

    // MARK: Colour vision

    private struct SimulationKey: Equatable {
        let card: SnippetCard
        let simulation: VisionSimulation
        let width: CardWidth
    }

    private func renderSimulation() {
        guard workspace.visionSimulation != .none,
              let image = CardExporter.cgImage(for: card, width: workspace.cardWidth.points, includeFooter: preferences.includeFooter)
        else {
            simulatedImage = nil
            return
        }
        simulatedImage = VisionSimulator.simulate(image, as: workspace.visionSimulation)
    }

    private var simulationView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "eye")
                    .accessibilityHidden(true)
                // The two lines read as one sentence; Done stays a button of its own,
                // so VoiceOver and Full Keyboard Access can reach it.
                VStack(alignment: .leading, spacing: 1) {
                    Text("Simulating \(workspace.visionSimulation.label)")
                        .font(.callout.weight(.semibold))
                    Text("\(workspace.visionSimulation.detail). Editing is paused.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 12)
                Button("Done") { workspace.visionSimulation = .none }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityHint("Returns to the editable card")
                    .accessibilityIdentifier("canvas.simulationDone")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: workspace.cardWidth.points)

            if let simulatedImage {
                Image(decorative: simulatedImage, scale: 2)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: workspace.cardWidth.points)
                    .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
                    .accessibilityLabel("The card as seen with \(workspace.visionSimulation.label)")
            } else {
                ProgressView()
            }
        }
    }

    // MARK: Inserting

    private func insert(_ blocks: [Block]) {
        card.blocks.append(contentsOf: blocks)
        card.touch()
        countWordsInImages(blocks)
        if let last = blocks.last {
            workspace.selectedBlockID = last.id
            workspace.scrollTarget = last.id
        }
        let needsDescription = blocks.contains {
            if case let .image(image) = $0 {
                !image.hasAcceptableAltText
            } else {
                false
            }
        }
        if needsDescription {
            workspace.reveal(.block)
            workspace.announce("Image added. Describe it in the Format inspector.")
        }
    }

    /// Runs on-device text recognition on new images and stores the word
    /// count, which lets the linter flag images that are mostly text.
    private func countWordsInImages(_ blocks: [Block]) {
        guard AppConfiguration.isEnabled(.visionAssist) else { return }
        for case let .image(image) in blocks where image.recognizedWordCount == nil {
            let data = image.imageData
            let blockID = image.id
            Task {
                guard let lines = try? await VisionServices.recognizeText(in: data) else { return }
                let words = lines.reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
                guard let index = card.index(ofBlock: blockID), case var .image(current) = card.blocks[index] else { return }
                current.recognizedWordCount = words
                card.blocks[index] = .image(current)
            }
        }
    }

    private func smartPaste() {
        guard let payload = PasteIngestor.read() else {
            workspace.announce("The clipboard has no text or image", isError: true)
            return
        }
        switch payload {
        case .metrics: workspace.pendingPaste = payload
        case let .image(block): insert([.image(block)])
        case let .text(text): insert([.text(TextBlock(body: text))])
        }
    }
}

/// What the toolbar, menus and the bar under the card can ask the canvas to add.
enum InsertRequest: Equatable {
    case text, metrics, image, paste
}

/// A quiet row under the card, for people who look at the page rather than the toolbar.
struct InsertBar: View {
    struct Actions {
        let text: () -> Void
        let metrics: () -> Void
        let image: () -> Void
        let paste: () -> Void
    }

    let actions: Actions

    var body: some View {
        HStack(spacing: 18) {
            Button(action: actions.text) { Label("Text", systemImage: "textformat") }
                .accessibilityIdentifier("canvas.addText")
            Button(action: actions.metrics) { Label("Metrics", systemImage: "chart.bar") }
                .accessibilityIdentifier("canvas.addMetrics")
            Button(action: actions.image) { Label("Image", systemImage: "photo") }
                .accessibilityIdentifier("canvas.addImage")
            Button(action: actions.paste) { Label("Paste", systemImage: "doc.on.clipboard") }
                .help("Paste the clipboard as the right kind of block (⇧⌘V)")
                .accessibilityIdentifier("canvas.paste")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add to card")
    }
}
