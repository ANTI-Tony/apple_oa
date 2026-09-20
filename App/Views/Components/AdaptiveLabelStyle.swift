import SwiftUI

/// A label that can drop its title when space is tight. The title stays the
/// accessibility label either way, so icon-only buttons remain named for
/// VoiceOver; pair it with `.help` so pointer users get a tooltip.
///
/// Used with `ViewThatFits` so rows of buttons shrink to icons instead of
/// forcing a wide minimum window (see ADR 0009).
struct AdaptiveLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            if showsTitle {
                configuration.title
            }
        }
    }
}
