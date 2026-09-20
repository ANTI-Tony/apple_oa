import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Colour-vision deficiencies the canvas can approximate, so an author can
/// check that nothing on the card depends on telling red from green.
///
/// The matrices are the widely used linear approximations. They are meant for
/// a quick sanity check, not as a clinical simulation.
enum VisionSimulation: String, CaseIterable, Identifiable {
    case none
    case protanopia
    case deuteranopia
    case tritanopia
    case achromatopsia

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .none: "Typical Vision"
        case .protanopia: "Protanopia"
        case .deuteranopia: "Deuteranopia"
        case .tritanopia: "Tritanopia"
        case .achromatopsia: "No Colour"
        }
    }

    var detail: String {
        switch self {
        case .none: "Colours as chosen"
        case .protanopia: "Red-blind, about 1 in 100 men"
        case .deuteranopia: "Green-blind, the most common form"
        case .tritanopia: "Blue-yellow, rare"
        case .achromatopsia: "Greyscale, also how it prints in black and white"
        }
    }

    /// Rows of the RGB mixing matrix.
    var matrix: [[CGFloat]] {
        switch self {
        case .none: [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
        case .protanopia: [[0.567, 0.433, 0], [0.558, 0.442, 0], [0, 0.242, 0.758]]
        case .deuteranopia: [[0.625, 0.375, 0], [0.7, 0.3, 0], [0, 0.3, 0.7]]
        case .tritanopia: [[0.95, 0.05, 0], [0, 0.433, 0.567], [0, 0.475, 0.525]]
        case .achromatopsia: [[0.299, 0.587, 0.114], [0.299, 0.587, 0.114], [0.299, 0.587, 0.114]]
        }
    }

    /// Applies the simulation to one colour. Exposed for tests.
    func apply(red: CGFloat, green: CGFloat, blue: CGFloat) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let rows = matrix
        func mix(_ row: [CGFloat]) -> CGFloat {
            min(1, max(0, row[0] * red + row[1] * green + row[2] * blue))
        }
        return (mix(rows[0]), mix(rows[1]), mix(rows[2]))
    }
}

@MainActor
enum VisionSimulator {
    private static let context = CIContext()

    static func simulate(_ image: CGImage, as simulation: VisionSimulation) -> CGImage? {
        guard simulation != .none else { return image }
        let rows = simulation.matrix
        let filter = CIFilter.colorMatrix()
        filter.inputImage = CIImage(cgImage: image)
        filter.rVector = CIVector(x: rows[0][0], y: rows[0][1], z: rows[0][2], w: 0)
        filter.gVector = CIVector(x: rows[1][0], y: rows[1][1], z: rows[1][2], w: 0)
        filter.bVector = CIVector(x: rows[2][0], y: rows[2][1], z: rows[2][2], w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let output = filter.outputImage else { return nil }
        return context.createCGImage(output, from: output.extent)
    }
}
