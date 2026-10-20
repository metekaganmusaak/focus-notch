import AppKit
import Foundation

// Procedurally drawn 32×32 pixel-art pets.

// MARK: - Canvas

struct RGB: Hashable {
    var r: UInt8, g: UInt8, b: UInt8
}

func hex(_ value: UInt32) -> RGB {
    RGB(r: UInt8(value >> 16 & 0xFF), g: UInt8(value >> 8 & 0xFF), b: UInt8(value & 0xFF))
}

typealias Point = (x: Double, y: Double)

let side = 32

/// Mirrors a continuous x coordinate around the sprite's vertical center line.
func mx(_ x: Double) -> Double { Double(side) - x }
/// Mirrors a pixel column around the sprite's vertical center line.
func mi(_ x: Int) -> Int { side - 1 - x }

struct Canvas {
    var pixels = [RGB?](repeating: nil, count: side * side)

    subscript(x: Int, y: Int) -> RGB? {
        get { x >= 0 && x < side && y >= 0 && y < side ? pixels[y * side + x] : nil }
        set { if x >= 0 && x < side && y >= 0 && y < side { pixels[y * side + x] = newValue } }
    }

    func filled(_ x: Int, _ y: Int) -> Bool { self[x, y] != nil }

    mutating func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ color: RGB) {
        for y in 0..<side {
            for x in 0..<side {
                let dx = (Double(x) + 0.5 - cx) / rx
                let dy = (Double(y) + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1 { self[x, y] = color }
            }
        }
    }

    mutating func triangle(_ a: Point, _ b: Point, _ c: Point, _ color: RGB) {
        func edge(_ p: Point, _ q: Point, _ r: Point) -> Double {
            (p.x - r.x) * (q.y - r.y) - (q.x - r.x) * (p.y - r.y)
        }
        for y in 0..<side {
            for x in 0..<side {
                let p: Point = (Double(x) + 0.5, Double(y) + 0.5)
                let d1 = edge(p, a, b), d2 = edge(p, b, c), d3 = edge(p, c, a)
                let hasNegative = d1 < 0 || d2 < 0 || d3 < 0
                let hasPositive = d1 > 0 || d2 > 0 || d3 > 0
                if !(hasNegative && hasPositive) { self[x, y] = color }
            }
        }
    }

    /// A thick line along a polyline, stamped with discs.
    mutating func stroke(_ points: [Point], radius: Double, _ color: RGB) {
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let steps = max(Int(hypot(b.x - a.x, b.y - a.y) * 4), 1)
            for s in 0...steps {
                let t = Double(s) / Double(steps)
                ellipse(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, radius, radius, color)
            }
        }
    }

    mutating func rect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: RGB) {
        for y in y0...y1 { for x in x0...x1 { self[x, y] = color } }
    }

    mutating func dots(_ points: [(Int, Int)], _ color: RGB) {
        for p in points { self[p.0, p.1] = color }
    }

    /// Same dots plus their mirror image on the other side of the face.
    mutating func mirroredDots(_ points: [(Int, Int)], _ color: RGB) {
        dots(points, color)
        dots(points.map { (mi($0.0), $0.1) }, color)
    }

    /// Darkens the bottom and right rim of `base` pixels to give the shape some volume.
    mutating func shade(_ base: RGB, with shade: RGB) {
        let copy = self
        for y in 0..<side {
            for x in 0..<side where copy[x, y] == base {
                if !copy.filled(x, y + 1) || !copy.filled(x + 1, y) {
                    self[x, y] = shade
                }
            }
        }
    }

    /// Adds a 1 px outline around everything drawn so far.
    mutating func outline(_ color: RGB) {
        let copy = self
        for y in 0..<side {
            for x in 0..<side where !copy.filled(x, y) {
                if copy.filled(x - 1, y) || copy.filled(x + 1, y) || copy.filled(x, y - 1) || copy.filled(x, y + 1) {
                    self[x, y] = color
                }
            }
        }
    }

    mutating func draw(_ other: Canvas, dx: Int = 0, dy: Int = 0) {
        for y in 0..<side {
            for x in 0..<side {
                if let p = other[x, y] { self[x + dx, y + dy] = p }
            }
        }
    }
}

// MARK: - Pets

