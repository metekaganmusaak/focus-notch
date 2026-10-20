import SwiftUI

extension PomodoroPhase {
    var title: String {
        switch self {
        case .focus: String(localized: "Focus")
        case .shortBreak: String(localized: "Short Break")
        case .longBreak: String(localized: "Long Break")
        }
    }

    /// The phase color in the user's theme.
    var tint: Color {
        AppModel.shared.settings.theme.color(for: self)
    }

    var symbol: String {
        switch self {
        case .focus: "brain.head.profile"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "sofa.fill"
        }
    }
}
