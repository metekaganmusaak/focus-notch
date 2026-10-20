import AppKit
import CoreGraphics

/// 8-bit RGBA pixels, top row first. `premultiplied` says how the color channels are stored.
struct RGBAImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]
    var premultiplied: Bool

    init(width: Int, height: Int, premultiplied: Bool = true) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: width * height * 4)
        self.premultiplied = premultiplied
    }

    /// Decodes an image into premultiplied RGBA.
    init(_ image: CGImage) {
        self.init(width: image.width, height: image.height)
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        withContext { context in
            context.draw(image, in: bounds)
        }
    }

    /// Draws into the pixels with a y-down coordinate system (origin at the top left).
    mutating func draw(_ body: (CGContext) -> Void) {
        precondition(premultiplied)
        let height = self.height
        withContext { context in
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            body(context)
        }
    }

    private mutating func withContext(_ body: (CGContext) -> Void) {
        let (width, height) = (self.width, self.height)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            body(context)
        }
    }

    func cgImage() -> CGImage {
        precondition(premultiplied)
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )!
    }

    func cropped(to rect: CGRect) -> RGBAImage {
        let x0 = Int(rect.minX), y0 = Int(rect.minY)
        var result = RGBAImage(width: Int(rect.width), height: Int(rect.height), premultiplied: premultiplied)
        for y in 0..<result.height {
            let source = ((y0 + y) * width + x0) * 4
            let target = y * result.width * 4
            result.pixels.replaceSubrange(target..<(target + result.width * 4), with: pixels[source..<(source + result.width * 4)])
        }
        return result
    }

    func writePNG(to url: URL) throws {
        try NSBitmapImageRep(cgImage: cgImage()).representation(using: .png, properties: [:])!.write(to: url)
    }
}

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Can't read image at \(url.path)")
    }
    return image
}

/// Draws an image upright inside a y-down context.
func drawUpright(_ context: CGContext, _ image: CGImage, in rect: CGRect) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(origin: .zero, size: rect.size))
    context.restoreGState()
}

/// A grid of images on a near-black background, like the notch they'll appear in.
func contactSheet(_ rows: [[CGImage]], cell: Int) -> RGBAImage {
    let columns = rows.map(\.count).max() ?? 1
    let size = CGSize(width: columns * (cell + 8), height: rows.count * (cell + 8))
    var sheet = RGBAImage(width: Int(size.width), height: Int(size.height))
    sheet.draw { context in
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        for (row, images) in rows.enumerated() {
            for (column, image) in images.enumerated() {
                let rect = CGRect(x: column * (cell + 8) + 4, y: row * (cell + 8) + 4, width: cell, height: cell)
                context.setFillColor(CGColor(gray: 0.07, alpha: 1))
                context.fill(rect)
                context.interpolationQuality = .none
                drawUpright(context, image, in: rect)
            }
        }
    }
    return sheet
}
