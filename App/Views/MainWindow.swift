import ReportCore
import SwiftUI

/// The main window, arranged like a Pages or Keynote document window: a list
/// on the left, the document in the middle, the Format inspector on the right.
/// Narrower windows drop the list, then the inspector (see `WindowLayout`).
struct MainWindow: View {
    @Environment(CardStore.self) private var store
    @Environment(WorkspaceState.self) private var workspace
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var layout: WindowLayout = .wide

    var body: some View {
        // The width that matters is the window's, not the split view's: a split
        // view never reports less than the minimum of its visible columns, so
        // measuring it would hide exactly the situation we need to react to.
        GeometryReader { window in
            splitView
                .inspector(isPresented: inspectorPresented) {
                    Group {
                        if let binding = selectedCardBinding {
                            FormatInspector(card: binding)
                        } else {
                            ContentUnavailableView("No Card Selected", systemImage: "paintbrush")
                        }
                    }
                    .inspectorColumnWidth(min: 260, ideal: 290, max: 360)
                }
                .onChange(of: window.size.width, initial: true) { _, width in
                    adapt(to: width)
                }
        }
        .onAppear { LaunchOverrides.applyWindowSize() }
        .onChange(of: store.selectedCardID) { _, _ in workspace.selectedBlockID = nil }
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) {
            if let notice = workspace.notice {
                NoticeBanner(notice: notice)
                    .padding(.bottom, 16)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: workspace.notice)
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CardListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
        } detail: {
            if let binding = selectedCardBinding {
                CanvasView(card: binding)
            } else {
                ContentUnavailableView(
                    "No Card Selected",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Choose a card in the sidebar, or press ⌘N for a new one.")
                )
            }
        }
    }

    /// The inspector is shown when the user wants it and the window has room.
    private var inspectorPresented: Binding<Bool> {
        Binding(
            get: { workspace.wantsInspector && (layout.allowsInspector || forcedInspector) },
            set: { isShown in
                if layout.allowsInspector {
                    workspace.wantsInspector = isShown
                } else if isShown {
                    // Asked for by hand in a narrow window.
                    workspace.wantsInspector = true
                    forcedInspector = true
                } else {
                    // Hidden for lack of room, or closed again in a narrow window.
                    // Either way, leave the wide-window preference alone.
                    forcedInspector = false
                }
            }
        )
    }

    /// True when the user opened the inspector by hand in a compact window.
    @State private var forcedInspector = false

    /// Re-flows only when a breakpoint is crossed, so a sidebar the user
    /// reopened by hand is left alone while they resize within a layout.
    private func adapt(to width: CGFloat) {
        let newLayout = WindowLayout.forWidth(width)
        guard newLayout != layout else { return }
        layout = newLayout
        columnVisibility = newLayout.columnVisibility
        forcedInspector = false
    }

    private var selectedCardBinding: Binding<SnippetCard>? {
        guard let current = store.selectedCard else { return nil }
        return Binding(
            get: { store.selectedCard ?? current },
            set: { store.update($0) }
        )
    }

    private func addCard(from template: CardTemplate) {
        store.add(template: template, theme: preferences.defaultTheme, author: preferences.authorName)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                ForEach(CardTemplate.builtIn) { template in
                    Button(template.name) { addCard(from: template) }
                }
            } label: {
                Label("New Card", systemImage: "plus")
            } primaryAction: {
                addCard(from: preferences.defaultTemplate)
            }
            .help("New card (⌘N). Hold for templates.")
            .accessibilityIdentifier("toolbar.newCard")
        }

        if let card = store.selectedCard {
            ToolbarItemGroup(placement: .principal) {
                Button { workspace.insertRequest = .text } label: { Label("Text", systemImage: "textformat") }
                    .help("Add text")
                    .accessibilityIdentifier("toolbar.addText")
                Button { workspace.insertRequest = .metrics } label: { Label("Metrics", systemImage: "chart.bar") }
                    .help("Add metrics")
                    .accessibilityIdentifier("toolbar.addMetrics")
                Button { workspace.insertRequest = .image } label: { Label("Image", systemImage: "photo") }
                    .help("Add an image")
                    .accessibilityIdentifier("toolbar.addImage")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                AccessibilityStatusButton(report: AccessibilityLinter.lint(card)) {
                    workspace.reveal(.accessibility)
                }

                Menu {
                    ForEach(CopyVariant.allCases) { variant in
                        Button(variant.label) {
                            workspace.copy(card, variant: variant, preferences: workspace.exportPreferences(from: preferences))
                        }
                    }
                    Divider()
                    Section("Export") {
                        ForEach(ExportFormat.allCases) { format in
                            Button("\(format.label)…") {
                                workspace.export(card, format: format, preferences: workspace.exportPreferences(from: preferences))
                            }
                        }
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                } primaryAction: {
                    workspace.copy(card, variant: .rich, preferences: workspace.exportPreferences(from: preferences))
                }
                .help("Copy for Email (⇧⌘C). Hold for other formats and export.")
                .accessibilityIdentifier("toolbar.copy")

                ShareLink(
                    item: CardTransfer(card: card, width: workspace.cardWidth.points),
                    preview: SharePreview(card.title.isEmpty ? "Card" : card.title, image: Image(systemName: "doc.richtext"))
                )
                .help("Share")
                .accessibilityIdentifier("toolbar.share")

                Toggle(isOn: inspectorPresented) {
                    Label("Format", systemImage: "paintbrush")
                }
                .help("Show or hide the Format inspector (⌥⌘I)")
                .accessibilityIdentifier("toolbar.format")
            }
        }
    }
}

/// Toolbar glance at the accessibility state. Quiet when all is well; a count
/// when something needs fixing. Opens the Accessibility tab of the inspector.
struct AccessibilityStatusButton: View {
    let report: AccessibilityReport
    let action: () -> Void

    private var label: String {
        if !report.isCompliant {
            return "\(report.errors.count) accessibility \(report.errors.count == 1 ? "error" : "errors")"
        }
        if !report.warnings.isEmpty {
            return "Accessible, \(report.warnings.count) \(report.warnings.count == 1 ? "warning" : "warnings")"
        }
        return "Accessible"
    }

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: report.isCompliant ? "checkmark.shield" : "exclamationmark.shield.fill")
        }
        .foregroundStyle(report.isCompliant ? Color.primary : Color.red)
        .help("\(label). Show the accessibility check.")
        .accessibilityIdentifier("toolbar.accessibility")
    }
}
