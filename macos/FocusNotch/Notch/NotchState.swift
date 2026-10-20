import AppKit
import Observation
import SwiftUI

enum NotchMode: Equatable {
    /// Nothing to show on a screen without a hardware notch.
    case hidden
    /// Same size as the hardware notch.
    case idle
    /// Notch with small "wings" showing the pet and countdown.
    case compact
    /// Full panel shown while the pointer is over the notch.
    case expanded
    /// A timer event (break, reminder, summary) being announced.
    case alert

    var isOpen: Bool { self == .expanded || self == .alert }
}

/// How much room the notch takes. Compact has narrower wings and smaller panels.
enum NotchDesign: String, CaseIterable {
    case standard, compact

    var title: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .compact: String(localized: "Compact")
        }
    }
}

/// Size of the physical notch, or of a stand-in on screens without one.
struct NotchMetrics: Equatable {
    var notchWidth: CGFloat = 200
    var notchHeight: CGFloat = 32
    var hasNotch = false

    init() {}

    init(screen: NSScreen) {
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            notchWidth = screen.frame.width - left.width - right.width
            notchHeight = screen.safeAreaInsets.top
            hasNotch = true
        } else {
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            notchWidth = 190
            notchHeight = menuBar > 0 ? menuBar : 24
            hasNotch = false
        }
    }
}

enum NotchLayout {
    static func compactWing(_ design: NotchDesign) -> CGFloat {
        design == .compact ? 62 : 78
    }
    /// Fixed size of the transparent panel; the black shape animates inside it.
    static let windowSize = CGSize(width: 760, height: 300)

    /// Size of the black body, excluding the flared top corners.
    static func bodySize(_ mode: NotchMode, _ metrics: NotchMetrics, _ design: NotchDesign) -> CGSize {
        let compact = design == .compact
        switch mode {
        case .hidden, .idle:
            return CGSize(width: metrics.notchWidth, height: metrics.notchHeight)
        case .compact:
            return CGSize(width: metrics.notchWidth + compactWing(design) * 2, height: metrics.notchHeight)
        case .expanded:
            return compact
                ? CGSize(width: max(metrics.notchWidth + 230, 420), height: metrics.notchHeight + 116)
                : CGSize(width: max(metrics.notchWidth + 310, 500), height: metrics.notchHeight + 170)
        case .alert:
            return compact
                ? CGSize(width: max(metrics.notchWidth + 230, 420), height: metrics.notchHeight + 74)
                : CGSize(width: max(metrics.notchWidth + 270, 470), height: metrics.notchHeight + 96)
        }
    }

    static func radii(_ mode: NotchMode, _ metrics: NotchMetrics) -> (top: CGFloat, bottom: CGFloat) {
        mode.isOpen ? (14, 30) : (6, min(12, metrics.notchHeight / 2.6))
    }

    /// Full size of the shape including the flared top corners.
    static func frameSize(_ mode: NotchMode, _ metrics: NotchMetrics, _ design: NotchDesign) -> CGSize {
        let body = bodySize(mode, metrics, design)
        return CGSize(width: body.width + radii(mode, metrics).top * 2, height: body.height)
    }
}

struct NotchAlert: Identifiable, Equatable {
    struct Action: Equatable {
        let title: String
    }

    let id = UUID()
    let title: String
    let message: String
    let tint: Color
    let mood: PetMood
    let sound: String
    let action: Action?

    var displayDuration: TimeInterval { action == nil ? 7 : 15 }
}

/// Transient UI state for the notch: hover, alerts and pet reactions.
@Observable
final class NotchState {
    var isHovering = false
    /// Keeps the panel open while the user types a new topic.
    var isEditingTopic = false
    var metrics = NotchMetrics()
    /// Set by the window controller: makes the panel accept typing.
    @ObservationIgnored var requestKeyboard: (() -> Void)?
    /// Set by the window controller: hands typing back to the app the user was in.
    @ObservationIgnored var releaseKeyboard: (() -> Void)?
    private(set) var alert: NotchAlert?
    private(set) var petReaction: PetMood?
    /// Opens the panel for a moment, e.g. to show a new design.
    private(set) var isPeeking = false

    @ObservationIgnored private var alertTask: Task<Void, Never>?
    @ObservationIgnored private var reactionTask: Task<Void, Never>?
    @ObservationIgnored private var peekTask: Task<Void, Never>?

    func present(_ alert: NotchAlert) {
        self.alert = alert
        alertTask?.cancel()
        alertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(alert.displayDuration))
            guard !Task.isCancelled else { return }
            self?.alert = nil
        }
    }

    func dismissAlert() {
        alertTask?.cancel()
        alert = nil
    }

    func peek(for seconds: TimeInterval = 4) {
        isPeeking = true
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.isPeeking = false
        }
    }

    /// Briefly switches the pet to another animation, e.g. when it's clicked.
    func react(_ mood: PetMood, for seconds: TimeInterval = 1.8) {
        petReaction = mood
        reactionTask?.cancel()
        reactionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.petReaction = nil
        }
    }
}
