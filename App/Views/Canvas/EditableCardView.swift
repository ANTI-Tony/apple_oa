import ReportCore
import SwiftUI

/// What on the canvas has keyboard focus. Drives block selection: putting the
/// caret in a block selects it, as clicking an object does in Keynote.
enum CanvasFocus: Hashable {
    case title
    case subtitle
    case field(block: UUID, slot: String)

    var blockID: UUID? {
        if case let .field(block, _) = self {
            return block
        }
        return nil
    }
}

/// The card, editable in place. There is no separate form: you change the
/// title by typing on the title. Properties that are not visible on the card
/// (theme, layout, image description) live in the Format inspector.
///
/// Built from the same `CardStyle`, `CardSurface` and `MetricsGroup` as the
/// exported `CardView`, with text fields where that view has text.
struct EditableCardView: View {
    @Binding var card: SnippetCard
    let maxWidth: CGFloat
    let includeFooter: Bool

    @Environment(WorkspaceState.self) private var workspace
    @FocusState private var focus: CanvasFocus?
    @Namespace private var rotor

    private var theme: CardTheme {
        card.theme
    }

    /// The root sets the type ramp for its subtree, so it computes its own.
    private var typography: CardTypography {
        CardTypography(scale: card.textSize.scale)
    }

    /// `body` is split into small pieces: as one expression it is more than the
    /// type checker will solve in reasonable time.
    var body: some View {
        surface
            .onChange(of: focus) { _, newFocus in
                guard let newFocus else { return }
                workspace.selectedBlockID = newFocus.blockID
            }
            .onChange(of: workspace.selectedBlockID) { _, selected in
                // Deselecting from outside (clicking the desk) also drops the caret.
                if selected == nil, focus?.blockID != nil {
                    focus = nil
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Card")
            // A custom VoiceOver rotor: jump from block to block, as the Headings
            // rotor does on a web page.
            .accessibilityRotor("Blocks") { rotorEntries }
    }

    private var surface: some View {
        content
            .frame(maxWidth: maxWidth - CardStyle.padding * 2, alignment: .leading)
            .modifier(CardSurface(theme: theme, isElevated: true))
            .cardTypography(for: card)
            .tint(theme.accent.color)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach($card.blocks) { $block in
                blockRow($block)
            }
            if card.blocks.isEmpty {
                Text("Add text, metrics or an image from the toolbar, paste with ⇧⌘V, or drop files here.")
                    .font(typography.body)
                    .foregroundStyle(theme.secondaryText.color)
                    .padding(.top, CardStyle.blockSpacing)
            }
            if includeFooter {
                footer
            }
        }
    }

    private var footer: some View {
        let text = CardDateFormatting.footerText(for: card)
        return Text(text)
            .font(typography.footer)
            .foregroundStyle(theme.secondaryText.color)
            .padding(.top, 24)
            .accessibilityLabel("Footer: \(text)")
    }

    @AccessibilityRotorContentBuilder
    private var rotorEntries: some AccessibilityRotorContent {
        ForEach(card.blocks) { block in
            AccessibilityRotorEntry(Text(verbatim: Self.rotorLabel(for: block)), id: block.id, in: rotor)
        }
    }

    private static func rotorLabel(for block: Block) -> String {
        let heading = block.heading.trimmingCharacters(in: .whitespaces)
        return heading.isEmpty ? block.kind.label : "\(block.kind.label): \(heading)"
    }

    /// One block on the canvas. Split out of `body` to keep the type checker fast.
    private func blockRow(_ block: Binding<Block>) -> some View {
        let blockID = block.wrappedValue.id
        return EditableBlockView(
            block: block,
            theme: theme,
            isSelected: workspace.selectedBlockID == blockID,
            isBeingSpoken: workspace.speech.currentSegment?.blockID == blockID,
            focus: $focus,
            actions: actions(for: blockID)
        )
        .padding(.top, CardStyle.blockSpacing)
        .id(blockID)
        .accessibilityRotorEntry(id: blockID, in: rotor)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Project · Period", text: $card.subtitle)
                .textFieldStyle(.plain)
                .font(typography.eyebrow)
                .frame(height: typography.fieldHeight(13))
                .foregroundStyle(theme.secondaryText.color)
                .focused($focus, equals: .subtitle)
                .padding(.bottom, 6)
                .accessibilityLabel("Subtitle")
                .accessibilityIdentifier("editor.subtitle")
            TextField("Title", text: $card.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(typography.title)
                .tracking(-0.3)
                .foregroundStyle(theme.text.color)
                .focused($focus, equals: .title)
                .padding(.bottom, 10)
                .accessibilityLabel("Title")
                .accessibilityIdentifier("editor.title")
            Menu {
                Picker("Status", selection: $card.status) {
                    ForEach(ReportStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                StatusLine(status: card.status, theme: theme)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Change status")
            .accessibilityLabel("Status: \(card.status.label)")
            .accessibilityIdentifier("editor.status")
        }
    }

    private func actions(for blockID: UUID) -> BlockActions {
        BlockActions(
            select: { workspace.selectedBlockID = blockID },
            moveUp: { card.moveBlock(withID: blockID, by: -1) },
            moveDown: { card.moveBlock(withID: blockID, by: 1) },
            delete: {
                card.removeBlock(withID: blockID)
                if workspace.selectedBlockID == blockID {
                    workspace.selectedBlockID = nil
                }
            },
            showInspector: { workspace.reveal(.block) },
            canMoveUp: card.index(ofBlock: blockID).map { $0 > 0 } ?? false,
            canMoveDown: card.index(ofBlock: blockID).map { $0 < card.blocks.count - 1 } ?? false
        )
    }
}

/// What a block can ask of its container.
struct BlockActions {
    let select: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void
    let showInspector: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
}
