import Foundation
import Observation

enum PomodoroPhase: String, CaseIterable {
    case focus, shortBreak, longBreak

    var isBreak: Bool { self != .focus }
}

enum TimerState {
    case idle, running, paused
}

enum PomodoroEvent {
    case focusCompleted(next: PomodoroPhase, autoStarted: Bool)
    case breakCompleted(autoStarted: Bool)
    case nextSessionSoon(remaining: TimeInterval)
    case finished(focusTime: TimeInterval, sessions: Int)
}

/// Drives the focus → break → focus cycle. Time is tracked against an end date,
/// so the countdown stays correct across sleep and busy run loops.
@Observable
final class PomodoroEngine {
    private(set) var phase: PomodoroPhase = .focus
    private(set) var state: TimerState = .idle
    /// Seconds left in the current phase. Updated once per second while running.
    private(set) var remaining: TimeInterval = 0
    private(set) var phaseDuration: TimeInterval = 0
    /// Focus sessions completed toward the next long break.
    private(set) var completedInCycle = 0
    /// True from the first start until the user finishes the session.
    private(set) var isSessionActive = false

    @ObservationIgnored var onEvent: ((PomodoroEvent) -> Void)?

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let stats: StatsStore
    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var hasWarnedNextSession = false
    @ObservationIgnored private var sessionFocusTime: TimeInterval = 0
    @ObservationIgnored private var sessionCompleted = 0

    init(settings: SettingsStore, stats: StatsStore) {
        self.settings = settings
        self.stats = stats
        load(.focus)
    }

    var isRunning: Bool { state == .running }

    var progress: Double {
        guard phaseDuration > 0 else { return 0 }
        return min(max(1 - remaining / phaseDuration, 0), 1)
    }

    var sessionsPerCycle: Int { settings.sessionsBeforeLongBreak }

    var nextPhase: PomodoroPhase {
        guard phase == .focus else { return .focus }
        return completedInCycle + 1 >= settings.sessionsBeforeLongBreak ? .longBreak : .shortBreak
    }

    /// The current phase hasn't been started or has been fully reset.
    var isPristine: Bool { state == .idle && remaining == phaseDuration }

    func duration(of phase: PomodoroPhase) -> TimeInterval {
        let minutes = switch phase {
        case .focus: settings.focusMinutes
        case .shortBreak: settings.shortBreakMinutes
        case .longBreak: settings.longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    // MARK: - Controls

    func start() {
        guard state != .running else { return }
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        isSessionActive = true
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func pause() {
        guard state == .running else { return }
        remaining = currentRemaining
        stopTicker()
        state = .paused
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func skip() {
        let wasRunning = isRunning
        if phase == .focus { recordPartialFocus() }
        if phase == .longBreak { completedInCycle = 0 }
        let next = nextPhase
        stopTicker()
        state = .idle
        load(next)
        if wasRunning { start() }
    }

    func reset() {
        stopTicker()
        state = .idle
        load(phase)
    }

    func finish() {
        if phase == .focus, state != .idle { recordPartialFocus() }
        let wasActive = isSessionActive
        let focusTime = sessionFocusTime
        let sessions = sessionCompleted
        stopTicker()
        state = .idle
        completedInCycle = 0
        isSessionActive = false
        sessionFocusTime = 0
        sessionCompleted = 0
        load(.focus)
        if wasActive {
            onEvent?(.finished(focusTime: focusTime, sessions: sessions))
        }
    }

    /// Durations changed in settings; apply them right away unless a timer is in flight.
    func settingsDidChange() {
        if state == .idle { load(phase) }
    }

    // MARK: - Internals

    private var leadTime: TimeInterval { TimeInterval(settings.reminderLeadMinutes * 60) }

    private var currentRemaining: TimeInterval {
        guard state == .running, let endDate else { return remaining }
        return max(endDate.timeIntervalSinceNow, 0)
    }

    private func tick() {
        guard state == .running else { return }
        let left = currentRemaining
        let shown = left.rounded(.up)
        if shown != remaining { remaining = shown }

        if phase.isBreak, !hasWarnedNextSession, left > 0, left <= leadTime {
            hasWarnedNextSession = true
            onEvent?(.nextSessionSoon(remaining: shown))
        }
        if left <= 0 { completePhase() }
    }

    private func completePhase() {
        stopTicker()
        state = .idle
        if phase == .focus {
            completedInCycle += 1
            sessionCompleted += 1
            sessionFocusTime += phaseDuration
            stats.addFocus(phaseDuration, completedSession: true, topicID: settings.currentTopicID)
            let next: PomodoroPhase = completedInCycle >= settings.sessionsBeforeLongBreak ? .longBreak : .shortBreak
            let autoStart = settings.autoStartBreaks
            load(next)
            if autoStart { start() }
            onEvent?(.focusCompleted(next: next, autoStarted: autoStart))
        } else {
            if phase == .longBreak { completedInCycle = 0 }
            let autoStart = settings.autoStartFocus
            load(.focus)
            if autoStart { start() }
            onEvent?(.breakCompleted(autoStarted: autoStart))
        }
    }

    private func load(_ newPhase: PomodoroPhase) {
        phase = newPhase
        phaseDuration = duration(of: newPhase)
        remaining = phaseDuration
        // A break no longer than the reminder lead time is announced together with
        // its next session when it begins, so it doesn't get a separate reminder.
        hasWarnedNextSession = newPhase.isBreak && phaseDuration <= leadTime
    }

    private func recordPartialFocus() {
        let elapsed = phaseDuration - currentRemaining
        guard elapsed >= 60 else { return }
        sessionFocusTime += elapsed
        stats.addFocus(elapsed, completedSession: false, topicID: settings.currentTopicID)
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
    }
}
