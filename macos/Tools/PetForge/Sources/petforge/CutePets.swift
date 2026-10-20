import AppKit
import Foundation

// Turns Codex-generated character sheets into small animated GIFs. Each sheet is a
// 2×2 grid on a flat magenta background: idle, focus (top), rest, celebrate (bottom).

let cuteCanvas = 160
let cutePetNames = ["cat", "dog", "bunny", "fox", "panda", "frog", "hamster", "penguin", "owl", "koala", "duck", "hedgehog"]

// MARK: - Background removal

/// Removes the magenta background. Pixels close to pure magenta become fully
/// transparent; pixels bordering them get a soft alpha from how magenta they look,
/// with the magenta spill subtracted from their color.
func removeMagenta(_ image: RGBAImage) -> RGBAImage {
    let (width, height) = (image.width, image.height)
    let source = image.pixels
    var alpha = [Float](repeating: 1, count: width * height)

    for i in 0..<(width * height) {
        let r = Float(source[i * 4]), g = Float(source[i * 4 + 1]), b = Float(source[i * 4 + 2])
        let distance = ((r - 255) * (r - 255) + g * g + (b - 255) * (b - 255)).squareRoot()
        if distance < 90 { alpha[i] = 0 }
    }

    var output = RGBAImage(width: width, height: height)
    for y in 0..<height {
        for x in 0..<width {
            let i = y * width + x
            guard alpha[i] > 0 else { continue }
            var r = Float(source[i * 4]), g = Float(source[i * 4 + 1]), b = Float(source[i * 4 + 2])
            var a: Float = 1
            if touchesBackground(alpha, x, y, width, height) {
                let magentaness = min(r, b) - g
                a = 1 - min(max((magentaness - 40) / 190, 0), 1)
                if a > 0 {
                    r = min(max((r - (1 - a) * 255) / a, 0), 255)
                    g = min(max(g / a, 0), 255)
                    b = min(max((b - (1 - a) * 255) / a, 0), 255)
                }
            }
            output.pixels[i * 4] = UInt8(r * a)
            output.pixels[i * 4 + 1] = UInt8(g * a)
            output.pixels[i * 4 + 2] = UInt8(b * a)
            output.pixels[i * 4 + 3] = UInt8(a * 255)
        }
    }
    return output
}

private func touchesBackground(_ alpha: [Float], _ x: Int, _ y: Int, _ width: Int, _ height: Int) -> Bool {
    for dy in -2...2 {
        for dx in -2...2 {
            let nx = x + dx, ny = y + dy
            if nx >= 0, nx < width, ny >= 0, ny < height, alpha[ny * width + nx] == 0 { return true }
        }
    }
    return false
}

/// Bounding box of the visible content, ignoring stray specks.
func contentBounds(_ image: RGBAImage) -> CGRect {
    var rows = [Int](repeating: 0, count: image.height)
    var columns = [Int](repeating: 0, count: image.width)
    for y in 0..<image.height {
        for x in 0..<image.width where image.pixels[(y * image.width + x) * 4 + 3] > 20 {
            rows[y] += 1
            columns[x] += 1
        }
    }
    let minY = rows.firstIndex { $0 >= 3 } ?? 0
    let maxY = rows.lastIndex { $0 >= 3 } ?? image.height - 1
    let minX = columns.firstIndex { $0 >= 3 } ?? 0
    let maxX = columns.lastIndex { $0 >= 3 } ?? image.width - 1
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

/// The four poses of a sheet (reading order), each cropped to its content.
///
/// Poses can poke out of their quadrant (a raised ear reaching into the cell
/// above), so pixels are grouped into connected shapes and every shape goes to
/// the quadrant holding its center. Tiny specks are dropped.
func splitPoses(_ sheet: RGBAImage) -> [RGBAImage] {
    let (width, height) = (sheet.width, sheet.height)
    var label = [Int32](repeating: -1, count: width * height)
    var quadrantOfLabel: [Int] = []
    var stack: [Int] = []

    for start in 0..<(width * height) where label[start] == -1 && sheet.pixels[start * 4 + 3] > 20 {
        let id = Int32(quadrantOfLabel.count)
        var members: [Int] = []
        label[start] = id
        stack.append(start)
        while let i = stack.popLast() {
            members.append(i)
            let x = i % width, y = i / width
            for dy in -1...1 {
                for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let n = ny * width + nx
                    if label[n] == -1, sheet.pixels[n * 4 + 3] > 20 {
                        label[n] = id
                        stack.append(n)
                    }
                }
            }
        }
        let centerX = members.reduce(0) { $0 + $1 % width } / members.count
        let centerY = members.reduce(0) { $0 + $1 / width } / members.count
        let quadrant = (centerY < height / 2 ? 0 : 2) + (centerX < width / 2 ? 0 : 1)
        quadrantOfLabel.append(members.count < 150 ? -1 : quadrant)
    }

    return (0..<4).map { quadrant in
        var pose = RGBAImage(width: width, height: height)
        for i in 0..<(width * height) where label[i] >= 0 && quadrantOfLabel[Int(label[i])] == quadrant {
            pose.pixels.replaceSubrange((i * 4)..<(i * 4 + 4), with: sheet.pixels[(i * 4)..<(i * 4 + 4)])
        }
        return pose.cropped(to: contentBounds(pose))
    }
}

