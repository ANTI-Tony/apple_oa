import ReportCore
import SwiftUI

/// Heading plus body. The markup hint lives in the placeholder, not on screen.
struct TextBlockEditor: View {
    @Binding var block: TextBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Heading", text: $block.heading, prompt: Text("Heading"))
                .font(.headline)
                .textFieldStyle(.plain)
                .accessibilityLabel("Section heading")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $block.body)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .padding(6)
                    .frame(minHeight: 72, maxHeight: 240)
                    .accessibilityLabel("Body text")
                    .accessibilityHint("Start a line with a dash for a bullet. Blank lines separate paragraphs.")
                if block.body.isEmpty {
                    Text("Write here. Start a line with “- ” for a bullet.")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor).opacity(0.6)))
        }
    }
}
