import ImageIO
import SwiftUI

/// Decoded GIF frames with their delays. Instances are cached per file.
final class GIFAnimation {
    let frames: [CGImage]
    let delays: [TimeInterval]
    let duration: TimeInterval

    private static var cache: [URL: GIFAnimation] = [:]

    /// Large custom GIFs are downsampled so a long animation doesn't hold
    /// hundreds of megabytes of full-size frames.
    static func load(_ url: URL, maxPixelSize: Int? = nil) -> GIFAnimation? {
        if let cached = cache[url] { return cached }
        guard let animation = GIFAnimation(url: url, maxPixelSize: maxPixelSize) else { return nil }
        cache[url] = animation
        return animation
    }

    private init?(url: URL, maxPixelSize: Int?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = min(CGImageSourceGetCount(source), 400)
        guard count > 0 else { return nil }

        let thumbnailOptions: CFDictionary? = maxPixelSize.map {
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: $0,
            ] as CFDictionary
        }

        var frames: [CGImage] = []
        var delays: [TimeInterval] = []
        for index in 0..<count {
            let image = thumbnailOptions.map { CGImageSourceCreateThumbnailAtIndex(source, index, $0) }
                ?? CGImageSourceCreateImageAtIndex(source, index, nil)
            guard let image else { continue }
            frames.append(image)
            delays.append(Self.delay(of: source, at: index))
        }
        guard !frames.isEmpty else { return nil }

        self.frames = frames
        self.delays = delays
        self.duration = delays.reduce(0, +)
    }

    var minimumDelay: TimeInterval { delays.min() ?? 0.1 }

    func frame(at date: Date) -> CGImage {
        guard frames.count > 1, duration > 0 else { return frames[0] }
        var time = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
        for (index, delay) in delays.enumerated() {
            if time < delay { return frames[index] }
            time -= delay
        }
        return frames[frames.count - 1]
    }

    private static func delay(of source: CGImageSource, at index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0.1
        // Browsers treat near-zero delays as 100 ms; do the same.
        return delay < 0.02 ? 0.1 : delay
    }
}

struct AnimatedGIFView: View {
    let url: URL?
    var pixelated = true

    var body: some View {
        if let url, let animation = GIFAnimation.load(url, maxPixelSize: pixelated ? nil : 256) {
            TimelineView(.animation(minimumInterval: animation.minimumDelay, paused: animation.frames.count < 2)) { context in
                Image(decorative: animation.frame(at: context.date), scale: 1)
                    .resizable()
                    .interpolation(pixelated ? .none : .high)
                    .antialiased(!pixelated)
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            Image(systemName: "pawprint.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(6)
        }
    }
}

/// The selected pet in the given mood, or a phase symbol when pets are turned off.
struct PetView: View {
    let pet: Pet?
    let mood: PetMood
    var fallbackSymbol = "timer"
    var tint: Color = .white

    var body: some View {
        if let pet {
            AnimatedGIFView(url: pet.url(for: mood), pixelated: pet.isPixelArt)
        } else {
            Image(systemName: fallbackSymbol)
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .foregroundStyle(tint)
                .padding(4)
        }
    }
}
