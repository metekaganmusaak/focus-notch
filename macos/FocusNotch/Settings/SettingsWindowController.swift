import AppKit
import SwiftUI

/// Classic toolbar-tab preferences window hosting the SwiftUI panes.
final class SettingsWindowController: NSWindowController {
    init(model: AppModel) {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab(TimerSettingsView(model: model), String(localized: "Timer"), "timer"))
        tabs.addTabViewItem(Self.tab(PetSettingsView(model: model), String(localized: "Focus Friend"), "pawprint.fill"))
        tabs.addTabViewItem(Self.tab(StatisticsSettingsView(model: model), String(localized: "Statistics"), "chart.bar.fill"))
        tabs.addTabViewItem(Self.tab(NotificationSettingsView(model: model), String(localized: "Notifications"), "bell.badge.fill"))
        tabs.addTabViewItem(Self.tab(GeneralSettingsView(model: model), String(localized: "General"), "gearshape"))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.title = tabs.tabViewItems.first?.label ?? ""
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private static func tab(_ view: some View, _ title: String, _ symbol: String) -> NSTabViewItem {
        let host = NSHostingController(rootView: view)
        host.sizingOptions = [.preferredContentSize]
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}

/// Names the window after the selected tab, like System Settings panes.
private final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? ""
    }
}
