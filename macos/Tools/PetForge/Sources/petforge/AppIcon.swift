import AppKit
import Foundation

/// Builds the AppIcon set from Codex artwork: a squircle tile on a flat magenta
/// background. The tile is cut out and placed on Apple's 1024 pt icon grid.
func generateAppIcon(from art: URL, into directory: URL) throws -> CGImage {
    let tile = cutOutTile(RGBAImage(loadImage(art)))

    var master = RGBAImage(width: 1024, height: 1024)
    master.draw { context in
        let side: CGFloat = 824
        let aspect = CGFloat(tile.width) / CGFloat(tile.height)
        let size = aspect >= 1 ? CGSize(width: side, height: side / aspect) : CGSize(width: side * aspect, height: side)
        let rect = CGRect(x: (1024 - size.width) / 2, y: (1024 - size.height) / 2, width: size.width, height: size.height)
        // Shadow offsets ignore the flipped transform, so a negative y points down.
        context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
        drawUpright(context, tile, in: rect)
    }
    let masterImage = master.cgImage()

    let sizes = [(16, "16x16", "1x"), (32, "16x16", "2x"), (32, "32x32", "1x"), (64, "32x32", "2x"),
                 (128, "128x128", "1x"), (256, "128x128", "2x"), (256, "256x256", "1x"), (512, "256x256", "2x"),
                 (512, "512x512", "1x"), (1024, "512x512", "2x")]
    var entries: [[String: String]] = []
    for (pixels, size, scale) in sizes {
        var icon = RGBAImage(width: pixels, height: pixels)
        icon.draw { context in
            drawUpright(context, masterImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        }
        let fileName = "icon_\(size)@\(scale).png"
        try icon.writePNG(to: directory.appendingPathComponent(fileName))
        entries.append(["filename": fileName, "idiom": "mac", "scale": scale, "size": size])
    }
    let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("Contents.json"))
    return masterImage
}

/// The artwork's rounded tile without the magenta around it. The tile uses pinks
/// close to the background color, so rather than keying by color this flood-fills
/// the background from the image edges, then trims the tile with a clean rounded
/// rectangle whose corner radius is measured from the art.
private func cutOutTile(_ art: RGBAImage) -> CGImage {
    let (width, height) = (art.width, art.height)
    func isMagenta(_ i: Int) -> Bool {
        let r = Int(art.pixels[i * 4]), g = Int(art.pixels[i * 4 + 1]), b = Int(art.pixels[i * 4 + 2])
        return (r - 255) * (r - 255) + g * g + (b - 255) * (b - 255) < 60 * 60
    }

    var background = [Bool](repeating: false, count: width * height)
    var stack: [Int] = []
    for x in 0..<width { stack += [x, (height - 1) * width + x] }
    for y in 0..<height { stack += [y * width, y * width + width - 1] }
    while let i = stack.popLast() {
        guard !background[i], isMagenta(i) else { continue }
        background[i] = true
        let x = i % width, y = i / width
        if x > 0 { stack.append(i - 1) }
        if x < width - 1 { stack.append(i + 1) }
        if y > 0 { stack.append(i - width) }
        if y < height - 1 { stack.append(i + width) }
    }

    var bounds = (minX: width, minY: height, maxX: 0, maxY: 0)
    for y in 0..<height {
        for x in 0..<width where !background[y * width + x] {
            bounds = (min(bounds.minX, x), min(bounds.minY, y), max(bounds.maxX, x), max(bounds.maxY, y))
        }
    }
    let rect = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.maxX - bounds.minX + 1, height: bounds.maxY - bounds.minY + 1)

    // The straight part of the top edge starts one corner radius in from the side.
    let topRow = (bounds.minY + 1) * width
    let edgeStart = (bounds.minX..<bounds.maxX).first { !background[topRow + $0] } ?? bounds.minX
    let side = min(rect.width, rect.height)
    let radius = min(max(CGFloat(edgeStart - bounds.minX) + 2, side * 0.12), side * 0.3)

    let crop = art.cropped(to: rect).cgImage()
    var tile = RGBAImage(width: Int(rect.width), height: Int(rect.height))
    tile.draw { context in
        let frame = CGRect(origin: .zero, size: rect.size)
        context.addPath(CGPath(roundedRect: frame.insetBy(dx: 2, dy: 2), cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        drawUpright(context, crop, in: frame)
    }
    return tile.cgImage()
}
