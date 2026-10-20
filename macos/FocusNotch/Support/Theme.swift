import SwiftUI

/// Color theme for the phases. The notch itself always stays black.
enum Theme: String, CaseIterable, Identifiable {
    case coral, ocean, forest, lavender, sunset, mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coral: String(localized: "Coral")
        case .ocean: String(localized: "Ocean")
        case .forest: String(localized: "Forest")
        case .lavender: String(localized: "Lavender")
        case .sunset: String(localized: "Sunset")
        case .mono: String(localized: "Mono")
        }
    }

    func color(for phase: PomodoroPhase) -> Color {
        let (focus, shortBreak, longBreak) = rgb
        let value = switch phase {
        case .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
        return Color(red: value.0, green: value.1, blue: value.2)
    }

    private var rgb: (RGB, RGB, RGB) {
        switch self {
        case .coral: ((1.00, 0.45, 0.36), (0.30, 0.88, 0.64), (0.45, 0.64, 1.00))
        case .ocean: ((0.29, 0.62, 1.00), (0.30, 0.86, 0.90), (0.58, 0.52, 1.00))
        case .forest: ((0.42, 0.84, 0.45), (0.98, 0.80, 0.36), (0.36, 0.76, 0.66))
        case .lavender: ((0.72, 0.56, 1.00), (1.00, 0.60, 0.80), (0.55, 0.70, 1.00))
        case .sunset: ((1.00, 0.58, 0.22), (1.00, 0.42, 0.56), (0.72, 0.46, 0.96))
        case .mono: ((0.96, 0.96, 0.96), (0.76, 0.76, 0.78), (0.60, 0.60, 0.64))
        }
    }

    private typealias RGB = (Double, Double, Double)
}
