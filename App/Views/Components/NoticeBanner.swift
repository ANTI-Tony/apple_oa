import SwiftUI

/// Transient confirmation ("Copied for email"). The text is also posted as a
/// VoiceOver announcement by `WorkspaceState.announce`.
struct NoticeBanner: View {
    let notice: Notice

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
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color(nsColor: .separatorColor)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("notice.banner")
    }
}
