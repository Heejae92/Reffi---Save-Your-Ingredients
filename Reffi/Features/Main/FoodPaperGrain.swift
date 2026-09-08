import SwiftUI

/// One shared 256 KiB fibre plate for both ingredient and recipe renderers.
/// No per-frame randomness, path construction, size-specific images or extra render layer.
enum FoodPaperGrain {
    static let plate: CGImage = {
        let side = 256
        var random = SeededGen(417)
        func noise() -> Double { random.unit() * 2 - 1 }
        // Fine fibres only: broad density patches read as stains on pale food and plates.
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            var strand = noise()
            for x in 0..<side {
                strand = strand * 0.72 + noise() * 0.28
                let grain = noise() * 0.4 + strand * 0.6
                // Dark recesses stay weaker than light fibres, keeping cream surfaces clean.
                let alpha = UInt8(min(1, abs(grain)) * (grain > 0 ? 24 : 12))
                let offset = (y * side + x) * 4
                // Premultiplied monochrome ink: white fibres or dark recesses.
                let ink: UInt8 = grain > 0 ? alpha : 0
                pixels[offset] = ink
                pixels[offset+1] = ink
                pixels[offset+2] = ink
                pixels[offset+3] = alpha
            }
        }
        let data = Data(pixels) as CFData
        let provider = CGDataProvider(data: data)!
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }()
    private static let image = Image(decorative: plate, scale: 1)

    static func overlay(in rect: CGRect, context: inout GraphicsContext) {
        var c = context
        // Existing artwork alpha is preserved, including transparent gaps and cut edges.
        c.blendMode = .sourceAtop
        c.draw(image, in: rect)
    }
}
