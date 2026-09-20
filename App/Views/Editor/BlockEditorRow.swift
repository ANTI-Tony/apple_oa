import ReportCore
import SwiftUI

/// Chrome shared by every block editor. Deliberately quiet: a small kind label,
/// and move/delete controls that appear on hover or keyboard focus. The same
/// actions are always available from the context menu and the Card menu
/// (⌥⌘↑, ⌥⌘↓, ⌥⌘⌫), so nothing depends on the pointer.
struct BlockEditorRow: View {
    @Binding var block: Block
    let position: Int
    let count: Int
    let isHighlighted: Bool
    let onMove: (Int) -> Void
    let onDelete: () -> Void
    let onInsertBlock: (Block) -> Void

    private enum Control: Hashable {
        case layout, moveUp, moveDown, delete
    }

    @State private var isHovering = false
    @FocusState private var focusedControl: Control?

    private var showControls: Bool {
        isHovering || focusedControl != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Label(block.kind.label, systemImage: block.kind.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                controls
                    .opacity(showControls ? 1 : 0)
            }
            editor
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .focusedValue(\.activeBlockID, block.id)
        .contextMenu {
            Button("Move Up") { onMove(-1) }.disabled(position == 0)
            Button("Move Down") { onMove(1) }.disabled(position >= count - 1)
            Divider()
            Button("Delete Block", role: .destructive) { onDelete() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.kind.label) block \(position + 1) of \(count)")
    }

    private var controls: some View {
        HStack(spacing: 2) {
            if let metrics = $block.metricsBlock {
                Menu {
                    Picker("Layout", selection: metrics.layout) {
                        ForEach(MetricsLayout.allCases, id: \.self) { layout in
                            Text(layout.label).tag(layout)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "rectangle.grid.2x2")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .fixedSize()
                .focused($focusedControl, equals: .layout)
                .help("Show metrics as tiles or a table")
                .accessibilityLabel("Metrics layout")
            }
            Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
                .disabled(position == 0)
                .focused($focusedControl, equals: .moveUp)
                .help("Move up (⌥⌘↑)")
                .accessibilityLabel("Move \(block.kind.label) block up")
            Button { onMove(1) } label: { Image(systemName: "chevron.down") }
                .disabled(position >= count - 1)
                .focused($focusedControl, equals: .moveDown)
                .help("Move down (⌥⌘↓)")
                .accessibilityLabel("Move \(block.kind.label) block down")
            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
                .focused($focusedControl, equals: .delete)
                .help("Delete block (⌥⌘⌫)")
                .accessibilityLabel("Delete \(block.kind.label) block")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }

    @ViewBuilder
    private var editor: some View {
        switch block {
        case .text:
            if let binding = $block.textBlock {
                TextBlockEditor(block: binding)
            }
        case .metrics:
            if let binding = $block.metricsBlock {
                MetricsBlockEditor(block: binding)
            }
        case .image:
            if let binding = $block.imageBlock {
                ImageBlockEditor(block: binding, onInsertBlock: onInsertBlock)
            }
        }
    }
}

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
