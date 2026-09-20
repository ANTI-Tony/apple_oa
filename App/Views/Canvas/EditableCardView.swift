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

    private var theme: CardTheme {
        card.theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach($card.blocks) { $block in
                EditableBlockView(
                    block: $block,
                    theme: theme,
                    isSelected: workspace.selectedBlockID == block.id,
                    focus: $focus,
                    actions: actions(for: block.id)
                )
                .padding(.top, CardStyle.blockSpacing)
                .id(block.id)
            }
            if card.blocks.isEmpty {
                Text("Add text, metrics or an image from the toolbar, paste with ⇧⌘V, or drop files here.")
                    .font(CardStyle.body)
                    .foregroundStyle(theme.secondaryText.color)
                    .padding(.top, CardStyle.blockSpacing)
            }
            if includeFooter {
                Text(CardDateFormatting.footerText(for: card))
                    .font(CardStyle.footer)
                    .foregroundStyle(theme.secondaryText.color)
                    .padding(.top, 24)
                    .accessibilityLabel("Footer: \(CardDateFormatting.footerText(for: card))")
            }
        }
        .frame(maxWidth: maxWidth - CardStyle.padding * 2, alignment: .leading)
        .modifier(CardSurface(theme: theme, isElevated: true))
        .tint(theme.accent.color)
        .onChange(of: focus) { _, newFocus in
            guard let newFocus else { return }
            workspace.selectedBlockID = newFocus.blockID
        }
        .onChange(of: workspace.selectedBlockID) { _, selected in
            // Deselecting from outside (clicking the canvas) also drops the caret.
            if selected == nil, focus?.blockID != nil {
                focus = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Project · Period", text: $card.subtitle)
                .textFieldStyle(.plain)
                .font(CardStyle.eyebrow)
                .foregroundStyle(theme.secondaryText.color)
                .focused($focus, equals: .subtitle)
                .padding(.bottom, 6)
                .accessibilityLabel("Subtitle")
                .accessibilityIdentifier("editor.subtitle")
            TextField("Title", text: $card.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(CardStyle.title)
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