struct Palette {
    var base: RGB
    var shade: RGB
    var light: RGB
    var accent: RGB
    var outline: RGB
    var eye = hex(0x22182A)
    var nose: RGB
    var blush = hex(0xFF8FA6)
}

enum Eyes { case open, blink, closed, happy, down }

struct Pose {
    var dy = 0
    var headDy = 0
    var breath = 0.0
    var eyes = Eyes.open
    var mouthOpen = false
    var tail = 0.0
    var earTwitch = false
    var armsUp = false
    var typing: Int?
    var effects: [Effect] = []
}

enum Effect {
    case z(x: Int, y: Int, big: Bool)
    case sparkle(x: Int, y: Int, color: RGB)
    case heart(x: Int, y: Int)
}

struct PetSpec {
    var name: String
    var palette: Palette
    var pawColor: RGB
    /// Color of the paws raised while celebrating; defaults to `pawColor`.
    var armColor: RGB?
    /// Ears that share the head's silhouette (drawn before the head outline).
    var ears: (inout Canvas, Pose) -> Void = { _, _ in }
    /// Patterns on the head (muzzle, patches) drawn before the outline.
    var headMarkings: (inout Canvas, Pose) -> Void = { _, _ in }
    /// Ears drawn on top of the head with their own outline (floppy ears).
    var frontEars: ((inout Canvas, Pose) -> Void)?
    var tail: ((inout Canvas, Pose) -> Void)?
    var bodyMarkings: (inout Canvas, Pose) -> Void = { _, _ in }
    /// Overrides the default nose and mouth.
    var mouth: ((inout Canvas, Pose) -> Void)?
    var eyeTop = 14
    /// Panda eyes sit in dark patches, so they need a light rim to read.
    var eyeHighlight = hex(0xFFFFFF)
}

let headCenter: Point = (16, 15)
let headRadius: Point = (9.4, 7.3)

func renderFrame(_ pet: PetSpec, _ pose: Pose) -> Canvas {
    let p = pet.palette
    var frame = Canvas()

    if let tail = pet.tail {
        var layer = Canvas()
        tail(&layer, pose)
        layer.shade(p.base, with: p.shade)
        layer.outline(p.outline)
        frame.draw(layer, dy: pose.dy)
    }

    var body = Canvas()
    body.ellipse(16, 25, 7.0, 5.0 + pose.breath, p.base)
    body.shade(p.base, with: p.shade)
    pet.bodyMarkings(&body, pose)
    body.outline(p.outline)
    frame.draw(body, dy: pose.dy)

    if !pose.armsUp && pose.typing == nil {
        var paws = Canvas()
        paws.ellipse(12.5, 29.6, 2.3, 1.4, pet.pawColor)
        paws.ellipse(mx(12.5), 29.6, 2.3, 1.4, pet.pawColor)
        paws.outline(p.outline)
        frame.draw(paws, dy: pose.dy)
    } else if pose.armsUp {
        var paws = Canvas()
        paws.ellipse(12.5, 29.8, 2.2, 1.2, pet.pawColor)
        paws.ellipse(mx(12.5), 29.8, 2.2, 1.2, pet.pawColor)
        paws.outline(p.outline)
        frame.draw(paws, dy: pose.dy)
    }

    var head = Canvas()
    pet.ears(&head, pose)
    head.ellipse(headCenter.x, headCenter.y, headRadius.x, headRadius.y, p.base)
    head.shade(p.base, with: p.shade)
    pet.headMarkings(&head, pose)
    head.outline(p.outline)
    if let frontEars = pet.frontEars {
        var ears = Canvas()
        frontEars(&ears, pose)
        ears.outline(p.outline)
        head.draw(ears)
    }
    drawFace(&head, pet, pose)
    frame.draw(head, dy: pose.dy + pose.headDy)

    if pose.armsUp {
        var arms = Canvas()
        let color = pet.armColor ?? pet.pawColor
        arms.ellipse(5.2, 18.5, 2.0, 2.2, color)
        arms.ellipse(mx(5.2), 18.5, 2.0, 2.2, color)
        arms.outline(p.outline)
        frame.draw(arms, dy: pose.dy)
    }

    if let typing = pose.typing {
        drawLaptop(&frame, pet, typing: typing)
    }

    for effect in pose.effects {
        drawEffect(&frame, effect)
    }
    return frame
}

