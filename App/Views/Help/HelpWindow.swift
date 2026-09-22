import SwiftUI

/// The usage guide, in the corner macOS keeps it: Help ▸ Reporting Builder Help.
///
/// It is a reference, not a re-told tour. The README narrates the project for
/// someone deciding whether to clone it; this answers "what do I press" for
/// someone who already has the app open, and almost everything on these pages
/// is read out of the app rather than written down a second time.
struct HelpWindow: View {
    @Environment(HelpState.self) private var help

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.allCases, id: \.self, selection: selection) { topic in
                Label(topic.title, systemImage: topic.symbolName)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(help.topic.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)

                    switch help.topic {
                    case .shortcuts: ShortcutsPage()
                    case .accessibility: AccessibilityPage()
                    case .storage: StoragePage()
                    case .about: AboutPage()
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .textSelection(.enabled)
            }
        }
        .navigationTitle("Reporting Builder Help")
    }

    /// `List` wants an optional selection; the window always has a topic.
    private var selection: Binding<HelpTopic?> {
        Binding(get: { help.topic }, set: {
            if let topic = $0 {
                help.topic = topic
            }
        })
    }
}

// MARK: - Pieces

/// A heading a VoiceOver user can jump between, like the ones the app's own
/// HTML export writes for its readers.
private struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct Paragraph: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One command and its keys. The glyphs are for the eye; VoiceOver is given the
/// spelled-out form, because it reads "⌥⌘⌫" as punctuation or as nothing, and
/// ⌘⌫ against ⌥⌘⌫ is exactly the pair a user must be able to tell apart.
private struct ShortcutRow: View {
    let shortcut: MenuShortcut

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                title
                Spacer(minLength: 16)
                keys
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                keys
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shortcut.title), \(shortcut.spoken), in the \(shortcut.menu.label) menu")
    }

    private var title: some View {
        Text(shortcut.title)
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var keys: some View {
        Text(shortcut.glyphs)
            .font(.body.monospaced())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

// MARK: - Pages

private struct ShortcutsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(MenuShortcut.Menu.allCases) { menu in
                let rows = MenuShortcut.allCases.filter { $0.menu == menu && isAvailable($0) }
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeading(text: menu.label)
                        ForEach(rows) { ShortcutRow(shortcut: $0) }
                    }
                }
            }
            Paragraph(text: HelpText.deleteFootnote)
        }
    }

    /// Never document a command that this build permanently dims.
    private func isAvailable(_ shortcut: MenuShortcut) -> Bool {
        shortcut != .newCardFromNotes || AppConfiguration.isEnabled(.writingAssistance)
    }
}

private struct AccessibilityPage: View {
    @Environment(WorkspaceState.self) private var workspace
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Paragraph(text: HelpText.accessibilityIntro)

            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(text: "What the shield means")
                verdict(
                    "Accessible",
                    symbol: "checkmark.shield",
                    tint: .primary,
                    detail: "Nothing to fix. Safe to send."
                )
                verdict(
                    "Accessible, 2 warnings",
                    symbol: "checkmark.shield",
                    tint: .primary,
                    detail: "It will read correctly, but something could be clearer."
                )
                verdict(
                    "1 accessibility error",
                    symbol: "exclamationmark.shield.fill",
                    tint: .red,
                    detail: "Someone will be unable to read part of this card."
                )
            }

            Paragraph(text: HelpText.accessibilityRules)

            Button("Open the Accessibility Check") {
                workspace.reveal(.accessibility)
                dismissWindow(id: HelpState.windowID)
            }
        }
    }

    private func verdict(_ label: String, symbol: String, tint: Color, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.body.weight(.medium))
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StoragePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Paragraph(text: HelpText.storageIntro)

            LabeledContent("Data file", value: AppPaths.cardsFile.path)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(text: "Writing assistance")
                Paragraph(text: HelpText.assistanceIntro)
                Paragraph(text: RemoteProcessingNotice.text)
                SettingsLink { Text("Open Settings…") }
            }
        }
    }
}

private struct AboutPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledContent("Version", value: "\(AppConfiguration.version) (\(AppConfiguration.build))")
            LabeledContent("Build", value: AppConfiguration.buildFlavor)
            LabeledContent("Features", value: AppConfiguration.enabledFeatures.map(\.label).joined(separator: ", "))

            Link("Card Gallery", destination: HelpLinks.gallery)
            Link("Source Repository", destination: HelpLinks.repository)
        }
    }
}
