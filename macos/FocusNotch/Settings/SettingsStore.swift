import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
@Observable
final class SettingsStore {
    private enum Keys {
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let sessionsBeforeLongBreak = "sessionsBeforeLongBreak"
        static let autoStartBreaks = "autoStartBreaks"
        static let autoStartFocus = "autoStartFocus"
        static let reminderLeadMinutes = "reminderLeadMinutes"
        static let notificationsEnabled = "notificationsEnabled"
        static let soundEnabled = "soundEnabled"
        static let showPet = "showPet"
        static let selectedPetID = "selectedPetID"
        static let petStyle = "petStyle"
        static let petSoundsEnabled = "petSoundsEnabled"
        static let theme = "theme"
        static let currentTopicID = "currentTopicID"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    static let reminderChoices = [1, 2, 3, 5, 10, 15]

    @ObservationIgnored private let defaults = UserDefaults.standard
    /// Called when a duration changes so an idle timer can pick it up.
    @ObservationIgnored var onTimingChange: (() -> Void)?

    var focusMinutes: Int {
        didSet { defaults.set(focusMinutes, forKey: Keys.focusMinutes); onTimingChange?() }
    }
    var shortBreakMinutes: Int {
        didSet { defaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes); onTimingChange?() }
    }
    var longBreakMinutes: Int {
        didSet { defaults.set(longBreakMinutes, forKey: Keys.longBreakMinutes); onTimingChange?() }
    }
    var sessionsBeforeLongBreak: Int {
        didSet { defaults.set(sessionsBeforeLongBreak, forKey: Keys.sessionsBeforeLongBreak) }
    }
    var autoStartBreaks: Bool {
        didSet { defaults.set(autoStartBreaks, forKey: Keys.autoStartBreaks) }
    }
    var autoStartFocus: Bool {
        didSet { defaults.set(autoStartFocus, forKey: Keys.autoStartFocus) }
    }
    var reminderLeadMinutes: Int {
        didSet { defaults.set(reminderLeadMinutes, forKey: Keys.reminderLeadMinutes); onTimingChange?() }
    }
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }
    var showPet: Bool {
        didSet { defaults.set(showPet, forKey: Keys.showPet) }
    }
    var selectedPetID: String {
        didSet { defaults.set(selectedPetID, forKey: Keys.selectedPetID) }
    }
    var petStyle: PetStyle {
        didSet { defaults.set(petStyle.rawValue, forKey: Keys.petStyle) }
    }
    var petSoundsEnabled: Bool {
        didSet { defaults.set(petSoundsEnabled, forKey: Keys.petSoundsEnabled) }
    }
    var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    /// The topic new focus time is logged under, or nil for none.
    var currentTopicID: String? {
        didSet { defaults.set(currentTopicID, forKey: Keys.currentTopicID) }
    }
    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    init() {
        defaults.register(defaults: [
            Keys.focusMinutes: 25,
            Keys.shortBreakMinutes: 5,
            Keys.longBreakMinutes: 15,
            Keys.sessionsBeforeLongBreak: 4,
            Keys.autoStartBreaks: true,
            Keys.autoStartFocus: true,
            Keys.reminderLeadMinutes: 5,
            Keys.notificationsEnabled: true,
            Keys.soundEnabled: true,
            Keys.showPet: true,
            Keys.selectedPetID: PetStore.defaultPetID,
            Keys.petStyle: PetStyle.cute.rawValue,
            Keys.petSoundsEnabled: true,
            Keys.theme: Theme.coral.rawValue,
            Keys.showMenuBarIcon: true,
        ])
        focusMinutes = defaults.integer(forKey: Keys.focusMinutes)
        shortBreakMinutes = defaults.integer(forKey: Keys.shortBreakMinutes)
        longBreakMinutes = defaults.integer(forKey: Keys.longBreakMinutes)
        sessionsBeforeLongBreak = defaults.integer(forKey: Keys.sessionsBeforeLongBreak)
        autoStartBreaks = defaults.bool(forKey: Keys.autoStartBreaks)
        autoStartFocus = defaults.bool(forKey: Keys.autoStartFocus)
        reminderLeadMinutes = defaults.integer(forKey: Keys.reminderLeadMinutes)
        notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        showPet = defaults.bool(forKey: Keys.showPet)
        selectedPetID = defaults.string(forKey: Keys.selectedPetID) ?? PetStore.defaultPetID
        petStyle = PetStyle(rawValue: defaults.string(forKey: Keys.petStyle) ?? "") ?? .cute
        petSoundsEnabled = defaults.bool(forKey: Keys.petSoundsEnabled)
        theme = Theme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .coral
        currentTopicID = defaults.string(forKey: Keys.currentTopicID)
        showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
    }
}