func drawFace(_ c: inout Canvas, _ pet: PetSpec, _ pose: Pose) {
    let p = pet.palette
    let ex = 11, ey = pet.eyeTop
    switch pose.eyes {
    case .open:
        for (x, hx) in [(ex, ex), (mi(ex + 1), mi(ex + 1))] {
            c.rect(x, ey, x + 1, ey + 2, p.eye)
            c[hx, ey] = pet.eyeHighlight
        }
    case .down:
        c.rect(ex, ey + 1, ex + 1, ey + 2, p.eye)
        c.rect(mi(ex + 1), ey + 1, mi(ex), ey + 2, p.eye)
    case .blink:
        c.rect(ex - 1, ey + 2, ex + 2, ey + 2, p.eye)
        c.rect(mi(ex + 2), ey + 2, mi(ex - 1), ey + 2, p.eye)
    case .closed:
        c.mirroredDots([(ex - 1, ey + 1), (ex, ey + 2), (ex + 1, ey + 2), (ex + 2, ey + 1)], p.eye)
    case .happy:
        c.mirroredDots([(ex - 1, ey + 2), (ex, ey + 1), (ex + 1, ey + 1), (ex + 2, ey + 2)], p.eye)
    }

    c.mirroredDots([(ex - 2, ey + 3), (ex - 1, ey + 3)], p.blush)

    if let mouth = pet.mouth {
        mouth(&c, pose)
        return
    }
    c.dots([(15, ey + 3), (16, ey + 3)], p.nose)
    if pose.mouthOpen {
        c.dots([(15, ey + 4), (16, ey + 4)], p.eye)
        c.dots([(15, ey + 5), (16, ey + 5)], hex(0xFF6F8E))
    } else {
        c.dots([(14, ey + 4), (mi(14), ey + 4)], p.eye)
    }
}

func drawLaptop(_ c: inout Canvas, _ pet: PetSpec, typing: Int) {
    let edge = hex(0x4A5163)
    var paws = Canvas()
    paws.ellipse(10.5, 21.6 + Double(typing), 2.1, 1.5, pet.pawColor)
    paws.ellipse(mx(10.5), 21.6 + Double(1 - typing), 2.1, 1.5, pet.pawColor)
    paws.outline(pet.palette.outline)
    c.draw(paws)

    var laptop = Canvas()
    laptop.rect(8, 22, 23, 28, hex(0xC9CFDA))
    laptop.rect(8, 22, 23, 22, hex(0xE7EBF2))
    laptop.rect(9, 28, 22, 28, hex(0xAEB5C3))
    laptop.rect(6, 29, 25, 30, hex(0x9AA2B2))
    laptop.rect(6, 29, 25, 29, hex(0xB9C0CD))
    laptop.outline(edge)
    laptop.dots([(15, 25), (16, 25)], pet.palette.accent)
    c.draw(laptop)
}

func drawEffect(_ c: inout Canvas, _ effect: Effect) {
    switch effect {
    case let .z(x, y, big):
        let color = hex(0xBFD8FF)
        if big {
            c.rect(x, y, x + 3, y, color)
            c.dots([(x + 2, y + 1), (x + 1, y + 2)], color)
            c.rect(x, y + 3, x + 3, y + 3, color)
        } else {
            c.rect(x, y, x + 2, y, color)
            c.dots([(x + 1, y + 1)], color)
            c.rect(x, y + 2, x + 2, y + 2, color)
        }
    case let .sparkle(x, y, color):
        c.dots([(x, y - 1), (x - 1, y), (x, y), (x + 1, y), (x, y + 1)], color)
    case let .heart(x, y):
        let color = hex(0xFF5C8A)
        c.dots([(x, y), (x + 1, y), (x + 3, y), (x + 4, y)], color)
        c.rect(x, y + 1, x + 4, y + 1, color)
        c.rect(x + 1, y + 2, x + 3, y + 2, color)
        c.dots([(x + 2, y + 3)], color)
    }
}

// MARK: - Pet designs

