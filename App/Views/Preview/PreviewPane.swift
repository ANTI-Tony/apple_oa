import ReportCore
import SwiftUI

/// Right column: the live card, an appearance menu and the accessibility badge.
struct PreviewPane: View {
    @Binding var card: SnippetCard
    @Environment(WorkspaceState.self) private var workspace
    @Environment(UserPreferences.self) private var preferences

    @State private var cardHeight: CGFloat = 400
    @State private var availableWidth: CGFloat = 0
    @State private var scale: CGFloat = 1

    private var report: AccessibilityReport {
        AccessibilityLinter.lint(card)
    }

    private var themeSelection: Binding<String> {
        Binding(
            get: { card.theme.id },
            set: { id in
                if let theme = CardTheme.builtIn(id: id) {
                    card.theme = theme
                }
            }
        )
    }

    private func updateScale() {
        guard availableWidth > 0 else { return }
        scale = min(1, max(0.3, (availableWidth - 48) / workspace.previewWidth.points))
    }

    var body: some View {
        @Bindable var workspace = workspace
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Menu {
                    Picker("Theme", selection: themeSelection) {
                        ForEach(CardTheme.builtIn) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .pickerStyle(.inline)
                    Picker("Width", selection: $workspace.previewWidth) {
                        ForEach(PreviewWidth.allCases) { width in
                            Text(width.label).tag(width)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    // Title when the column has room, palette icon alone when it is narrow.
                    Label("Appearance", systemImage: "paintpalette")
                        .labelStyle(AdaptiveLabelStyle(showsTitle: availableWidth == 0 || availableWidth > 380))
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .fixedSize()
                .help("Card theme and preview width")
                .accessibilityIdentifier("preview.appearance")

                if scale < 0.999 {
                    Text("\(Int((scale * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("The preview is scaled to fit the column. Exports use the full width.")
                        .accessibilityLabel("Preview scaled to \(Int((scale * 100).rounded())) percent")
                }
                Spacer(minLength: 0)
                AccessibilityBadge(report: report, isReportPresented: $workspace.showAccessibilityReport) { issue in
                    if let blockID = issue.blockID {
                        workspace.highlight(blockID: blockID)
                    }
                }
            }
            .padding(12)
            Divider()
            // The card is laid out at its real export width, measured, then scaled
            // to fit the column. The clear frame has no minimum width, so the
            // scroll view never forces the column wider than the window allows.
            ScrollView(.vertical) {
                let cardWidth = workspace.previewWidth.points
                Color.clear
                    .frame(minWidth: 0, idealWidth: cardWidth * scale, maxWidth: cardWidth * scale)
                    .frame(height: cardHeight * scale)
                    .overlay(alignment: .topLeading) {
                        CardView(card: card, width: cardWidth, includeFooter: preferences.includeFooter)
                            .fixedSize()
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                cardHeight = height
                            }
                            .scaleEffect(scale, anchor: .topLeading)
                    }
                    .draggable(CardTransfer(card: card)) {
                        Label("Card image", systemImage: "photo")
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                availableWidth = width
            }
            .onChange(of: availableWidth, initial: true) { _, _ in updateScale() }
            .onChange(of: workspace.previewWidth) { _, _ in updateScale() }
            .background(Color(nsColor: .underPageBackgroundColor))
        }
        .navigationTitle("Preview")
        .accessibilityIdentifier("preview.pane")
    }
}
