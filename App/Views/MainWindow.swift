import ReportCore
import SwiftUI

/// The main window. Adapts to its width: three columns when wide, editor plus
/// preview when medium, and a single pane with an Edit/Preview switch when
/// compact (see `WindowLayout`). Accessibility findings live in a popover
/// behind the badge above the preview.
struct MainWindow: View {
    @Environment(CardStore.self) private var store
    @Environment(WorkspaceState.self) private var workspace
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var layout: WindowLayout = .wide
    @State private var compactPane: CompactPane = .edit

    var body: some View {
        // The width that matters is the window's, not the split view's: a split
        // view never reports less than the minimum of its visible columns, so
        // measuring it would hide exactly the situation we need to react to.
        GeometryReader { window in
            splitView
                .onChange(of: window.size.width, initial: true) { _, width in
                    adapt(to: width)
                }
        }
        .onAppear { LaunchOverrides.applyWindowSize() }
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
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        } content: {
            if let binding = selectedCardBinding {
                CardEditorView(card: binding)
                    // Roomier when there is space; the smaller minimum is what lets
                    // the narrower layouts fit (see WindowLayout).
                    .navigationSplitViewColumnWidth(min: layout == .wide ? 420 : 340, ideal: 520)
            } else {
                ContentUnavailableView(
                    "Select a card",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Choose a card in the sidebar or create a new one with ⌘N.")
                )
            }
        } detail: {
            detailPane
                .navigationSplitViewColumnWidth(min: 300, ideal: 620)
        }
    }

    /// In the compact layout the detail column is the only visible one, so it
    /// hosts whichever pane the user picked.
    @ViewBuilder
    private var detailPane: some View {
        if let binding = selectedCardBinding {
            if layout == .compact, compactPane == .edit {
                CardEditorView(card: binding)
            } else {
                PreviewPane(card: binding)
            }
        } else {
            ContentUnavailableView(
                "No card selected",
                systemImage: "rectangle.on.rectangle",
                description: Text("Create a card with ⌘N, or show the sidebar to pick one.")
            )
        }
    }

    /// Re-flows only when a breakpoint is crossed, so a sidebar the user
    /// reopened by hand is left alone while they resize within a layout.
    private func adapt(to width: CGFloat) {
        let newLayout = WindowLayout.forWidth(width)
        guard newLayout != layout else { return }
        layout = newLayout
        columnVisibility = newLayout.columnVisibility
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
                    Button {
                        addCard(from: template)
                    } label: {
                        Label(template.name, systemImage: template.symbolName)
                    }
                }
            } label: {
                Label("New Card", systemImage: "plus")
            } primaryAction: {
                addCard(from: preferences.defaultTemplate)
            }
            .help("Create a new card (⌘N). Hold to pick a template.")
            .accessibilityIdentifier("toolbar.newCard")
        }

        if layout == .compact {
            ToolbarItem(placement: .principal) {
                Picker("Pane", selection: $compactPane) {
                    ForEach(CompactPane.allCases) { pane in
                        Text(pane.label).tag(pane)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Switch between editing and the live preview")
                .accessibilityLabel("Pane")
                .accessibilityIdentifier("layout.paneSwitch")
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if let card = store.selectedCard {
                Menu {
                    ForEach(CopyVariant.allCases) { variant in
                        Button {
                            workspace.copy(card, variant: variant, preferences: preferences.exportPreferences)
                        } label: {
                            Label(variant.label, systemImage: variant.symbolName)
                        }
                    }
                    Divider()
                    Section("Save As") {
                        ForEach(ExportFormat.allCases) { format in
                            Button("\(format.label)…") {
                                workspace.export(card, format: format, preferences: preferences.exportPreferences)
                            }
                        }
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                } primaryAction: {
                    workspace.copy(card, variant: .rich, preferences: preferences.exportPreferences)
                }
                .help("Copy for Email (⇧⌘C). Hold for other formats and file export.")
                .accessibilityIdentifier("toolbar.copy")

                ShareLink(
                    item: CardTransfer(card: card),
                    preview: SharePreview(card.title.isEmpty ? "Card" : card.title, image: Image(systemName: "doc.richtext"))
                )
                .help("Share via Mail, Messages, AirDrop and more")
                .accessibilityIdentifier("toolbar.share")
            }
        }
    }
}
