import Foundation
import ImageIO

func littleEndian(_ value: Int) -> [UInt8] {
    [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]
}

/// GIF-flavoured LZW with variable code sizes (mirrors omggif's encoder).
func lzw(_ indices: [UInt8], minCodeSize: Int) -> [UInt8] {
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

/// Writes a looping GIF from palette-indexed frames. Index 0 is transparent and
/// every frame clears to the background, so transparent pixels never show the
/// previous frame.
func writeGIF(width: Int, height: Int, palette: [RGB], frames: [[UInt8]], delay: Double, to url: URL) throws {
    precondition(palette.count <= 256, "too many colors")
    var colors = palette
    var bits = 2
    while 1 << bits < colors.count { bits += 1 }
    while colors.count < 1 << bits { colors.append(RGB(r: 0, g: 0, b: 0)) }

    var out = Array("GIF89a".utf8)
    out += littleEndian(width)
    out += littleEndian(height)
    out += [0x80 | 0x70 | UInt8(bits - 1), 0, 0]
    for color in colors { out += [color.r, color.g, color.b] }
    // Loop forever.
    out += [0x21, 0xFF, 0x0B]
    out += Array("NETSCAPE2.0".utf8)
    out += [0x03, 0x01, 0x00, 0x00, 0x00]

    let centiseconds = Int((delay * 100).rounded())
    for data in frames {
        // Graphic control: dispose to background, transparent index 0.
        let control: [UInt8] = [0x21, 0xF9, 0x04, 0x09]
        out += control
        out += littleEndian(centiseconds)
        out += [0x00, 0x00]
        let descriptor: [UInt8] = [0x2C, 0, 0, 0, 0]
        out += descriptor
        out += littleEndian(width)
        out += littleEndian(height)
        out.append(0x00)
        out.append(UInt8(bits))
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
    try Data(out).write(to: url)
}

/// Decodes the GIF with ImageIO and checks that every frame's transparency
/// matches the indexed source (index 0 = transparent).
func verifyGIF(_ url: URL, width: Int, height: Int, frames: [[UInt8]]) -> Bool {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(source) == frames.count else { return false }
    for (index, frame) in frames.enumerated() {
        guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { return false }
        let decoded = RGBAImage(image)
        guard decoded.width == width, decoded.height == height else { return false }
        for i in 0..<(width * height) where (decoded.pixels[i * 4 + 3] > 127) != (frame[i] != 0) {
            return false
        }
    }
    return true
}
