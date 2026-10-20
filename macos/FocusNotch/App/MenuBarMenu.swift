import SwiftUI

struct MenuBarLabel: View {
    let engine: PomodoroEngine

    var body: some View {
        Image(systemName: engine.isRunning ? "timer.circle.fill" : "timer")
    }
}

struct MenuBarMenu: View {
    let model: AppModel

    var body: some View {
        let engine = model.engine
        @Bindable var settings = model.settings

        Text(status)

        Divider()

        Button(primaryTitle) { engine.toggle() }
        Button("Skip") { engine.skip() }
        Button("Reset") { engine.reset() }
            .disabled(engine.isPristine)
        Button("Finish Session") { engine.finish() }
            .disabled(!engine.isSessionActive)

        Divider()

        Picker("Focus Friend", selection: $settings.selectedPetID) {
            ForEach(model.pets.all(style: settings.petStyle)) { pet in
                Text(pet.name).tag(pet.id)
            }
        }
        Toggle("Show Focus Friend", isOn: $settings.showPet)

        Picker("Topic", selection: $settings.currentTopicID) {
            Text("No topic").tag(String?.none)
            ForEach(model.topics.topics) { topic in
                Text(topic.name).tag(String?.some(topic.id))
            }
        }

        Divider()

        Button("Settings…") { model.openSettings() }
            .keyboardShortcut(",")
        Button("Quit Focus Notch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var status: String {
        let engine = model.engine
        guard engine.isSessionActive || !engine.isPristine else {
            return String(localized: "Ready to focus?")
        }
        return "\(engine.phase.title) · \(TimeFormat.clock(engine.remaining))"
    }

    private var primaryTitle: String {
        let engine = model.engine
        switch engine.state {
        case .running: return String(localized: "Pause")
        case .paused: return String(localized: "Resume")
        case .idle: return engine.phase == .focus ? String(localized: "Start Focus") : String(localized: "Start Break")
        }
    }
}
