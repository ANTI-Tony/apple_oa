import SwiftUI

/// Transient confirmation ("Copied for email"). The text is also posted as a
/// VoiceOver announcement by `WorkspaceState.announce`.
struct NoticeBanner: View {
    let notice: Notice
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(notice.isError ? .orange : .green)
                .accessibilityHidden(true)
            Text(notice.text)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial),
            in: Capsule()
        )
        .overlay(Capsule().stroke(Color(nsColor: .separatorColor)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("notice.banner")
    }
}

extension View {
    /// Section footers in the inspector and Settings are sentences; they read
    /// better leading-aligned than with the grouped form's trailing default.
    /// The inset lines the sentence up with the section's header and rows.
    func sectionFooterStyle() -> some View {
        multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 9)
    }
}
