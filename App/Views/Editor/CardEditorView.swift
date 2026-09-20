import ReportCore
import SwiftUI
import UniformTypeIdentifiers

/// The middle column: card title, status, the ordered blocks, and every way of
/// getting content in (Add Block, Smart Paste, drag and drop, file import).
struct CardEditorView: View {
    @Binding var card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDropTargeted = false
    @State private var pendingPaste: PastePayload?
    @State private var showImageImporter = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerFields
                    blocksSection
                    addBlockBar
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: workspace.highlightedBlockID) { _, blockID in
                guard let blockID else { return }
                withAnimation(reduceMotion ? nil : .default) {
                    proxy.scrollTo(blockID, anchor: .center)
                }
            }
        }
        .navigationTitle(card.title.isEmpty ? "Untitled" : card.title)
        .onDrop(of: DropIngestor.supportedTypes, isTargeted: $isDropTargeted) { providers in
            Task {
                let blocks = await DropIngestor.blocks(from: providers)
                guard !blocks.isEmpty else {
                    workspace.announce("Nothing usable was dropped", isError: true)
                    return
                }
                card.blocks.append(contentsOf: blocks)
                card.touch()
                workspace.announce("Added \(blocks.count) block\(blocks.count == 1 ? "" : "s")")
            }
            return true
        }
        .overlay {
            if isDropTargeted {
                dropOverlay
            }
        }
        .fileImporter(isPresented: $showImageImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            guard case let .success(urls) = result else { return }
            let blocks = urls.compactMap { ImageImport.imageBlock(from: $0) }.map(Block.image)
            card.blocks.append(contentsOf: blocks)
            card.touch()
            if blocks.isEmpty {
                workspace.announce("No images could be read", isError: true)
            } else {
                workspace.announce("Added \(blocks.count) image\(blocks.count == 1 ? "" : "s"). Remember to add alt text.")
            }
        }
        .sheet(item: $pendingPaste) { payload in
            PasteReviewSheet(payload: payload) { blocks in
                card.blocks.append(contentsOf: blocks)
                card.touch()
                workspace.announce("Added \(blocks.count) block\(blocks.count == 1 ? "" : "s")")
            }
        }
    }

    // MARK: Header

    private var headerFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Title", text: $card.title, prompt: Text("Card title"))
                .font(.system(.title, weight: .bold))
                .textFieldStyle(.plain)
                .accessibilityLabel("Card title")
                .accessibilityIdentifier("editor.title")
            TextField("Subtitle", text: $card.subtitle, prompt: Text("Project · period"))
                .font(.title3)
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Card subtitle")
                .accessibilityIdentifier("editor.subtitle")
            Picker("Status", selection: $card.status) {
                ForEach(ReportStatus.allCases) { status in
                    Label(status.label, systemImage: status.symbolName).tag(status)
                }
            }
            .labelsHidden()
            .fixedSize()
            .padding(.top, 4)
            .accessibilityLabel("Status")
            .accessibilityIdentifier("editor.status")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: Blocks

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach($card.blocks) { $block in
                Divider()
                BlockEditorRow(
                    block: $block,
                    position: card.index(ofBlock: block.id) ?? 0,
                    count: card.blocks.count,
                    isHighlighted: workspace.highlightedBlockID == block.id,
                    onMove: { offset in card.moveBlock(withID: block.id, by: offset) },
                    onDelete: { card.removeBlock(withID: block.id) },
                    onInsertBlock: { newBlock in
                        card.append(newBlock)
                        workspace.announce("Added \(newBlock.kind.label.lowercased()) block")
                    }
                )
                .id(block.id)
            }
            Divider()
        }
    }

    private var addBlockBar: some View {
        HStack(spacing: 16) {
            Menu {
                Button { card.append(.text(TextBlock())) } label: { Label("Text", systemImage: "text.alignleft") }
                    .accessibilityIdentifier("editor.addText")
                Button { card.append(.metrics(MetricsBlock())) } label: { Label("Metrics", systemImage: "chart.bar.xaxis") }
                    .accessibilityIdentifier("editor.addMetrics")
                Button { showImageImporter = true } label: { Label("Image…", systemImage: "photo") }
                    .accessibilityIdentifier("editor.addImage")
            } label: {
                Label("Add Block", systemImage: "plus")
            }
            .menuStyle(.button)
            .fixedSize()
            .accessibilityIdentifier("editor.addBlock")

            Button { smartPaste() } label: { Label("Smart Paste", systemImage: "doc.on.clipboard") }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .help("Insert the clipboard as the right kind of block: image, metrics or text (⇧⌘V)")
                .accessibilityIdentifier("editor.smartPaste")

            Spacer()
            if card.blocks.isEmpty {
                Text("or drop files here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
            .overlay {
                Label("Drop images, CSV, JSON or text", systemImage: "arrow.down.doc")
                    .font(.title3)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(8)
            .allowsHitTesting(false)
    }

    private func smartPaste() {
        guard let payload = PasteIngestor.read() else {
            workspace.announce("The clipboard has no text or image", isError: true)
            return
        }
        switch payload {
        case .metrics:
            pendingPaste = payload
        case let .image(block):
            card.append(.image(block))
            workspace.announce("Added image block. Remember to add alt text.")
        case let .text(text):
            card.append(.text(TextBlock(body: text)))
            workspace.announce("Added text block")
        }
    }
}
