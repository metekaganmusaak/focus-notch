import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

private let paneWidth: CGFloat = 500

// MARK: - Timer

struct TimerSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Section("Durations") {
                MinutesSlider(title: "Focus", value: $settings.focusMinutes, range: 5...120, tint: PomodoroPhase.focus.tint)
                MinutesSlider(title: "Short Break", value: $settings.shortBreakMinutes, range: 1...30, tint: PomodoroPhase.shortBreak.tint)
                MinutesSlider(title: "Long Break", value: $settings.longBreakMinutes, range: 5...60, tint: PomodoroPhase.longBreak.tint)
                Stepper(value: $settings.sessionsBeforeLongBreak, in: 2...12) {
                    LabeledContent("Sessions before a long break") {
                        Text(verbatim: "\(settings.sessionsBeforeLongBreak)")
                            .monospacedDigit()
                    }
                }
            }

            Section {
                Toggle("Start breaks automatically", isOn: $settings.autoStartBreaks)
                Toggle("Start focus sessions automatically", isOn: $settings.autoStartFocus)
            } header: {
                Text("Automation")
            } footer: {
                Text("Changes apply to the next phase if a timer is already running.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: paneWidth, height: 500)
    }
}

/// A duration you can drag, type in, or nudge with the arrow keys.
private struct MinutesSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(title)
                Spacer()
                TextField(value: clamped, format: .number) {
                    Text(title)
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 52)
                Text("min")
                    .foregroundStyle(.secondary)
            }
            Slider(value: sliderValue, in: Double(range.lowerBound)...Double(range.upperBound), step: 1) {
                Text(title)
            } minimumValueLabel: {
                Text(verbatim: "\(range.lowerBound)").font(.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(verbatim: "\(range.upperBound)").font(.caption).foregroundStyle(.secondary)
            }
            .labelsHidden()
            .tint(tint)
        }
        .padding(.vertical, 2)
    }

    private var sliderValue: Binding<Double> {
        Binding { Double(value) } set: { value = Int($0.rounded()) }
    }

    /// Typed values outside the slider's range are pulled back into it.
    private var clamped: Binding<Int> {
        Binding { value } set: { value = min(max($0, range.lowerBound), range.upperBound) }
    }
}

// MARK: - Focus Friend

struct PetSettingsView: View {
    let model: AppModel
    @State private var importError: String?
    @State private var isDropTargeted = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Section {
                Toggle("Show focus friend", isOn: $settings.showPet)
                Toggle("Pet sounds", isOn: $settings.petSoundsEnabled)
                    .disabled(!settings.showPet)
            } footer: {
                Text("Your friend works alongside you during focus sessions and naps during breaks.")
                    .foregroundStyle(.secondary)
            }

            Section("Choose your companion") {
                Picker("Style", selection: $settings.petStyle) {
                    ForEach(PetStyle.allCases, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!settings.showPet)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.pets.all(style: settings.petStyle)) { pet in
                        PetCard(pet: pet, isSelected: pet.id == settings.selectedPetID) {
                            settings.selectedPetID = pet.id
                        } onRemove: {
                            remove(pet)
                        }
                    }
                    AddPetCard(isTargeted: isDropTargeted, action: chooseGIF)
                }
                .padding(.vertical, 6)
                .disabled(!settings.showPet)
                .opacity(settings.showPet ? 1 : 0.5)

                Text("Add your own pet: drop an animated GIF here or click +.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let importError {
                    Label(importError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: paneWidth, height: 620)
        .dropDestination(for: URL.self) { urls, _ in
            let gifs = urls.filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .gif) == true }
            gifs.forEach(importGIF)
            return !gifs.isEmpty
        } isTargeted: {
            isDropTargeted = $0
        }
    }

    private func chooseGIF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "Choose an animated GIF for your focus friend")
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(importGIF)
    }

    private func importGIF(_ url: URL) {
        do {
            let pet = try model.pets.importGIF(from: url)
            model.settings.selectedPetID = pet.id
            importError = nil
        } catch {
            importError = String(localized: "This file couldn't be added. Please choose a valid GIF.")
        }
    }

    private func remove(_ pet: Pet) {
        if model.settings.selectedPetID == pet.id {
            model.settings.selectedPetID = PetStore.defaultPetID
        }
        model.pets.remove(pet)
    }
}

private struct PetCard: View {
    let pet: Pet
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.08).gradient)
                    AnimatedGIFView(url: pet.url(for: isSelected ? .celebrate : .idle), pixelated: pet.isPixelArt)
                        .frame(width: 56, height: 56)
                }
                .frame(height: 78)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                }
                .overlay(alignment: .topTrailing) {
                    if pet.isCustom {
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(5)
                        .help("Remove")
                    }
                }

                Text(pet.name)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if pet.isCustom {
                Button("Remove", role: .destructive, action: onRemove)
            }
        }
    }
}

