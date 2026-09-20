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
            Group {
                switch workspace.inspectorTab {
                case .card: CardInspector(card: $card)
                case .block: BlockInspector(card: $card)
                case .accessibility: AccessibilityInspector(card: card)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("inspector")
    }
}

/// What an inspector shows when there is nothing to inspect. Quiet, as in
/// Keynote's Format inspector: a full-size placeholder would shout in a column
/// this narrow.
struct InspectorPlaceholder: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
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
    @Environment(\.colorSchemeContrast) private var contrast

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
                if contrast == .increased, card.theme.id != CardTheme.highContrast.id {
                    // The Mac is set to Increase Contrast; offer the matching card theme.
                    Button("Use High Contrast Theme") { card.theme = .highContrast }
                        .help("Increase Contrast is on in System Settings")
                }
            }
            Section {
                Picker("Text Size", selection: $card.textSize) {
                    ForEach(CardTextSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
            } footer: {
                Text("Large and Extra Large are large-print editions for readers with low vision. Every export follows.")
                    .sectionFooterStyle()
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
                    if let binding = $card.blocks[index].textBlock {
                        RefineSection(block: binding, card: $card)
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
            InspectorPlaceholder(title: "No Block Selected", message: "Click part of the card to format it.")
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
