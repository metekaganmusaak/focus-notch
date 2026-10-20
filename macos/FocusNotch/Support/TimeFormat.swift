import Foundation

enum TimeFormat {
    /// "24:59" or "1:05:00".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.up))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    /// "5 minutes", "1 hour, 30 minutes" in the app's language.
    static func spelledOut(_ seconds: TimeInterval) -> String {
        format(seconds, style: .full)
    }

    /// "5 min", "1 hr, 30 min" in the app's language.
    static func short(_ seconds: TimeInterval) -> String {
        format(seconds, style: .abbreviated)
    }

    /// The locale matching the localization the app actually loaded, which can differ
    /// from the system locale when the user picks a language in settings.
    static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    private static func format(_ seconds: TimeInterval, style: DateComponentsFormatter.UnitsStyle) -> String {
        let value = max((seconds / 60).rounded(), 0) * 60
        var calendar = Calendar.current
        calendar.locale = appLocale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = style
        formatter.allowedUnits = value >= 3600 ? [.hour, .minute] : [.minute]
        formatter.zeroFormattingBehavior = value >= 3600 ? .dropAll : .default
        return formatter.string(from: value) ?? ""
    }
}