func pointyEars(inner: RGB, base: RGB, height: Double, tip: RGB? = nil) -> (inout Canvas, Pose) -> Void {
    { c, pose in
        let twitch = pose.earTwitch ? 1.0 : 0
        let tipY = 9.5 - height
        c.triangle((6.6, 13), (13.5, 9), (7.4 - twitch, tipY + twitch), base)
        c.triangle((mx(6.6), 13), (mx(13.5), 9), (mx(7.4), tipY), base)
        if let tip {
            c.triangle((6.9 - twitch * 0.8, tipY + 2.6), (9.3, tipY + 2.2), (7.4 - twitch, tipY + twitch), tip)
            c.triangle((mx(6.9), tipY + 2.6), (mx(9.3), tipY + 2.2), (mx(7.4), tipY), tip)
        }
        c.triangle((8.3, 10.6), (11.4, 9.4), (8.3 - twitch, tipY + 2.6 + twitch), inner)
        c.triangle((mx(8.3), 10.6), (mx(11.4), 9.4), (mx(8.3), tipY + 2.6), inner)
    }
}

let cat = PetSpec(
    name: "cat",
    palette: Palette(base: hex(0xF5A35A), shade: hex(0xD7803A), light: hex(0xFFF1E0), accent: hex(0xFF9DB2),
                     outline: hex(0x6A3A1E), nose: hex(0xFF7F9C)),
    pawColor: hex(0xFFF1E0),
    ears: pointyEars(inner: hex(0xFFB6C6), base: hex(0xF5A35A), height: 5.2),
    headMarkings: { c, _ in
        c.ellipse(16, 19.6, 3.6, 2.3, hex(0xFFF1E0))
        c.dots([(15, 8), (16, 8), (15, 9), (16, 9), (12, 9), (12, 10), (mi(12), 9), (mi(12), 10)], hex(0xD7803A))
    },
    tail: { c, pose in
        let s = pose.tail
        c.stroke([(20, 28), (24.5, 27.5), (27, 24.5), (27.6 + s, 20.5), (26.6 + s * 1.8, 17.6)], radius: 1.35, hex(0xF5A35A))
        c.ellipse(26.6 + s * 1.8, 17.8, 1.4, 1.4, hex(0xD7803A))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 3.6, 3.4, hex(0xFFF1E0))
    }
)

let dog = PetSpec(
    name: "dog",
    palette: Palette(base: hex(0xD49A61), shade: hex(0xB37A45), light: hex(0xFFF4E3), accent: hex(0xFF8FA6),
                     outline: hex(0x5A3418), nose: hex(0x3A2622)),
    pawColor: hex(0xFFF4E3),
    headMarkings: { c, _ in
        c.ellipse(16, 19.4, 4.6, 2.9, hex(0xFFF4E3))
        c.rect(15, 8, 16, 12, hex(0xFFF4E3))
        c.ellipse(mx(11.6), 15.3, 2.7, 2.5, hex(0xA86E3D))
    },
    frontEars: { c, pose in
        let lift = pose.armsUp ? -1.5 : 0
        c.ellipse(6.9, 14.0 + lift, 2.4, 4.6, hex(0x8C5631))
        c.ellipse(mx(6.9), 14.0 + lift, 2.4, 4.6, hex(0x8C5631))
    },
    tail: { c, pose in
        let s = pose.tail
        c.stroke([(21, 26), (24.5, 24.5), (25.6 + s * 1.6, 20.6)], radius: 1.3, hex(0xD49A61))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 3.8, 3.4, hex(0xFFF4E3))
    }
)

let bunny = PetSpec(
    name: "bunny",
    palette: Palette(base: hex(0xF4EEF7), shade: hex(0xD5C9DF), light: hex(0xFFFFFF), accent: hex(0xFFB0C6),
                     outline: hex(0x6E5A7A), nose: hex(0xFF8FB0)),
    pawColor: hex(0xFFFFFF),
    ears: { c, pose in
        let tilt = pose.earTwitch ? 1.6 : 0
        let flop = pose.armsUp ? 2.5 : 0
        c.stroke([(12, 10), (11.2 - tilt - flop, 3.0 + flop * 0.6)], radius: 2.3, hex(0xF4EEF7))
        c.stroke([(mx(12), 10), (mx(11.2) + flop, 3.0 + flop * 0.6)], radius: 2.3, hex(0xF4EEF7))
        c.stroke([(12, 9), (11.3 - tilt - flop, 3.6 + flop * 0.6)], radius: 0.9, hex(0xFFB6CB))
        c.stroke([(mx(12), 9), (mx(11.3) + flop, 3.6 + flop * 0.6)], radius: 0.9, hex(0xFFB6CB))
    },
    headMarkings: { c, _ in
        c.ellipse(16, 19.4, 3.2, 2.0, hex(0xFFFFFF))
    },
    tail: { c, _ in
        c.ellipse(23.4, 28.2, 2.3, 2.1, hex(0xFFFFFF))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 3.6, 3.3, hex(0xFFFFFF))
    }
)

