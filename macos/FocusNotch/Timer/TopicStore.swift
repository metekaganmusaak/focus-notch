import Foundation
import Observation

/// Something the user studies or works on, e.g. "Math". Focus time is tracked per topic.
struct Topic: Codable, Identifiable, Hashable {
    let id: String
    var name: String
}

@Observable
final class TopicStore {
    private(set) var topics: [Topic]

    @ObservationIgnored private let storageKey = "topics"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Topic].self, from: data) {
            topics = decoded
        } else {
            topics = []
        }
    }

    func topic(withID id: String?) -> Topic? {
        guard let id else { return nil }
        return topics.first { $0.id == id }
    }

    /// Adds a topic, or returns the existing one with the same name.
    @discardableResult
    func add(named rawName: String) -> Topic? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = topics.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let topic = Topic(id: UUID().uuidString, name: String(name.prefix(40)))
        topics.append(topic)
        save()
        return topic
    }

    func remove(_ topic: Topic) {
        topics.removeAll { $0.id == topic.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(topics) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
