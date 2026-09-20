import AppKit
import ReportCore
import SwiftUI

struct ImageBlockEditor: View {
    @Binding var block: ImageBlock
    let onInsertBlock: (Block) -> Void
    @Environment(WorkspaceState.self) private var workspace

    @State private var thumbnail: NSImage?
    @State private var showReplace = false
    @State private var isWorking = false

    private var visionEnabled: Bool {
        AppConfiguration.isEnabled(.visionAssist)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFit()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 96, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(block.altText.isEmpty ? "Image without a description yet" : block.altText)

            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "Alt text",
                    text: $block.altText,
                    prompt: Text("Describe the image for people who cannot see it"),
                    axis: .vertical
                )
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor).opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor)))
                .disabled(block.isDecorative)
                .accessibilityLabel("Alternative text")
                .accessibilityHint("Required unless the image is marked decorative")
                if !block.hasAcceptableAltText {
                    Label("Alt text is required", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .symbolRenderingMode(.multicolor)
                }
                TextField("Caption", text: $block.caption, prompt: Text("Caption (optional)"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Caption")
                Toggle("Decorative image (screen readers skip it)", isOn: $block.isDecorative)
                    .controlSize(.small)
                // Full labels when they fit, icons only when the column is narrow.
                ViewThatFits(in: .horizontal) {
                    actionRow(showsTitles: true)
                    actionRow(showsTitles: false)
                }
            }
        }
        .task(id: block.imageData) {
            thumbnail = NSImage(data: block.imageData)
        }
        .fileImporter(isPresented: $showReplace, allowedContentTypes: [.image]) { result in
            guard case let .success(url) = result, let replacement = ImageImport.imageBlock(from: url) else { return }
            block.imageData = replacement.imageData
            block.contentType = replacement.contentType
            block.pixelSize = replacement.pixelSize
            block.fileName = replacement.fileName
        }
    }

    private func actionRow(showsTitles: Bool) -> some View {
        HStack(spacing: 10) {
            Button { showReplace = true } label: { Label("Replace…", systemImage: "arrow.triangle.2.circlepath") }
                .help("Choose a different image")
            if visionEnabled {
                Button { suggestAltText() } label: { Label("Suggest Alt", systemImage: "sparkles") }
                    .disabled(isWorking || block.isDecorative)
                    .help("Suggest alt text: an on-device classifier proposes a starting description")
                Button { extractMetrics() } label: { Label("Extract Metrics", systemImage: "text.viewfinder") }
                    .disabled(isWorking)
                    .help("Extract metrics: read numbers from a screenshot into a new metrics block")
            }
            if isWorking {
                ProgressView().controlSize(.small)
            }
        }
        .labelStyle(AdaptiveLabelStyle(showsTitle: showsTitles))
        .buttonStyle(.borderless)
        .controlSize(.small)
        .lineLimit(1)
        .fixedSize()
    }

    private func suggestAltText() {
        isWorking = true
        let data = block.imageData
        Task {
            defer { isWorking = false }
            if let suggestion = await VisionServices.suggestAltText(for: data) {
                block.altText = suggestion
                workspace.announce("Alt text suggested. Edit it so it says what matters.")
            } else {
                workspace.announce("No suggestion available for this image", isError: true)
            }
        }
    }

    private func extractMetrics() {
        isWorking = true
        let data = block.imageData
        Task {
            defer { isWorking = false }
            do {
                if let result = try await VisionServices.extractMetrics(from: data), !result.metrics.isEmpty {
                    onInsertBlock(.metrics(MetricsBlock(heading: "Extracted from image", metrics: result.metrics)))
                    workspace.announce("Extracted \(result.metrics.count) metric\(result.metrics.count == 1 ? "" : "s"). Check the values.")
                } else {
                    workspace.announce("No labelled numbers were recognised", isError: true)
                }
            } catch {
                workspace.announce("Text recognition failed: \(error.localizedDescription)", isError: true)
            }
        }
    }
}