// MARK: - Animation

struct Motion {
    var dy: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var effects: [CuteEffect] = []
}

enum CuteEffect {
    case z(CGPoint, size: CGFloat)
    case sparkle(CGPoint, radius: CGFloat, color: CGColor)
}

struct CuteAnimation {
    let mood: String
    let frameCount: Int
    let delay: Double
    /// Motion for frame `index`, given where the pose sits on the canvas.
    let motion: (_ index: Int, _ pose: CGRect) -> Motion
}

private func phase(_ index: Int, _ count: Int) -> CGFloat {
    CGFloat(index) / CGFloat(count)
}

let cuteAnimations = [
    // Slow breathing.
    CuteAnimation(mood: "idle", frameCount: 16, delay: 0.1) { index, _ in
        let wave = sin(phase(index, 16) * 2 * .pi)
        return Motion(scaleX: 1 - 0.01 * wave, scaleY: 1 + 0.022 * wave)
    },
    // A light bounce, as if typing.
    CuteAnimation(mood: "focus", frameCount: 8, delay: 0.11) { index, _ in
        let wave = sin(phase(index, 8) * 2 * .pi)
        return Motion(dy: index % 2 == 0 ? 0 : -1.2, scaleY: 1 + 0.012 * wave)
    },
    // Deep breathing with two z's drifting up.
    CuteAnimation(mood: "rest", frameCount: 16, delay: 0.14) { index, pose in
        let wave = sin(phase(index, 16) * 2 * .pi)
        let effects: [CuteEffect] = [0, 0.5].map { offset in
            let t = (phase(index, 16) + offset).truncatingRemainder(dividingBy: 1)
            let start = CGPoint(x: min(pose.maxX - pose.width * 0.22, CGFloat(cuteCanvas) - 34), y: max(pose.minY - 2, 30))
            return .z(CGPoint(x: start.x + 14 * t, y: start.y - 26 * t), size: 7 + 8 * t)
        }
        return Motion(scaleX: 1 - 0.012 * wave, scaleY: 1 + 0.03 * wave, effects: effects)
    },
    // Hop with squash and stretch, surrounded by twinkling sparkles.
    CuteAnimation(mood: "celebrate", frameCount: 12, delay: 0.07) { index, pose in
        let heights: [CGFloat] = [0, -4, -10, -14, -16, -16, -14, -10, -5, 0, 0, 0]
        let squash: [CGFloat] = [0.93, 1.04, 1.02, 1, 1, 1, 1, 1.01, 1.02, 0.94, 0.98, 1]
        let colors = [
            CGColor(srgbRed: 1, green: 0.84, blue: 0.37, alpha: 1),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
            CGColor(srgbRed: 1, green: 0.56, blue: 0.72, alpha: 1),
            CGColor(srgbRed: 0.45, green: 0.92, blue: 0.75, alpha: 1),
        ]
        let spots = [
            CGPoint(x: pose.minX + 4, y: pose.minY + 12),
            CGPoint(x: pose.maxX - 2, y: pose.minY + 22),
            CGPoint(x: pose.minX + 2, y: pose.maxY - 34),
            CGPoint(x: pose.maxX - 4, y: pose.maxY - 22),
        ]
        let edge = CGFloat(cuteCanvas) - 8
        let effects: [CuteEffect] = spots.enumerated().map { k, spot in
            let twinkle = abs(sin((phase(index, 12) * 2 + CGFloat(k) * 0.25) * .pi))
            let point = CGPoint(x: min(max(spot.x, 8), edge), y: min(max(spot.y, 8), edge))
            return .sparkle(point, radius: 2.5 + 4 * twinkle, color: colors[k])
        }
        return Motion(dy: heights[index], scaleX: 2 - squash[index], scaleY: squash[index], effects: effects)
    },
]

