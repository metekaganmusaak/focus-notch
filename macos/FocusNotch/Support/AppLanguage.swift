import AppKit

/// In-app language override. macOS reads `AppleLanguages` from the app's own
/// defaults domain at launch, so a change takes effect after a relaunch.
enum AppLanguage {
    static let codes = [
        "en", "zh-Hans", "zh-Hant", "hi", "es", "fr", "ar", "bn", "pt-BR", "ru", "ur",
        "id", "de", "ja", "tr", "ko", "vi", "it", "fa", "pl", "uk", "th", "nl",
    ]

    private static let defaultsKey = "AppleLanguages"

    static func nativeName(for code: String) -> String {
        let locale = Locale(identifier: code)
        let name = locale.localizedString(forIdentifier: code) ?? code
        return name.capitalized(with: locale)
    }

    /// The language chosen in the app, or "" when following the system.
    static var override: String {
        get {
            let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            return (domain?[defaultsKey] as? [String])?.first ?? ""
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            } else {
                UserDefaults.standard.set([newValue], forKey: defaultsKey)
            }
        }
    }

    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.6; /usr/bin/open \"$0\"", Bundle.main.bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