private struct AddPetCard: View {
    let isTargeted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isTargeted ? Color.accentColor.opacity(0.12) : .clear)
                    )
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 78)
                Text("Add GIF…")
                    .font(.callout)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        let notifications = model.notifications

        Form {
            Section {
                Toggle("Show notifications", isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { _, enabled in
                        if enabled { Task { await notifications.requestAuthorization() } }
                    }
                Toggle("Play sounds", isOn: $settings.soundEnabled)

                if settings.notificationsEnabled, notifications.authorization == .denied {
                    HStack {
                        Label("Notifications are turned off for Focus Notch in System Settings.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open System Settings") { notifications.openSystemSettings() }
                    }
                }
            }

            Section {
                Picker("Remind me before the next session", selection: $settings.reminderLeadMinutes) {
                    ForEach(SettingsStore.reminderChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
            } footer: {
                Text("During a break you'll get a heads-up before the next focus session begins. Breaks shorter than this are announced as soon as they start.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Send Test Notification") {
                    Task {
                        await notifications.requestAuthorization()
                        notifications.post(
                            title: String(localized: "Focus Notch"),
                            body: String(localized: "Notifications are working. Stay focused!")
                        )
                        if settings.soundEnabled { NSSound(named: "chime_break")?.play() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: paneWidth, height: 380)
        .task { await notifications.refreshStatus() }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    let model: AppModel
    @State private var language = AppLanguage.override
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    private let launchLanguage = AppLanguage.override

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Section {
                Picker("Language", selection: $language) {
                    Text("System Default").tag("")
                    Divider()
                    ForEach(AppLanguage.codes, id: \.self) { code in
                        Text(verbatim: AppLanguage.nativeName(for: code)).tag(code)
                    }
                }
                .onChange(of: language) { _, newValue in
                    AppLanguage.override = newValue
                }
                if language != launchLanguage {
                    HStack {
                        Text("Restart Focus Notch to apply the new language.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { AppLanguage.relaunch() }
                    }
                }
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let loginError {
                    Text(loginError).foregroundStyle(.orange)
                }
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
            }

            Section("Theme") {
                ThemePicker(selection: $settings.theme)
            }

            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: paneWidth, height: 470)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct ThemePicker: View {
    @Binding var selection: Theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Theme.allCases) { theme in
                Button {
                    selection = theme
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(theme.color(for: .focus))
                            HStack(spacing: 3) {
                                Circle().fill(theme.color(for: .shortBreak))
                                Circle().fill(theme.color(for: .longBreak))
                            }
                            .frame(width: 20, height: 9)
                            .offset(y: 9)
                        }
                        .frame(width: 34, height: 34)
                        .padding(3)
                        .overlay {
                            Circle().strokeBorder(selection == theme ? Color.accentColor : .clear, lineWidth: 2)
                        }
                        Text(theme.title)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(selection == theme ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Statistics

struct StatisticsSettingsView: View {
    let model: AppModel
    @State private var period = StatsStore.Period.today
    @State private var newTopic = ""

    var body: some View {
        let totals = model.stats.totals(in: period)
        let rows = model.stats.topicTotals(in: period, knownTopics: Set(model.topics.topics.map(\.id)))
        let longest = rows.first?.totals.focusSeconds ?? 1

        Form {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(StatsStore.Period.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 12) {
                    StatTile(title: "Focus time", value: TimeFormat.short(totals.focusSeconds), symbol: "clock.fill")
                    StatTile(title: "Completed sessions", value: "\(totals.sessions)", symbol: "flame.fill")
                }
                .padding(.vertical, 4)

                if rows.isEmpty {
                    Text("No focus time yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { row in
                        TopicBarRow(
                            name: model.topics.topic(withID: row.topicID)?.name ?? String(localized: "No topic"),
                            totals: row.totals,
                            fraction: row.totals.focusSeconds / max(longest, 1),
                            tint: row.topicID == nil ? .secondary : PomodoroPhase.focus.tint
                        )
                    }
                }
            }

            Section {
                ForEach(model.topics.topics) { topic in
                    HStack {
                        Text(topic.name)
                        if model.settings.currentTopicID == topic.id {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            model.removeTopic(topic)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove")
                    }
                }
                HStack {
                    TextField("New topic", text: $newTopic)
                        .onSubmit(addTopic)
                    Button("Add", action: addTopic)
                        .disabled(newTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Topics")
            } footer: {
                Text("Pick a topic in the notch before you start, and your focus time is counted under it.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset Today's Statistics", role: .destructive) {
                    model.stats.resetToday()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: paneWidth, height: 560)
    }

    private func addTopic() {
        if model.topics.add(named: newTopic) != nil { newTopic = "" }
    }
}

private struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.6)))
    }
}

private struct TopicBarRow: View {
    let name: String
    let totals: StatsStore.Totals
    let fraction: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).lineLimit(1)
                Spacer()
                Text(TimeFormat.short(totals.focusSeconds))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: max(proxy.size.width * fraction, 6))
                    }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
    }
}
