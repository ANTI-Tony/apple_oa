import AppKit
import ReportCore
import SwiftUI

extension HexColor {
    var color: Color {
        let rgb = components
        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    var nsColor: NSColor {
        let rgb = components
        return NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}

extension ReportStatus {
    /// Tint for app chrome (sidebar rows). Card rendering uses theme colours.
    var tint: Color {
        switch self {
        case .onTrack: .green
        case .atRisk: .orange
        case .offTrack: .red
        case .completed: .blue
        case .notStarted: .gray
        }
    }
}