let fox = PetSpec(
    name: "fox",
    palette: Palette(base: hex(0xF0823A), shade: hex(0xCC6224), light: hex(0xFFF7EE), accent: hex(0xFF9DB2),
                     outline: hex(0x5E2810), nose: hex(0x2C1D1A)),
    pawColor: hex(0x3C2A28),
    armColor: hex(0xF0823A),
    ears: pointyEars(inner: hex(0xFFE2CF), base: hex(0xF0823A), height: 6.6, tip: hex(0x3C2A28)),
    headMarkings: { c, _ in
        c.ellipse(11.2, 19.0, 4.0, 2.6, hex(0xFFF7EE))
        c.ellipse(mx(11.2), 19.0, 4.0, 2.6, hex(0xFFF7EE))
        c.ellipse(16, 20.2, 2.2, 1.6, hex(0xFFF7EE))
    },
    tail: { c, pose in
        let s = pose.tail
        c.stroke([(20, 28), (24.5, 27.2), (27.2, 23.6), (27.4 + s, 19.6)], radius: 2.3, hex(0xF0823A))
        c.ellipse(27.4 + s, 18.0, 2.1, 2.1, hex(0xFFF7EE))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 25.4, 3.6, 3.6, hex(0xFFF7EE))
    }
)

let panda = PetSpec(
    name: "panda",
    palette: Palette(base: hex(0xF6F6F1), shade: hex(0xD6D6D0), light: hex(0xFFFFFF), accent: hex(0xFF9DB2),
                     outline: hex(0x3A3A48), eye: hex(0x0E0E14), nose: hex(0x2A2A34)),
    pawColor: hex(0x3E3E4C),
    ears: { c, pose in
        let twitch = pose.earTwitch ? 0.6 : 0
        c.ellipse(8.4, 9.0 + twitch, 3.0, 3.0, hex(0x3E3E4C))
        c.ellipse(mx(8.4), 9.0, 3.0, 3.0, hex(0x3E3E4C))
    },
    headMarkings: { c, _ in
        c.ellipse(11.6, 15.6, 2.7, 2.4, hex(0x3E3E4C))
        c.ellipse(mx(11.6), 15.6, 2.7, 2.4, hex(0x3E3E4C))
    },
    bodyMarkings: { c, _ in
        c.ellipse(9.6, 23.4, 2.6, 3.4, hex(0x3E3E4C))
        c.ellipse(mx(9.6), 23.4, 2.6, 3.4, hex(0x3E3E4C))
    },
    eyeHighlight: hex(0xFFFFFF)
)

let frog = PetSpec(
    name: "frog",
    palette: Palette(base: hex(0x86CF6C), shade: hex(0x62AC4E), light: hex(0xEAF7C9), accent: hex(0xFF9DB2),
                     outline: hex(0x2E5A26), nose: hex(0x2E5A26)),
    pawColor: hex(0x86CF6C),
    ears: { c, _ in
        c.ellipse(11.0, 10.4, 3.6, 3.4, hex(0x86CF6C))
        c.ellipse(mx(11.0), 10.4, 3.6, 3.4, hex(0x86CF6C))
    },
    headMarkings: { c, _ in
        c.ellipse(11.0, 10.6, 2.5, 2.4, hex(0xFFFFFF))
        c.ellipse(mx(11.0), 10.6, 2.5, 2.4, hex(0xFFFFFF))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 4.2, 3.4, hex(0xEAF7C9))
    },
    mouth: { c, pose in
        let line = hex(0x2E5A26)
        if pose.mouthOpen {
            c.rect(13, 18, 18, 18, line)
            c.rect(14, 19, 17, 19, hex(0xFF6F8E))
            c.dots([(13, 19), (18, 19)], line)
        } else {
            c.dots([(11, 17), (12, 18), (mi(11), 17), (mi(12), 18)], line)
            c.rect(13, 18, 18, 18, line)
        }
    },
    eyeTop: 9
)

