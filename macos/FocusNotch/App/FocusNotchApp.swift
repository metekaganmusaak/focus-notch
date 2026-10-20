import SwiftUI

@main
struct FocusNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Bindable private var settings = AppModel.shared.settings

    var body: some Scene {
        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
            MenuBarMenu(model: AppModel.shared)
        } label: {
            MenuBarLabel(engine: AppModel.shared.engine)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        model.start()
        notchController = NotchWindowController(model: model)
    }

    /// Opening the app again from Finder or Spotlight shows the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppModel.shared.openSettings()
        return false
    }
}
