import Foundation
import Observation

/// Per-day focus totals, split by topic, persisted in UserDefaults.
@Observable
final class StatsStore {
    struct Totals: Codable {
        var sessions = 0
        var focusSeconds: TimeInterval = 0

        mutating func add(_ seconds: TimeInterval, completedSession: Bool) {
            focusSeconds += seconds
            if completedSession { sessions += 1 }
        }
    }

    struct Day: Codable {
        var sessions = 0
        var focusSeconds: TimeInterval = 0
        /// Totals per topic ID. Time without a topic isn't listed here.
        var topics: [String: Totals] = [:]

        init() {}

        // Data saved before topics existed has no `topics` key.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sessions = try container.decode(Int.self, forKey: .sessions)
            focusSeconds = try container.decode(TimeInterval.self, forKey: .focusSeconds)
            topics = try container.decodeIfPresent([String: Totals].self, forKey: .topics) ?? [:]
        }
    }

    enum Period: CaseIterable, Identifiable {
        case today, week, allTime

        var id: Self { self }

        var title: String {
            switch self {
            case .today: String(localized: "Today")
            case .week: String(localized: "This Week")
            case .allTime: String(localized: "All Time")
            }
        }
    }

    /// One row of the per-topic breakdown; `topicID` is nil for time without a topic.
    struct TopicTotal: Identifiable {
        let topicID: String?
        let totals: Totals

        var id: String { topicID ?? "" }
    }

    private(set) var days: [String: Day]

    @ObservationIgnored private let storageKey = "stats.days"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: Day].self, from: data) {
            days = decoded
        } else {
            days = [:]
        }
    }

    var today: Day { days[Self.key(for: Date())] ?? Day() }

    func addFocus(_ seconds: TimeInterval, completedSession: Bool, topicID: String?) {
        let key = Self.key(for: Date())
        var day = days[key] ?? Day()
        day.focusSeconds += seconds
        if completedSession { day.sessions += 1 }
        if let topicID {
            day.topics[topicID, default: Totals()].add(seconds, completedSession: completedSession)
        }
        days[key] = day
        save()
    }

    func totals(in period: Period) -> Totals {
        selectedDays(period).reduce(into: Totals()) { result, day in
            result.sessions += day.sessions
            result.focusSeconds += day.focusSeconds
        }
    }

    /// Focus time per topic, largest first. Time logged for topics that no longer
    /// exist is counted as "no topic".
    func topicTotals(in period: Period, knownTopics: Set<String>) -> [TopicTotal] {
        var byTopic: [String: Totals] = [:]
        var untracked = Totals()
        for day in selectedDays(period) {
            var tracked = Totals()
            for (id, totals) in day.topics where knownTopics.contains(id) {
                byTopic[id, default: Totals()].sessions += totals.sessions
                byTopic[id, default: Totals()].focusSeconds += totals.focusSeconds
                tracked.sessions += totals.sessions
                tracked.focusSeconds += totals.focusSeconds
            }
            untracked.sessions += day.sessions - tracked.sessions
            untracked.focusSeconds += day.focusSeconds - tracked.focusSeconds
        }
        var rows = byTopic.map { TopicTotal(topicID: $0.key, totals: $0.value) }
        if untracked.focusSeconds >= 1 {
            rows.append(TopicTotal(topicID: nil, totals: untracked))
        }
        return rows.sorted { $0.totals.focusSeconds > $1.totals.focusSeconds }
    }

    func resetToday() {
        days[Self.key(for: Date())] = nil
        save()
    }

    private func selectedDays(_ period: Period) -> [Day] {
        switch period {
        case .today:
            return [today]
        case .week:
            let calendar = Calendar.current
            return (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: Date()).flatMap { days[Self.key(for: $0)] }
            }
        case .allTime:
            return Array(days.values)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func key(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