/// Side flippers or wings, drawn behind the body.
func sideWings(_ color: RGB) -> (inout Canvas, Pose) -> Void {
    { c, _ in
        c.ellipse(8.6, 24.2, 1.9, 3.4, color)
        c.ellipse(mx(8.6), 24.2, 1.9, 3.4, color)
    }
}

/// A small beak or bill in the middle of the face, wider for ducks.
func beak(_ color: RGB, wide: Bool) -> (inout Canvas, Pose) -> Void {
    { c, pose in
        let left = wide ? 14 : 15
        c.rect(left, 17, mi(left), 17, color)
        if pose.mouthOpen {
            c.dots([(15, 18), (16, 18)], hex(0xFF6F8E))
            c.rect(left, 19, mi(left), 19, color)
        } else {
            c.rect(15, 18, 16, 18, color)
        }
    }
}

let hamster = PetSpec(
    name: "hamster",
    palette: Palette(base: hex(0xF2B45A), shade: hex(0xD6923C), light: hex(0xFFF3DD), accent: hex(0xFFB3C1),
                     outline: hex(0x6B4220), nose: hex(0xFF8FA6)),
    pawColor: hex(0xFFD9D0),
    ears: { c, pose in
        let twitch = pose.earTwitch ? 0.6 : 0
        c.ellipse(9.6, 8.8 + twitch, 2.5, 2.4, hex(0xF2B45A))
        c.ellipse(mx(9.6), 8.8, 2.5, 2.4, hex(0xF2B45A))
        c.ellipse(9.6, 8.9 + twitch, 1.2, 1.2, hex(0xFFB3C1))
        c.ellipse(mx(9.6), 8.9, 1.2, 1.2, hex(0xFFB3C1))
    },
    headMarkings: { c, _ in
        c.ellipse(10.0, 18.4, 3.4, 2.4, hex(0xFFF3DD))
        c.ellipse(mx(10.0), 18.4, 3.4, 2.4, hex(0xFFF3DD))
        c.ellipse(16, 19.0, 2.6, 1.8, hex(0xFFF3DD))
        c.rect(15, 8, 16, 10, hex(0xFFF3DD))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 4.4, 3.6, hex(0xFFF3DD))
    }
)

let penguin = PetSpec(
    name: "penguin",
    palette: Palette(base: hex(0x3D4A6B), shade: hex(0x2C3652), light: hex(0xF7F7FA), accent: hex(0xFF9DB2),
                     outline: hex(0x1A2033), nose: hex(0xFFA53D)),
    pawColor: hex(0xFFA53D),
    armColor: hex(0x3D4A6B),
    headMarkings: { c, _ in
        c.ellipse(12.4, 16.0, 3.7, 4.2, hex(0xF7F7FA))
        c.ellipse(mx(12.4), 16.0, 3.7, 4.2, hex(0xF7F7FA))
        c.ellipse(16, 18.6, 5.6, 3.0, hex(0xF7F7FA))
    },
    tail: sideWings(hex(0x3D4A6B)),
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 4.8, 4.4, hex(0xF7F7FA))
    },
    mouth: beak(hex(0xFFA53D), wide: false)
)

let owl = PetSpec(
    name: "owl",
    palette: Palette(base: hex(0xB9824F), shade: hex(0x94643A), light: hex(0xF1DDBD), accent: hex(0xFF9DB2),
                     outline: hex(0x4E3016), nose: hex(0xF0A23C)),
    pawColor: hex(0xF0A23C),
    armColor: hex(0xB9824F),
    ears: { c, pose in
        let twitch = pose.earTwitch ? 1.0 : 0
        c.triangle((7.2, 11), (11.8, 8.6), (7.6 - twitch, 4.6 + twitch), hex(0xB9824F))
        c.triangle((mx(7.2), 11), (mx(11.8), 8.6), (mx(7.6), 4.6), hex(0xB9824F))
    },
    headMarkings: { c, _ in
        c.ellipse(11.8, 15.6, 3.6, 3.4, hex(0xF1DDBD))
        c.ellipse(mx(11.8), 15.6, 3.6, 3.4, hex(0xF1DDBD))
        c.dots([(13, 10), (16, 9), (19, 10)], hex(0x94643A))
    },
    tail: sideWings(hex(0x94643A)),
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 4.2, 3.8, hex(0xF1DDBD))
        c.dots([(14, 25), (17, 24), (15, 27), (18, 27)], hex(0xD0B48C))
    },
    mouth: beak(hex(0xF0A23C), wide: false)
)

