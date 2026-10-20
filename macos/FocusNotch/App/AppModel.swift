import AppKit
import Observation

/// Owns every store and wires timer events to the notch, sounds and notifications.
@Observable
final class AppModel {
    static let shared = AppModel()

    let settings = SettingsStore()
    let stats = StatsStore()
    let pets = PetStore()
    let topics = TopicStore()
    let notifications = NotificationManager()
    let notch = NotchState()
    let engine: PomodoroEngine

    @ObservationIgnored private var settingsWindow: SettingsWindowController?

    private init() {
        engine = PomodoroEngine(settings: settings, stats: stats)
        engine.onEvent = { [weak self] event in self?.handle(event) }
        settings.onTimingChange = { [weak self] in self?.engine.settingsDidChange() }
    }

    func start() {
        notifications.configure()
        if settings.notificationsEnabled {
            Task { await notifications.requestAuthorization() }
        }
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(model: self)
        }
        settingsWindow?.show()
    }

    // MARK: - Derived state

    var notchMode: NotchMode {
        if notch.alert != nil { return .alert }
        if notch.isHovering || notch.isEditingTopic || notch.isPeeking { return .expanded }
        if engine.isSessionActive { return .compact }
        return notch.metrics.hasNotch ? .idle : .hidden
    }

    /// The pet shown in the notch, or nil when the user turned the focus friend off.
    var activePet: Pet? {
        guard settings.showPet else { return nil }
        return pets.pet(withID: settings.selectedPetID, style: settings.petStyle)
            ?? PetStore.builtIn(style: settings.petStyle)[0]
    }

    var petMood: PetMood {
        if let reaction = notch.petReaction { return reaction }
        switch engine.state {
        case .running: return engine.phase == .focus ? .focus : .rest
        case .paused, .idle: return .idle
        }
    }

    var currentTopic: Topic? {
        topics.topic(withID: settings.currentTopicID)
    }

    func removeTopic(_ topic: Topic) {
        if settings.currentTopicID == topic.id { settings.currentTopicID = nil }
        topics.remove(topic)
    }

    /// Clicking the pet makes it cheer and, for some animals, make a sound.
    func petTapped() {
        notch.react(.celebrate)
        guard settings.petSoundsEnabled, let name = activePet?.soundName, let sound = NSSound(named: name) else { return }
        sound.stop()
        sound.play()
    }

    // MARK: - Events

    private func handle(_ event: PomodoroEvent) {
        let alert = makeAlert(for: event)
        notch.present(alert)
        if settings.soundEnabled {
            NSSound(named: alert.sound)?.play()
        }
        if settings.notificationsEnabled {
            notifications.post(title: alert.title, body: alert.message)
        }
    }

    private func makeAlert(for event: PomodoroEvent) -> NotchAlert {
        switch event {
        case let .focusCompleted(next, autoStarted):
            let length = engine.duration(of: next)
            let title = next == .longBreak
                ? String(localized: "Time for a long break!")
                : String(localized: "Time for a break!")
            var message: String
            if autoStarted {
                let spelled = TimeFormat.spelledOut(length)
                message = String(localized: "Great focus! Relax for \(spelled).")
                if settings.autoStartFocus, length <= TimeInterval(settings.reminderLeadMinutes * 60) {
                    message += " " + String(localized: "Your next focus session starts in \(spelled).")
                }
            } else {
                message = String(localized: "Great focus! Start your break whenever you're ready.")
            }
            return NotchAlert(
                title: title, message: message, tint: next.tint, mood: .celebrate, sound: "chime_break",
                action: autoStarted ? nil : .init(title: String(localized: "Start Break"))
            )

        case let .breakCompleted(autoStarted):
            return NotchAlert(
                title: String(localized: "Break's over!"),
                message: autoStarted
                    ? String(localized: "Your next focus session has started. You've got this!")
                    : String(localized: "Ready for the next focus session?"),
                tint: PomodoroPhase.focus.tint, mood: .idle, sound: "chime_focus",
                action: autoStarted ? nil : .init(title: String(localized: "Start Focus"))
            )

        case let .nextSessionSoon(remaining):
            let spelled = TimeFormat.spelledOut(remaining)
            return NotchAlert(
                title: String(localized: "Heads up!"),
                message: settings.autoStartFocus
                    ? String(localized: "Your next focus session starts in \(spelled).")
                    : String(localized: "Your break ends in \(spelled)."),
                tint: engine.phase.tint, mood: .idle, sound: "chime_reminder", action: nil
            )

        case let .finished(focusTime, sessions):
            guard focusTime >= 60 else {
                return NotchAlert(
                    title: String(localized: "Session finished"),
                    message: String(localized: "See you next time!"),
                    tint: PomodoroPhase.focus.tint, mood: .idle, sound: "chime_finish", action: nil
                )
            }
            let time = TimeFormat.short(focusTime)
            return NotchAlert(
                title: String(localized: "Great work!"),
                message: String(localized: "Focus time: \(time) · Sessions: \(sessions)"),
                tint: PomodoroPhase.focus.tint, mood: .celebrate, sound: "chime_finish", action: nil
            )
        }
    }

    func performAlertAction() {
        notch.dismissAlert()
        engine.start()
    }
}
