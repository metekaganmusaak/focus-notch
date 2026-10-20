import SwiftUI

struct NotchRootView: View {
    let model: AppModel

    var body: some View {
        let mode = model.notchMode
        let metrics = model.notch.metrics
        let body = NotchLayout.bodySize(mode, metrics)
        let radii = NotchLayout.radii(mode, metrics)
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

        ZStack {
            switch mode {
            case .hidden, .idle:
                Color.clear
            case .compact:
                CompactNotchView(model: model, metrics: metrics)
                    .transition(.blurReplace)
            case .expanded:
                ExpandedNotchView(model: model, metrics: metrics, width: body.width)
                    .transition(.blurReplace.combined(with: .scale(0.92, anchor: .top)))
            case .alert:
                if let alert = model.notch.alert {
                    AlertNotchView(model: model, alert: alert, metrics: metrics, width: body.width)
                        .transition(.blurReplace.combined(with: .scale(0.92, anchor: .top)))
                }
            }
        }
        .frame(width: body.width, height: body.height)
        .padding(.horizontal, radii.top)
        .background(shape.fill(.black))
        .clipShape(shape)
        .shadow(color: .black.opacity(mode.isOpen ? 0.45 : 0), radius: 18, y: 8)
        .opacity(mode == .hidden ? 0 : 1)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: mode)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: metrics)
    }
}

// MARK: - Compact

/// The "live activity" look: pet on one side of the notch, countdown on the other.
private struct CompactNotchView: View {
    let model: AppModel
    let metrics: NotchMetrics

    var body: some View {
        let engine = model.engine
        let tint = engine.phase.tint
        let wing = NotchLayout.compactWing - 12

        HStack(spacing: 0) {
            PetView(pet: model.activePet, mood: model.petMood, fallbackSymbol: engine.phase.symbol, tint: tint)
                .frame(width: max(metrics.notchHeight - 8, 16), height: max(metrics.notchHeight - 8, 16))
                .frame(width: wing, alignment: .leading)

            Spacer(minLength: metrics.notchWidth)

            HStack(spacing: 5) {
                switch engine.state {
                case .running:
                    ProgressRing(progress: engine.progress, tint: tint, lineWidth: 2.5)
                        .frame(width: 12, height: 12)
                case .paused:
                    Image(systemName: "pause.fill").font(.system(size: 9, weight: .heavy))
                case .idle:
                    Image(systemName: "play.fill").font(.system(size: 9, weight: .heavy))
                }
                Text(TimeFormat.clock(engine.remaining))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: engine.remaining)
            }
            .foregroundStyle(tint)
            .opacity(engine.state == .running ? 1 : 0.7)
            .frame(width: wing, alignment: .trailing)
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - Expanded

private struct ExpandedNotchView: View {
    let model: AppModel
    let metrics: NotchMetrics
    let width: CGFloat

    private var engine: PomodoroEngine { model.engine }

    var body: some View {
        let tint = engine.phase.tint
        let side = max((width - metrics.notchWidth) / 2 - 8, 60)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                PhaseBadge(phase: engine.phase, state: engine.state)
                    .frame(width: side, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    TodayBadge(stats: model.stats)
                    Button {
                        model.openSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(NotchIconButtonStyle(size: 22))
                    .help("Settings")
                }
                .frame(width: side, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .frame(height: metrics.notchHeight)

            HStack(spacing: 18) {
                PetAvatar(model: model, tint: tint)
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    Text(TimeFormat.clock(engine.remaining))
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: engine.remaining)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    SessionDots(
                        total: engine.sessionsPerCycle,
                        completed: engine.completedInCycle,
                        currentProgress: engine.phase == .focus ? engine.progress : nil,
                        tint: PomodoroPhase.focus.tint
                    )
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)

                ControlsView(engine: engine, tint: tint)
            }
            .padding(.horizontal, 22)
            .frame(maxHeight: .infinity)

            TopicBar(model: model, tint: tint)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
        }
    }

    private var subtitle: String {
        if !engine.isSessionActive, engine.isPristine {
            return String(localized: "Ready to focus?")
        }
        if engine.phase == .focus {
            let round = min(engine.completedInCycle + 1, engine.sessionsPerCycle)
            return String(localized: "Round \(round) of \(engine.sessionsPerCycle)")
        }
        return String(localized: "Up next: \(PomodoroPhase.focus.title)")
    }
}

private struct PhaseBadge: View {
    let phase: PomodoroPhase
    let state: TimerState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phase.tint)
                .frame(width: 7, height: 7)
                .shadow(color: phase.tint.opacity(0.8), radius: state == .running ? 4 : 0)
            Text(phase.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            if state == .paused {
                Text("Paused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(phase.tint.opacity(0.16)))
    }
}

private struct TodayBadge: View {
    let stats: StatsStore

    var body: some View {
        let today = stats.today
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Color.orange.gradient)
            Text(verbatim: "\(today.sessions)")
                .foregroundStyle(.white)
            Text(verbatim: "·")
                .foregroundStyle(.white.opacity(0.35))
            Text(TimeFormat.short(today.focusSeconds))
                .foregroundStyle(.white.opacity(0.7))
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .help("Focus time today")
    }
}

/// The pet inside a ring that fills up as the phase progresses. Click the pet to cheer it up.
private struct PetAvatar: View {
    let model: AppModel
    let tint: Color

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.06))
            ProgressRing(progress: model.engine.progress, tint: tint, lineWidth: 5)
            PetView(pet: model.activePet, mood: model.petMood, fallbackSymbol: model.engine.phase.symbol, tint: tint)
                .frame(width: 64, height: 64)
        }
        .contentShape(Circle())
        .onTapGesture {
            model.petTapped()
        }
    }
}