let koala = PetSpec(
    name: "koala",
    palette: Palette(base: hex(0xA7ACB8), shade: hex(0x868B98), light: hex(0xEDEFF3), accent: hex(0xFF9DB2),
                     outline: hex(0x454956), nose: hex(0x34373F)),
    pawColor: hex(0x868B98),
    ears: { c, pose in
        let twitch = pose.earTwitch ? 0.8 : 0
        c.ellipse(7.2, 10.0 + twitch, 3.7, 3.5, hex(0xA7ACB8))
        c.ellipse(mx(7.2), 10.0, 3.7, 3.5, hex(0xA7ACB8))
        c.ellipse(7.6, 10.4 + twitch, 2.1, 2.0, hex(0xEDEFF3))
        c.ellipse(mx(7.6), 10.4, 2.1, 2.0, hex(0xEDEFF3))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 4.0, 3.6, hex(0xEDEFF3))
    },
    mouth: { c, pose in
        let nose = hex(0x34373F)
        c.rect(15, 16, 16, 18, nose)
        c.dots([(14, 17), (17, 17)], nose)
        c.dots([(15, 16)], hex(0x6A6E7A))
        if pose.mouthOpen { c.dots([(15, 19), (16, 19)], hex(0xFF6F8E)) }
    }
)

let duck = PetSpec(
    name: "duck",
    palette: Palette(base: hex(0xFFD84A), shade: hex(0xE9B92A), light: hex(0xFFF2A6), accent: hex(0xFF9DB2),
                     outline: hex(0x8A5A12), nose: hex(0xFF9F2E)),
    pawColor: hex(0xFF9F2E),
    armColor: hex(0xFFD84A),
    ears: { c, pose in
        let sway = pose.earTwitch ? 1.0 : 0
        c.stroke([(16, 8.5), (16.6 + sway, 5.8), (18.2 + sway, 5.0)], radius: 1.0, hex(0xFFD84A))
    },
    tail: sideWings(hex(0xE9B92A)),
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 4.0, 3.4, hex(0xFFF2A6))
    },
    mouth: beak(hex(0xFF9F2E), wide: true)
)

let hedgehog = PetSpec(
    name: "hedgehog",
    palette: Palette(base: hex(0x9C6B45), shade: hex(0x7C5233), light: hex(0xF6E1C3), accent: hex(0xFF9DB2),
                     outline: hex(0x4A2E18), nose: hex(0x2A1E18)),
    pawColor: hex(0xF6E1C3),
    ears: { c, pose in
        // Spines fanning out around the top of the head.
        let lift = pose.earTwitch ? 0.6 : 0
        for step in 0..<10 {
            let angle = (178 + Double(step) * 20.4) * .pi / 180
            let tip: Point = (16 + cos(angle) * 13.4, 15 + sin(angle) * (11.6 + lift))
            let left = angle - 0.2, right = angle + 0.2
            let base = (left: (16 + cos(left) * 8.8, 15 + sin(left) * 6.9), right: (16 + cos(right) * 8.8, 15 + sin(right) * 6.9))
            c.triangle(base.left, base.right, tip, hex(0x9C6B45))
            // Darker tips make the spines read as spines rather than fur.
            let mid = (left: (base.left.0 * 0.4 + tip.x * 0.6, base.left.1 * 0.4 + tip.y * 0.6),
                       right: (base.right.0 * 0.4 + tip.x * 0.6, base.right.1 * 0.4 + tip.y * 0.6))
            c.triangle(mid.left, mid.right, tip, hex(0x6A4428))
        }
    },
    headMarkings: { c, _ in
        c.ellipse(16, 17.2, 6.6, 4.6, hex(0xF6E1C3))
        c.ellipse(10.2, 12.0, 1.5, 1.5, hex(0xF6E1C3))
        c.ellipse(mx(10.2), 12.0, 1.5, 1.5, hex(0xF6E1C3))
    },
    bodyMarkings: { c, _ in
        c.ellipse(16, 26, 4.0, 3.6, hex(0xF6E1C3))
    }
)

