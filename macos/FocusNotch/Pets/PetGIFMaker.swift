import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PetGIFError: Error {
    case unreadableImage
}

/// Turns the images a user picks for a custom pet into small looping GIFs.
///
/// Animated GIFs are kept as they are. Every other image (PNG, JPEG, HEIC, a
/// single-frame GIF…) can lose a flat background and gets the same motion per
/// mood as the bundled cute pets (PetForge's CutePets.swift). Keep in sync with
/// `gif-maker.js` on Windows.
enum PetGIFMaker {
    static let canvas = 160

    /// With `removeBackground`, a flat color filling the corners of a still image is made transparent.
    static func gifData(from url: URL, mood: PetMood, removeBackground: Bool = true) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw PetGIFError.unreadableImage
        }
        if CGImageSourceGetCount(source) > 1,
           let type = CGImageSourceGetType(source) as String?, UTType(type)?.conforms(to: .gif) == true {
            return try Data(contentsOf: url)
        }

        // Downsampling also applies the EXIF orientation of camera photos.
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: canvas * 2,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw PetGIFError.unreadableImage
        }
        return animate(removeBackground ? removingFlatBackground(image) ?? image : image, mood: mood)
    }

    // MARK: - Background removal

    /// How far (RGB distance) a pixel may be from the background color and still count as background.
    private static let backgroundTolerance = 48.0
    /// Edge pixels up to this much further away get partial transparency.
    private static let backgroundSoftness = 72.0

    /// When at least three corners share one opaque color, everything of that color
    /// connected to the border becomes transparent, the edges around it are softened,
    /// and the result is cropped to what's left. Nil when there's no such background.
    private static func removingFlatBackground(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        let count = width * height
        var pixels = [UInt8](repeating: 0, count: count * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        typealias Color = (r: Double, g: Double, b: Double)
        func color(_ i: Int) -> Color { (Double(pixels[i * 4]), Double(pixels[i * 4 + 1]), Double(pixels[i * 4 + 2])) }
        func distance(_ a: Color, _ b: Color) -> Double {
            ((a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b)).squareRoot()
        }

        let corners = [0, width - 1, (height - 1) * width, count - 1]
        guard corners.allSatisfy({ pixels[$0 * 4 + 3] > 250 }) else { return nil }
        let cornerColors = corners.map(color)
        let matching = cornerColors.map { candidate in cornerColors.filter { distance($0, candidate) < backgroundTolerance } }
            .max { $0.count < $1.count }!
        guard matching.count >= 3 else { return nil }
        let background: Color = (
            matching.map(\.r).reduce(0, +) / Double(matching.count),
            matching.map(\.g).reduce(0, +) / Double(matching.count),
            matching.map(\.b).reduce(0, +) / Double(matching.count)
        )

        // Flood fill from the border through background-colored pixels.
        var removed = [Bool](repeating: false, count: count)
        var stack: [Int] = []
        func visit(_ i: Int) {
            if !removed[i], distance(color(i), background) < backgroundTolerance {
                removed[i] = true
                stack.append(i)
            }
        }
        for x in 0..<width { visit(x); visit((height - 1) * width + x) }
        for y in 0..<height { visit(y * width); visit(y * width + width - 1) }
        while let i = stack.popLast() {
            let x = i % width, y = i / width
            if x > 0 { visit(i - 1) }
            if x < width - 1 { visit(i + 1) }
            if y > 0 { visit(i - width) }
            if y < height - 1 { visit(i + width) }
        }
        // A flat image with nothing on it: keep it as it is.
        guard removed.lazy.filter({ !$0 }).count > count / 50 else { return nil }

        var output = pixels
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                if removed[i] {
                    output.replaceSubrange((i * 4)..<(i * 4 + 4), with: [0, 0, 0, 0])
                    continue
                }
                var edge = false
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nx = x + dx, ny = y + dy
                        if nx >= 0, nx < width, ny >= 0, ny < height, removed[ny * width + nx] { edge = true }
                    }
                }
                if edge {
                    // Unmix the background from the pixel: premultiplied = pixel - (1 - alpha) * background.
                    let alpha = min(max((distance(color(i), background) - backgroundTolerance) / backgroundSoftness, 0), 1)
                    let p = color(i)
                    let channels = [p.r - (1 - alpha) * background.r, p.g - (1 - alpha) * background.g, p.b - (1 - alpha) * background.b]
                    for (k, value) in channels.enumerated() {
                        output[i * 4 + k] = UInt8(min(max(value, 0), 255 * alpha).rounded())
                    }
                    output[i * 4 + 3] = UInt8((255 * alpha).rounded())
                }
                if output[i * 4 + 3] > 20 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX else { return nil }

        let cropWidth = maxX - minX + 1, cropHeight = maxY - minY + 1
        var cropped = [UInt8](repeating: 0, count: cropWidth * cropHeight * 4)
        for row in 0..<cropHeight {
            let from = ((minY + row) * width + minX) * 4
            cropped.replaceSubrange((row * cropWidth * 4)..<((row + 1) * cropWidth * 4), with: output[from..<(from + cropWidth * 4)])
        }
        return CGImage(
            width: cropWidth, height: cropHeight, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: cropWidth * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(cropped) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    // MARK: - Animation

    private struct Motion {
        var dy: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var zs: [(origin: CGPoint, size: CGFloat)] = []
        var sparkles: [(center: CGPoint, radius: CGFloat, color: CGColor)] = []
    }

    private static let sparkleColors = [
        CGColor(srgbRed: 1, green: 0.84, blue: 0.37, alpha: 1),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        CGColor(srgbRed: 1, green: 0.56, blue: 0.72, alpha: 1),
        CGColor(srgbRed: 0.45, green: 0.92, blue: 0.75, alpha: 1),
    ]

    private static func timing(_ mood: PetMood) -> (frames: Int, delay: Double) {
        switch mood {
        case .idle: (16, 0.1)
        case .focus: (8, 0.11)
        case .rest: (16, 0.14)
        case .celebrate: (12, 0.07)
        }
    }

    private static func motion(_ mood: PetMood, _ index: Int, _ frames: Int, _ pose: CGRect) -> Motion {
        let phase = CGFloat(index) / CGFloat(frames)
        let wave = sin(phase * 2 * .pi)
        let size = CGFloat(canvas)
        switch mood {
        case .idle:
            // Slow breathing.
            return Motion(scaleX: 1 - 0.01 * wave, scaleY: 1 + 0.022 * wave)
        case .focus:
            // A light bounce, as if typing.
            return Motion(dy: index % 2 == 0 ? 0 : -1.2, scaleY: 1 + 0.012 * wave)
        case .rest:
            // Deep breathing with two z's drifting up.
            let start = CGPoint(x: min(pose.maxX - pose.width * 0.22, size - 34), y: max(pose.minY - 2, 30))
            let zs = [0, 0.5].map { (offset: CGFloat) -> (origin: CGPoint, size: CGFloat) in
                let t = (phase + offset).truncatingRemainder(dividingBy: 1)
                return (CGPoint(x: start.x + 14 * t, y: start.y - 26 * t), 7 + 8 * t)
            }
            return Motion(scaleX: 1 - 0.012 * wave, scaleY: 1 + 0.03 * wave, zs: zs)
        case .celebrate:
            // Hop with squash and stretch, surrounded by twinkling sparkles.
            let heights: [CGFloat] = [0, -4, -10, -14, -16, -16, -14, -10, -5, 0, 0, 0]
            let squash: [CGFloat] = [0.93, 1.04, 1.02, 1, 1, 1, 1, 1.01, 1.02, 0.94, 0.98, 1]
            let spots = [
                CGPoint(x: pose.minX + 4, y: pose.minY + 12),
                CGPoint(x: pose.maxX - 2, y: pose.minY + 22),
                CGPoint(x: pose.minX + 2, y: pose.maxY - 34),
                CGPoint(x: pose.maxX - 4, y: pose.maxY - 22),
            ]
            let sparkles = spots.enumerated().map { k, spot -> (center: CGPoint, radius: CGFloat, color: CGColor) in
                let twinkle = abs(sin((phase * 2 + CGFloat(k) * 0.25) * .pi))
                let point = CGPoint(x: min(max(spot.x, 8), size - 8), y: min(max(spot.y, 8), size - 8))
                return (point, 2.5 + 4 * twinkle, sparkleColors[k])
            }
            return Motion(dy: heights[index], scaleX: 2 - squash[index], scaleY: squash[index], sparkles: sparkles)
        }
    }

    private static func animate(_ image: CGImage, mood: PetMood) -> Data {
        let size = CGFloat(canvas)
        // The celebrate hop needs headroom; tiny images are pixel art and stay crisp.
        let headroom: CGFloat = mood == .celebrate ? 18 : 6
        let scale = min((size - 12) / CGFloat(image.width), (size - 4 - headroom) / CGFloat(image.height))
        let width = CGFloat(image.width) * scale, height = CGFloat(image.height) * scale
        let rect = CGRect(x: (size - width) / 2, y: size - 4 - height, width: width, height: height)
        let pixelArt = max(image.width, image.height) <= 64

        let (count, delay) = timing(mood)
        let frames = (0..<count).map { index in
            render(image, in: rect, motion: motion(mood, index, count, rect), pixelArt: pixelArt)
        }
        let (palette, indexed) = quantize(frames)
        return encodeGIF(width: canvas, height: canvas, palette: palette, frames: indexed, delay: delay)
    }

    /// One frame as premultiplied RGBA, drawn in a y-down coordinate system.
    private static func render(_ image: CGImage, in rect: CGRect, motion: Motion, pixelArt: Bool) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: canvas * canvas * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: canvas * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.translateBy(x: 0, y: CGFloat(canvas))
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = pixelArt ? .none : .high

            let placed = rect.offsetBy(dx: 0, dy: motion.dy)
            context.saveGState()
            context.translateBy(x: placed.midX, y: placed.maxY)
            context.scaleBy(x: motion.scaleX, y: -motion.scaleY)
            context.draw(image, in: CGRect(x: -placed.width / 2, y: 0, width: placed.width, height: placed.height))
            context.restoreGState()

            for (origin, size) in motion.zs {
                context.setStrokeColor(CGColor(srgbRed: 0.75, green: 0.85, blue: 1, alpha: 1))
                context.setLineWidth(size * 0.24)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.move(to: origin)
                context.addLine(to: CGPoint(x: origin.x + size, y: origin.y))
                context.addLine(to: CGPoint(x: origin.x, y: origin.y + size))
                context.addLine(to: CGPoint(x: origin.x + size, y: origin.y + size))
                context.strokePath()
            }
            for (center, radius, color) in motion.sparkles {
                context.move(to: CGPoint(x: center.x, y: center.y - radius))
                for step in 1..<8 {
                    let angle = CGFloat(step) * .pi / 4 - .pi / 2
                    let length = step.isMultiple(of: 2) ? radius : radius * 0.3
                    context.addLine(to: CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
                }
                context.closePath()
                context.setFillColor(color)
                context.fillPath()
            }
        }
        return pixels
    }

    // MARK: - Color quantization

    private struct RGB {
        var r: UInt8, g: UInt8, b: UInt8
    }

    /// Median-cut palette over 5-bit color buckets, shared by every frame. Index 0 is
    /// transparent; pixels below the alpha threshold use it.
    private static func quantize(_ frames: [[UInt8]], alphaThreshold: UInt8 = 102) -> (palette: [RGB], frames: [[UInt8]]) {
        struct Bucket {
            var key: Int
            var count = 0
            var sum = (r: 0.0, g: 0.0, b: 0.0)
            var mean: (r: Double, g: Double, b: Double) { (sum.r / Double(count), sum.g / Double(count), sum.b / Double(count)) }
        }

        func bucketKey(_ p: [UInt8], _ i: Int) -> Int {
            Int(p[i] >> 3) << 10 | Int(p[i + 1] >> 3) << 5 | Int(p[i + 2] >> 3)
        }

        var buckets: [Int: Bucket] = [:]
        for frame in frames {
            for i in stride(from: 0, to: frame.count, by: 4) where frame[i + 3] >= alphaThreshold {
                let key = bucketKey(frame, i)
                var bucket = buckets[key] ?? Bucket(key: key)
                bucket.count += 1
                bucket.sum.r += Double(frame[i])
                bucket.sum.g += Double(frame[i + 1])
                bucket.sum.b += Double(frame[i + 2])
                buckets[key] = bucket
            }
        }

        func channel(_ bucket: Bucket, _ axis: Int) -> Double {
            let mean = bucket.mean
            return axis == 0 ? mean.r : axis == 1 ? mean.g : mean.b
        }
        func longestAxis(_ box: [Bucket]) -> (axis: Int, range: Double) {
            (0..<3).map { axis in
                let values = box.map { channel($0, axis) }
                return (axis, (values.max() ?? 0) - (values.min() ?? 0))
            }.max { $0.range < $1.range }!
        }

        var boxes = buckets.isEmpty ? [] : [Array(buckets.values)]
        while boxes.count < 255 {
            let scored = boxes.enumerated()
                .filter { $0.element.count > 1 }
                .map { ($0.offset, longestAxis($0.element).range * Double($0.element.reduce(0) { $0 + $1.count })) }
            guard let (index, score) = scored.max(by: { $0.1 < $1.1 }), score > 0 else { break }
            let box = boxes.remove(at: index)
            let axis = longestAxis(box).axis
            let sorted = box.sorted { channel($0, axis) < channel($1, axis) }
            let total = sorted.reduce(0) { $0 + $1.count }
            var running = 0
            var split = 1
            for (i, bucket) in sorted.enumerated() {
                running += bucket.count
                if running * 2 >= total { split = max(1, min(i + 1, sorted.count - 1)); break }
            }
            boxes.append(Array(sorted[..<split]))
            boxes.append(Array(sorted[split...]))
        }

        let colors: [(r: Double, g: Double, b: Double)] = boxes.map { box in
            let count = Double(box.reduce(0) { $0 + $1.count })
            let sum = box.reduce((r: 0.0, g: 0.0, b: 0.0)) { ($0.r + $1.sum.r, $0.g + $1.sum.g, $0.b + $1.sum.b) }
            return (sum.r / count, sum.g / count, sum.b / count)
        }
        var lookup: [Int: UInt8] = [:]
        for bucket in buckets.values {
            let mean = bucket.mean
            var best = 0
            var bestDistance = Double.infinity
            for (index, color) in colors.enumerated() {
                let distance = (color.r - mean.r) * (color.r - mean.r) + (color.g - mean.g) * (color.g - mean.g)
                    + (color.b - mean.b) * (color.b - mean.b)
                if distance < bestDistance { bestDistance = distance; best = index }
            }
            lookup[bucket.key] = UInt8(best + 1)
        }

        let palette = [RGB(r: 0, g: 0, b: 0)] + colors.map {
            RGB(r: UInt8($0.r.rounded()), g: UInt8($0.g.rounded()), b: UInt8($0.b.rounded()))
        }
        let indexed = frames.map { frame in
            stride(from: 0, to: frame.count, by: 4).map { i in
                frame[i + 3] >= alphaThreshold ? lookup[bucketKey(frame, i)]! : 0
            }
        }
        return (palette, indexed)
    }

    // MARK: - GIF encoding

    private static func littleEndian(_ value: Int) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]
    }

    /// GIF-flavoured LZW with variable code sizes.
    private static func lzw(_ indices: [UInt8], minCodeSize: Int) -> [UInt8] {
        let clearCode = 1 << minCodeSize
        let endCode = clearCode + 1
        var nextCode = endCode + 1
        var codeSize = minCodeSize + 1
        var table: [Int: Int] = [:]
        var output: [UInt8] = []
        var buffer = 0
        var bufferedBits = 0

        func emit(_ code: Int) {
            buffer |= code << bufferedBits
            bufferedBits += codeSize
            while bufferedBits >= 8 {
                output.append(UInt8(buffer & 0xFF))
                buffer >>= 8
                bufferedBits -= 8
            }
        }

        emit(clearCode)
        var prefix = Int(indices[0])
        for k in indices.dropFirst() {
            let key = prefix << 8 | Int(k)
            if let code = table[key] {
                prefix = code
                continue
            }
            emit(prefix)
            if nextCode == 4096 {
                emit(clearCode)
                nextCode = endCode + 1
                codeSize = minCodeSize + 1
                table.removeAll()
            } else {
                if nextCode >= 1 << codeSize { codeSize += 1 }
                table[key] = nextCode
                nextCode += 1
            }
            prefix = Int(k)
        }
        emit(prefix)
        emit(endCode)
        if bufferedBits > 0 { output.append(UInt8(buffer & 0xFF)) }
        return output
    }

    /// A looping GIF where index 0 is transparent and every frame clears to the
    /// background, so transparent pixels never show the previous frame.
    private static func encodeGIF(width: Int, height: Int, palette: [RGB], frames: [[UInt8]], delay: Double) -> Data {
        var colors = palette
        var bits = 2
        while 1 << bits < colors.count { bits += 1 }
        while colors.count < 1 << bits { colors.append(RGB(r: 0, g: 0, b: 0)) }

        var out = Array("GIF89a".utf8)
        out += littleEndian(width) + littleEndian(height)
        out += [0x80 | 0x70 | UInt8(bits - 1), 0, 0]
        for color in colors { out += [color.r, color.g, color.b] }
        out += [0x21, 0xFF, 0x0B] + Array("NETSCAPE2.0".utf8) + [0x03, 0x01, 0x00, 0x00, 0x00]

        let centiseconds = Int((delay * 100).rounded())
        for data in frames {
            out += [0x21, 0xF9, 0x04, 0x09] + littleEndian(centiseconds) + [0x00, 0x00]
            out += [0x2C, 0, 0, 0, 0] + littleEndian(width) + littleEndian(height) + [0x00, UInt8(bits)]
            let compressed = lzw(data, minCodeSize: bits)
            var offset = 0
            while offset < compressed.count {
                let count = min(255, compressed.count - offset)
                out.append(UInt8(count))
                out += compressed[offset..<(offset + count)]
                offset += count
            }
            out.append(0)
        }
        out.append(0x3B)
        return Data(out)
    }
}