func renderCuteFrame(_ pose: CGImage, in rect: CGRect, motion: Motion) -> RGBAImage {
    var frame = RGBAImage(width: cuteCanvas, height: cuteCanvas)
    frame.draw { context in
        let placed = rect.offsetBy(dx: 0, dy: motion.dy)
        let anchor = CGPoint(x: placed.midX, y: placed.maxY)
        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.scaleBy(x: motion.scaleX, y: motion.scaleY)
        context.translateBy(x: -anchor.x, y: -anchor.y)
        drawUpright(context, pose, in: placed)
        context.restoreGState()

        for effect in motion.effects {
            switch effect {
            case let .z(origin, size):
                context.setStrokeColor(CGColor(srgbRed: 0.75, green: 0.85, blue: 1, alpha: 1))
                context.setLineWidth(size * 0.24)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.move(to: origin)
                context.addLine(to: CGPoint(x: origin.x + size, y: origin.y))
                context.addLine(to: CGPoint(x: origin.x, y: origin.y + size))
                context.addLine(to: CGPoint(x: origin.x + size, y: origin.y + size))
                context.strokePath()
            case let .sparkle(center, radius, color):
                let inner = radius * 0.3
                context.move(to: CGPoint(x: center.x, y: center.y - radius))
                for step in 1..<8 {
                    let angle = CGFloat(step) * .pi / 4 - .pi / 2
                    let length = step.isMultiple(of: 2) ? radius : inner
                    context.addLine(to: CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
                }
                context.closePath()
                context.setFillColor(color)
                context.fillPath()
            }
        }
    }
    return frame
}

// MARK: - Color quantization

/// Median-cut palette over 5-bit color buckets, shared by every frame of one GIF.
/// Opaque-enough pixels keep their premultiplied color, i.e. their edges are already
/// blended toward black — the color of the notch they're shown on.
func quantize(_ frames: [RGBAImage], alphaThreshold: UInt8 = 102) -> (palette: [RGB], frames: [[UInt8]]) {
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
        for i in stride(from: 0, to: frame.pixels.count, by: 4) where frame.pixels[i + 3] >= alphaThreshold {
            let key = bucketKey(frame.pixels, i)
            var bucket = buckets[key] ?? Bucket(key: key)
            bucket.count += 1
            bucket.sum.r += Double(frame.pixels[i])
            bucket.sum.g += Double(frame.pixels[i + 1])
            bucket.sum.b += Double(frame.pixels[i + 2])
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

    var boxes = [Array(buckets.values)]
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
        stride(from: 0, to: frame.pixels.count, by: 4).map { i in
            frame.pixels[i + 3] >= alphaThreshold ? lookup[bucketKey(frame.pixels, i)]! : 0
        }
    }
    return (palette, indexed)
}

// MARK: - Output

/// Writes `cute_<pet>_<mood>.gif` for every sheet in `artDirectory`. Returns one row of frames per GIF for previews.
func generateCutePets(from artDirectory: URL, into directory: URL) throws -> [[CGImage]] {
    var rows: [[CGImage]] = []
    for name in cutePetNames {
        let sheet = removeMagenta(RGBAImage(loadImage(artDirectory.appendingPathComponent("\(name).png"))))
        let poses = splitPoses(sheet)

        // One scale for the grounded poses keeps the character the same size between
        // moods. The celebrate pose needs headroom for its hop, so it only shrinks
        // further when it wouldn't fit otherwise.
        let canvas = CGFloat(cuteCanvas)
        func fit(_ pose: RGBAImage, headroom: CGFloat) -> CGFloat {
            min((canvas - 12) / CGFloat(pose.width), (canvas - 4 - headroom) / CGFloat(pose.height))
        }
        let scale = poses.prefix(3).map { fit($0, headroom: 6) }.min()!

        for (index, (pose, animation)) in zip(poses, cuteAnimations).enumerated() {
            let poseScale = index == 3 ? min(scale, fit(pose, headroom: 18)) : scale
            let size = CGSize(width: CGFloat(pose.width) * poseScale, height: CGFloat(pose.height) * poseScale)
            let rect = CGRect(x: (CGFloat(cuteCanvas) - size.width) / 2, y: CGFloat(cuteCanvas) - 4 - size.height,
                              width: size.width, height: size.height)
            let image = pose.cgImage()
            let frames = (0..<animation.frameCount).map { index in
                renderCuteFrame(image, in: rect, motion: animation.motion(index, rect))
            }
            let (palette, indexed) = quantize(frames)
            let url = directory.appendingPathComponent("cute_\(name)_\(animation.mood).gif")
            try writeGIF(width: cuteCanvas, height: cuteCanvas, palette: palette, frames: indexed, delay: animation.delay, to: url)
            guard verifyGIF(url, width: cuteCanvas, height: cuteCanvas, frames: indexed) else {
                fatalError("GIF round-trip failed for \(url.lastPathComponent)")
            }
            rows.append(frames.map { $0.cgImage() })
        }
        print("  \(name)")
    }
    return rows
}