private struct ControlsView: View {
    let engine: PomodoroEngine
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    engine.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(NotchIconButtonStyle(size: 34))
                .disabled(engine.isPristine)
                .help("Reset")

                Button {
                    engine.toggle()
                } label: {
                    Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(NotchIconButtonStyle(size: 50, tint: tint))
                .help(engine.isRunning ? "Pause" : (engine.state == .paused ? "Resume" : "Start"))

                Button {
                    engine.skip()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(NotchIconButtonStyle(size: 34))
                .help("Skip")
            }

            Button {
                engine.finish()
            } label: {
                Label("Finish", systemImage: "flag.checkered")
            }
            .buttonStyle(NotchCapsuleButtonStyle())
            .disabled(!engine.isSessionActive)
            .help("End this session and see your summary")
        }
    }
}

/// Topic chips: click one to log focus time under it, click it again to clear,
/// or add a new topic by typing.
private struct TopicBar: View {
    let model: AppModel
    let tint: Color
    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.topics.topics) { topic in
                        let isSelected = model.settings.currentTopicID == topic.id
                        Button(topic.name) {
                            model.settings.currentTopicID = isSelected ? nil : topic.id
                        }
                        .buttonStyle(TopicChipStyle(tint: isSelected ? tint : nil))
                    }

                    if model.notch.isEditingTopic {
                        TextField("New topic", text: $draft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .focused($isFieldFocused)
                            .frame(width: 120)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().strokeBorder(tint.opacity(0.8), lineWidth: 1.2))
                            .onSubmit(commit)
                            .onExitCommand(perform: finishEditing)
                    } else {
                        Button {
                            startEditing()
                        } label: {
                            if model.topics.topics.isEmpty {
                                Label("Add topic", systemImage: "plus")
                            } else {
                                Image(systemName: "plus")
                            }
                        }
                        .buttonStyle(TopicChipStyle(tint: nil))
                        .help("Add topic")
                    }
                }
            }
        }
        .frame(height: 24)
        .onChange(of: isFieldFocused) { _, focused in
            if !focused, model.notch.isEditingTopic { finishEditing() }
        }
    }

    private func startEditing() {
        draft = ""
        model.notch.isEditingTopic = true
        model.notch.requestKeyboard?()
        Task { isFieldFocused = true }
    }

    private func commit() {
        if let topic = model.topics.add(named: draft) {
            model.settings.currentTopicID = topic.id
        }
        finishEditing()
    }

    private func finishEditing() {
        model.notch.isEditingTopic = false
        isFieldFocused = false
        model.notch.releaseKeyboard?()
    }
}

private struct TopicChipStyle: ButtonStyle {
    let tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(tint == nil ? Color.white.opacity(0.75) : Color.black.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.white.opacity(0.1))))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Alert

private struct AlertNotchView: View {
    let model: AppModel
    let alert: NotchAlert
    let metrics: NotchMetrics
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: metrics.notchHeight)

            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(alert.tint.opacity(0.14))
                    PetView(pet: model.activePet, mood: alert.mood, fallbackSymbol: "bell.fill", tint: alert.tint)
                        .frame(width: 48, height: 48)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(alert.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if let action = alert.action {
                    Button(action.title) {
                        model.performAlertAction()
                    }
                    .buttonStyle(NotchCapsuleButtonStyle(tint: alert.tint))
                }

                Button {
                    model.notch.dismissAlert()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(NotchIconButtonStyle(size: 24))
                .help("Dismiss")
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Components

struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .padding(lineWidth / 2)
    }
}

private struct SessionDots: View {
    let total: Int
    let completed: Int
    /// Progress of the focus round in flight, or nil during a break.
    let currentProgress: Double?
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                let isCurrent = currentProgress != nil && index == completed
                Capsule()
                    .fill(.white.opacity(0.14))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(tint)
                                .frame(width: proxy.size.width * fill(for: index))
                        }
                    }
                    .clipShape(Capsule())
                    .frame(width: isCurrent ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completed)
    }

    private func fill(for index: Int) -> Double {
        if index < completed { return 1 }
        if index == completed, let currentProgress { return currentProgress }
        return 0
    }
}

struct NotchIconButtonStyle: ButtonStyle {
    var size: CGFloat
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, size: size, tint: tint)
    }

    private struct IconButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let size: CGFloat
        let tint: Color?
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(tint == nil ? Color.white : Color.black.opacity(0.85))
                .frame(width: size, height: size)
                .background {
                    if let tint {
                        Circle().fill(tint.gradient)
                            .shadow(color: tint.opacity(0.5), radius: isHovered ? 10 : 6)
                    } else {
                        Circle().fill(.white.opacity(isHovered ? 0.2 : 0.11))
                    }
                }
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .opacity(isEnabled ? 1 : 0.35)
                .onHover { isHovered = $0 }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
    }
}

struct NotchCapsuleButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        CapsuleButtonBody(configuration: configuration, tint: tint)
    }

    private struct CapsuleButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color?
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(tint == nil ? Color.white : Color.black.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(tint.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(.white.opacity(isHovered ? 0.2 : 0.11))))
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .opacity(isEnabled ? 1 : 0.35)
                .onHover { isHovered = $0 }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
}
