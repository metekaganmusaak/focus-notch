import Foundation

// Synthesizes Focus Notch's own notification chimes, so they're original and
// free of any license: soft kalimba/bell notes with a touch of reverb.

private let sampleRate = 44_100.0

private struct Note {
    let frequency: Double
    let start: Double
    var gain = 1.0
    var decay = 0.9
}

private struct Chime {
    let name: String
    let notes: [Note]
    var length = 2.0
}

private let chimes = [
    // Focus finished: a bright rising arpeggio.
    Chime(name: "chime_break", notes: [
        Note(frequency: 659.26, start: 0.00, gain: 0.8),
        Note(frequency: 830.61, start: 0.09, gain: 0.8),
        Note(frequency: 987.77, start: 0.18, gain: 0.85),
        Note(frequency: 1318.51, start: 0.30, gain: 0.9, decay: 1.3),
    ]),
    // Break over: a friendly two-note "ding-dong" upward.
    Chime(name: "chime_focus", notes: [
        Note(frequency: 783.99, start: 0.00, gain: 0.9),
        Note(frequency: 1174.66, start: 0.17, gain: 1.0, decay: 1.2),
        Note(frequency: 587.33, start: 0.17, gain: 0.35, decay: 1.2),
    ]),
    // Heads-up before the next session: two soft, falling notes.
    Chime(name: "chime_reminder", notes: [
        Note(frequency: 1174.66, start: 0.00, gain: 0.65, decay: 0.6),
        Note(frequency: 880.00, start: 0.16, gain: 0.7, decay: 0.9),
    ], length: 1.6),
    // Session finished: a little fanfare ending on a chord.
    Chime(name: "chime_finish", notes: [
        Note(frequency: 523.25, start: 0.00, gain: 0.7, decay: 0.5),
        Note(frequency: 659.26, start: 0.10, gain: 0.7, decay: 0.5),
        Note(frequency: 783.99, start: 0.20, gain: 0.75, decay: 0.5),
        Note(frequency: 1046.50, start: 0.36, gain: 0.9, decay: 1.5),
        Note(frequency: 1318.51, start: 0.36, gain: 0.55, decay: 1.5),
        Note(frequency: 1567.98, start: 0.36, gain: 0.45, decay: 1.5),
    ], length: 2.6),
]

/// A kalimba-like tone: a few gently inharmonic partials, each fading at its own rate.
private func render(_ note: Note, into samples: inout [Double]) {
    let partials: [(ratio: Double, gain: Double, decay: Double)] = [
        (1.0, 1.0, 1.0), (2.0, 0.28, 0.5), (3.01, 0.10, 0.32), (5.43, 0.05, 0.16),
    ]
    let first = Int(note.start * sampleRate)
    for i in first..<samples.count {
        let t = Double(i - first) / sampleRate
        let attack = min(t / 0.004, 1)
        var value = 0.0
        for partial in partials {
            let envelope = exp(-t / (note.decay * partial.decay))
            value += partial.gain * envelope * sin(2 * .pi * note.frequency * partial.ratio * t)
        }
        samples[i] += note.gain * attack * value
    }
}

/// A small Schroeder reverb: parallel damped combs into series all-passes.
private func reverb(_ dry: [Double], mix: Double) -> [Double] {
    var wet = [Double](repeating: 0, count: dry.count)
    for delayTime in [0.0297, 0.0371, 0.0411, 0.0437] {
        let delay = Int(delayTime * sampleRate)
        var buffer = [Double](repeating: 0, count: delay)
        var index = 0
        var lowpass = 0.0
        for i in 0..<dry.count {
            let output = buffer[index]
            lowpass = output * 0.6 + lowpass * 0.4
            buffer[index] = dry[i] + lowpass * 0.72
            index = (index + 1) % delay
            wet[i] += output / 4
        }
    }
    for delayTime in [0.005, 0.0017] {
        let delay = Int(delayTime * sampleRate)
        var buffer = [Double](repeating: 0, count: delay)
        var index = 0
        for i in 0..<wet.count {
            let delayed = buffer[index]
            let input = wet[i]
            let output = -0.5 * input + delayed
            buffer[index] = input + 0.5 * output
            index = (index + 1) % delay
            wet[i] = output
        }
    }
    return zip(dry, wet).map { $0 * (1 - mix) + $1 * mix }
}

private func writeWAV(_ samples: [Double], to url: URL) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let byteCount = samples.count * 2
    data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + byteCount))
    data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
    append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
    data.append(contentsOf: Array("data".utf8)); append(UInt32(byteCount))
    for sample in samples {
        append(Int16(max(-1, min(1, sample)) * 32_767))
    }
    try data.write(to: url)
}

/// Writes `chime_*.wav` into `directory`, normalized to -3 dBFS.
func generateChimes(into directory: URL) throws -> [String] {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try chimes.map { chime in
        var samples = [Double](repeating: 0, count: Int(chime.length * sampleRate))
        for note in chime.notes { render(note, into: &samples) }
        samples = reverb(samples, mix: 0.22)
        // Fade the tail so the file never ends on a click.
        let fade = Int(0.25 * sampleRate)
        for i in 0..<fade { samples[samples.count - 1 - i] *= Double(i) / Double(fade) }
        let peak = samples.map(abs).max() ?? 1
        let gain = pow(10, -3.0 / 20) / peak
        try writeWAV(samples.map { $0 * gain }, to: directory.appendingPathComponent("\(chime.name).wav"))
        return chime.name
    }
}