let pets = [cat, dog, bunny, fox, panda, frog, hamster, penguin, owl, koala, duck, hedgehog]

// MARK: - Animations

struct Animation {
    let mood: String
    let delay: Double
    let poses: [Pose]
}

let idle = Animation(mood: "idle", delay: 0.14, poses: (0..<12).map { i in
    var pose = Pose()
    pose.tail = sin(Double(i) / 12 * 2 * .pi)
    pose.headDy = (6...10).contains(i) ? 1 : 0
    pose.breath = (6...10).contains(i) ? 0.4 : 0
    pose.eyes = i == 9 ? .blink : .open
    pose.earTwitch = i == 3
    return pose
})

let focus = Animation(mood: "focus", delay: 0.15, poses: (0..<8).map { i in
    var pose = Pose()
    pose.typing = i % 2
    pose.eyes = i == 6 ? .blink : .down
    pose.headDy = (4...7).contains(i) ? 1 : 0
    pose.tail = sin(Double(i) / 8 * 2 * .pi) * 0.6
    return pose
})

let rest = Animation(mood: "rest", delay: 0.28, poses: (0..<8).map { i in
    var pose = Pose()
    pose.eyes = .closed
    pose.headDy = i < 4 ? 1 : 2
    pose.breath = i < 4 ? 0 : 0.5
    pose.tail = -0.4
    let rise = [(26, 9), (26, 8), (27, 7), (27, 6), (28, 5), (28, 4), (29, 3), (29, 2)]
    let a = rise[i], b = rise[(i + 4) % 8]
    pose.effects = [.z(x: a.0, y: a.1, big: i >= 4), .z(x: b.0 - 1, y: b.1, big: (i + 4) % 8 >= 4)]
    return pose
})

let celebrate = Animation(mood: "celebrate", delay: 0.09, poses: (0..<8).map { i in
    var pose = Pose()
    let jump = [0, -1, -2, -3, -3, -2, -1, 0]
    pose.dy = jump[i]
    pose.armsUp = (1...6).contains(i)
    pose.eyes = .happy
    pose.mouthOpen = true
    pose.tail = sin(Double(i) / 8 * 4 * .pi)
    let yellow = hex(0xFFD75E), white = hex(0xFFFFFF), pink = hex(0xFF8FB8)
    pose.effects = i % 2 == 0
        ? [.sparkle(x: 3, y: 6, color: yellow), .sparkle(x: 28, y: 11, color: white), .sparkle(x: 2, y: 22, color: pink)]
        : [.sparkle(x: 28, y: 4, color: yellow), .sparkle(x: 3, y: 14, color: white), .sparkle(x: 29, y: 21, color: pink)]
    return pose
})

let animations = [idle, focus, rest, celebrate]

// MARK: - Output

extension Canvas {
    var image: CGImage {
        var image = RGBAImage(width: side, height: side)
        for (i, pixel) in pixels.enumerated() {
            guard let pixel else { continue }
            image.pixels.replaceSubrange((i * 4)..<(i * 4 + 4), with: [pixel.r, pixel.g, pixel.b, 255])
        }
        return image.cgImage()
    }
}

/// Writes `<pet>_<mood>.gif` for every pixel pet. Returns one row of frames per GIF for previews.
func generatePixelPets(into directory: URL) throws -> [[CGImage]] {
    var rows: [[CGImage]] = []
    for pet in pets {
        for animation in animations {
            let frames = animation.poses.map { renderFrame(pet, $0) }
            var palette = [RGB(r: 0, g: 0, b: 0)]
            var lookup: [RGB: UInt8] = [:]
            let indexed: [[UInt8]] = frames.map { frame in
                frame.pixels.map { pixel in
                    guard let pixel else { return 0 }
                    if let index = lookup[pixel] { return index }
                    let index = UInt8(palette.count)
                    palette.append(pixel)
                    lookup[pixel] = index
                    return index
                }
            }
            let url = directory.appendingPathComponent("\(pet.name)_\(animation.mood).gif")
            try writeGIF(width: side, height: side, palette: palette, frames: indexed, delay: animation.delay, to: url)
            guard verifyGIF(url, width: side, height: side, frames: indexed) else {
                fatalError("GIF round-trip failed for \(url.lastPathComponent)")
            }
            rows.append(frames.map(\.image))
        }
    }
    return rows
}
