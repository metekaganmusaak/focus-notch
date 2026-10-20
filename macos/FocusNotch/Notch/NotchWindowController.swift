import AppKit
import SwiftUI

/// Borderless panel that sits above the menu bar, on every Space and over full-screen apps.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Keep the panel pinned to the very top of the screen, over the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Lets the first click on a button work without activating the app first.
final class NotchHostingView: NSHostingView<NotchRootView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class NotchWindowController {
    private let model: AppModel
    private let panel: NotchPanel
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var hoverTask: Task<Void, Never>?
    /// The app that had keyboard focus before the user started typing in the notch.
    private var previousApp: NSRunningApplication?

    init(model: AppModel) {
        self.model = model
        panel = NotchPanel(contentRect: NSRect(origin: .zero, size: NotchLayout.windowSize))

        let hostingView = NotchHostingView(rootView: NotchRootView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        model.notch.requestKeyboard = { [weak self] in
            guard let self else { return }
            previousApp = NSWorkspace.shared.frontmostApplication
            panel.makeKey()
        }
        model.notch.releaseKeyboard = { [weak self] in
            self?.previousApp?.activate()
            self?.previousApp = nil
        }

        reposition()
        panel.orderFrontRegardless()
        installMouseMonitors()
        observeScreens()
        observeMode()
    }

    deinit {
        monitors.forEach(NSEvent.removeMonitor)
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    // MARK: - Placement

    private var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func reposition() {
        guard let screen else { return }
        model.notch.metrics = NotchMetrics(screen: screen)
        let size = NotchLayout.windowSize
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
    }

    private func observeScreens() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    // MARK: - Mouse

    /// Hover is tracked with event monitors rather than tracking areas because the
    /// panel ignores mouse events while collapsed so clicks reach the menu bar.
    private func installMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func isPointerInside() -> Bool {
        guard let screen else { return false }
        let mode = model.notchMode
        let size = NotchLayout.frameSize(mode, model.notch.metrics, model.settings.notchDesign)
        // Once open, allow some slack so small overshoots don't collapse the panel.
        let slack: CGFloat = mode.isOpen ? 14 : 2
        let zone = NSRect(
            x: screen.frame.midX - size.width / 2 - slack,
            y: screen.frame.maxY - size.height - slack,
            width: size.width + slack * 2,
            height: size.height + slack + 4
        )
        return zone.contains(NSEvent.mouseLocation)
    }

    private func mouseMoved() {
        let inside = isPointerInside()
        guard inside != model.notch.isHovering else {
            hoverTask?.cancel()
            return
        }
        hoverTask?.cancel()
        // A short delay on entry avoids opening when the pointer just passes by;
        // a longer one on exit forgives quick wiggles outside the panel.
        let delay: Duration = inside ? .milliseconds(90) : .milliseconds(280)
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            if self.isPointerInside() == inside {
                self.model.notch.isHovering = inside
            }
        }
    }

    /// Accept clicks only while the panel is open.
    private func observeMode() {
        let mode = withObservationTracking {
            model.notchMode
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.observeMode() }
        }
        panel.ignoresMouseEvents = !mode.isOpen
    }
}
