import SwiftUI

struct NotchRootView: View {
    let model: AppModel

    var body: some View {
        NotchSurface(model: model, mode: model.notchMode)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The black notch shape with its content for one mode. Also used for the design preview in settings.
struct NotchSurface: View {
    let model: AppModel
    let mode: NotchMode

    var body: some View {
        let metrics = model.notch.metrics
        let design = model.settings.notchDesign
        let body = NotchLayout.bodySize(mode, metrics, design)
        let radii = NotchLayout.radii(mode, metrics)
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

        ZStack {
            switch mode {
            case .hidden, .idle:
                Color.clear
            case .compact:
                CompactNotchView(model: model, metrics: metrics, design: design)
                    .transition(.blurReplace)
            case .expanded:
                ExpandedNotchView(model: model, metrics: metrics, width: body.width, compact: design == .compact)
                    .transition(.blurReplace.combined(with: .scale(0.92, anchor: .top)))
            case .alert:
                if let alert = model.notch.alert {
                    AlertNotchView(model: model, alert: alert, metrics: metrics, width: body.width, compact: design == .compact)
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
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: mode)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: metrics)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: design)
    }
}

// MARK: - Compact

/// The "live activity" look: pet on one side of the notch, countdown on the other.
private struct CompactNotchView: View {
    let model: AppModel
    let metrics: NotchMetrics
    let design: NotchDesign

    var body: some View {
        let engine = model.engine
        let tint = engine.phase.tint
        let wing = NotchLayout.compactWing(design) - 12
        let compact = design == .compact
        let petSize = max(metrics.notchHeight - (compact ? 12 : 8), 16)

        HStack(spacing: 0) {
            PetView(pet: model.activePet, mood: model.petMood, fallbackSymbol: engine.phase.symbol, tint: tint)
                .frame(width: petSize, height: petSize)
                .frame(width: wing, alignment: .leading)

            Spacer(minLength: metrics.notchWidth)

            HStack(spacing: compact ? 4 : 5) {
                switch engine.state {
                case .running:
                    ProgressRing(progress: engine.progress, tint: tint, lineWidth: compact ? 2 : 2.5)
                        .frame(width: compact ? 10 : 12, height: compact ? 10 : 12)
                case .paused:
                    Image(systemName: "pause.fill").font(.system(size: compact ? 8 : 9, weight: .heavy))
                case .idle:
                    Image(systemName: "play.fill").font(.system(size: compact ? 8 : 9, weight: .heavy))
                }
                Text(TimeFormat.clock(engine.remaining))
                    .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(compact ? 0.7 : 1)
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
    let compact: Bool

    private var engine: PomodoroEngine { model.engine }

    var body: some View {
        let tint = engine.phase.tint
        let side = max((width - metrics.notchWidth) / 2 - 8, 60)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                PhaseBadge(phase: engine.phase, state: engine.state, compact: compact)
                    .frame(width: side, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: compact ? 8 : 10) {
                    TodayBadge(stats: model.stats, showsTime: !compact)
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
            .padding(.horizontal, compact ? 14 : 18)
            .frame(height: metrics.notchHeight)

            HStack(spacing: compact ? 12 : 18) {
                PetAvatar(model: model, tint: tint, compact: compact)
                    .frame(width: compact ? 60 : 92, height: compact ? 60 : 92)

                VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                    Text(subtitle)
                        .font(.system(size: compact ? 11 : 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    Text(TimeFormat.clock(engine.remaining))
                        .font(.system(size: compact ? 30 : 46, weight: .semibold, design: .rounded))
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
                    .padding(.top, compact ? 2 : 4)
                }

                Spacer(minLength: 0)

                ControlsView(engine: engine, tint: tint, compact: compact)
            }
            .padding(.horizontal, compact ? 16 : 22)
            .frame(maxHeight: .infinity)

            TopicBar(model: model, tint: tint)
                .padding(.horizontal, compact ? 16 : 22)
                .padding(.bottom, compact ? 10 : 14)
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
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 5 : 6) {
            Circle()
                .fill(phase.tint)
                .frame(width: 7, height: 7)
                .shadow(color: phase.tint.opacity(0.8), radius: state == .running ? 4 : 0)
            Text(phase.title)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .foregroundStyle(.white)
            if state == .paused {
                Text("Paused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .lineLimit(1)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(phase.tint.opacity(0.16)))
    }
}

private struct TodayBadge: View {
    let stats: StatsStore
    var showsTime = true

    var body: some View {
        let today = stats.today
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Color.orange.gradient)
            Text(verbatim: "\(today.sessions)")
                .foregroundStyle(.white)
            if showsTime {
                Text(verbatim: "·")
                    .foregroundStyle(.white.opacity(0.35))
                Text(TimeFormat.short(today.focusSeconds))
                    .foregroundStyle(.white.opacity(0.7))
            }
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
    var compact = false

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.06))
            ProgressRing(progress: model.engine.progress, tint: tint, lineWidth: compact ? 4 : 5)
            PetView(pet: model.activePet, mood: model.petMood, fallbackSymbol: model.engine.phase.symbol, tint: tint)
                .frame(width: compact ? 42 : 64, height: compact ? 42 : 64)
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
    var compact = false

    var body: some View {
        if compact {
            // One row, with Finish as an icon.
            HStack(spacing: 8) {
                buttons(small: 26, large: 38)
                finishButton
                    .labelStyle(.iconOnly)
                    .buttonStyle(NotchIconButtonStyle(size: 26))
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    buttons(small: 34, large: 50)
                }
                finishButton
                    .buttonStyle(NotchCapsuleButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func buttons(small: CGFloat, large: CGFloat) -> some View {
        Button {
            engine.reset()
        } label: {
            Image(systemName: "arrow.counterclockwise")
        }
        .buttonStyle(NotchIconButtonStyle(size: small))
        .disabled(engine.isPristine)
        .help("Reset")

        Button {
            engine.toggle()
        } label: {
            Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(NotchIconButtonStyle(size: large, tint: tint))
        .help(engine.isRunning ? "Pause" : (engine.state == .paused ? "Resume" : "Start"))

        Button {
            engine.skip()
        } label: {
            Image(systemName: "forward.end.fill")
        }
        .buttonStyle(NotchIconButtonStyle(size: small))
        .help("Skip")
    }

    private var finishButton: some View {
        Button {
            engine.finish()
        } label: {
            Label("Finish", systemImage: "flag.checkered")
        }
        .disabled(!engine.isSessionActive)
        .help("End this session and see your summary")
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

            // Scroll only when the chips don't fit.
            ViewThatFits(in: .horizontal) {
                chips
                ScrollView(.horizontal, showsIndicators: false) { chips }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 24)
        .onChange(of: isFieldFocused) { _, focused in
            if !focused, model.notch.isEditingTopic { finishEditing() }
        }
    }

    private var chips: some View {
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
    let compact: Bool

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: metrics.notchHeight)

            HStack(spacing: compact ? 10 : 14) {
                ZStack {
                    Circle().fill(alert.tint.opacity(0.14))
                    PetView(pet: model.activePet, mood: alert.mood, fallbackSymbol: "bell.fill", tint: alert.tint)
                        .frame(width: compact ? 34 : 48, height: compact ? 34 : 48)
                }
                .frame(width: compact ? 46 : 64, height: compact ? 46 : 64)

                VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                    Text(alert.title)
                        .font(.system(size: compact ? 13 : 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(alert.message)
                        .font(.system(size: compact ? 11 : 12))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(compact ? 2 : 3)
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
                .buttonStyle(NotchIconButtonStyle(size: compact ? 22 : 24))
                .help("Dismiss")
            }
            .padding(.horizontal, compact ? 16 : 20)
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
