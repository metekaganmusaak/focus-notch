import Foundation
import Observation

enum PetMood: String, CaseIterable {
    case idle, focus, rest, celebrate
}

/// Art style of the bundled pets.
enum PetStyle: String, CaseIterable {
    /// Illustrated pets (generated with Codex, animated by PetForge).
    case cute
    /// 32×32 pixel-art pets drawn by PetForge.
    case pixel

    var title: String {
        switch self {
        case .cute: String(localized: "Cute")
        case .pixel: String(localized: "Pixel")
        }
    }
}

struct Pet: Identifiable, Hashable {
    enum Source: Hashable {
        /// Bundled pet with one GIF per mood: `<name>_<mood>.gif`.
        case builtIn(String)
        /// GIFs the user added, one per mood (older custom pets have one for every mood).
        case custom([PetMood: URL])
    }

    let id: String
    let name: String
    let source: Source
    /// Pixel sprites are tiny and should be scaled without smoothing.
    var isPixelArt = false
    /// Bundled sound played when the pet is clicked, if it has one.
    var soundName: String?

    var isCustom: Bool {
        if case .custom = source { return true }
        return false
    }

    func url(for mood: PetMood) -> URL? {
        switch source {
        case .builtIn(let name):
            Bundle.main.url(forResource: "\(name)_\(mood.rawValue)", withExtension: "gif")
        case .custom(let urls):
            urls[mood] ?? urls[.idle]
        }
    }
}

@Observable
final class PetStore {
    private struct CustomRecord: Codable {
        let id: String
        var name: String
        /// Pets added before per-mood images use this one GIF for every mood.
        var fileName: String?
        /// Mood raw value → file name.
        var moodFiles: [String: String]?

        var fileNames: [String] { (fileName.map { [$0] } ?? []) + (moodFiles.map { Array($0.values) } ?? []) }
    }

    static let defaultPetID = "cat"

    /// The bundled pets. IDs are shared between styles so a choice survives a style switch.
    static func builtIn(style: PetStyle) -> [Pet] {
        let animals = [
            ("cat", String(localized: "Cat")),
            ("dog", String(localized: "Dog")),
            ("bunny", String(localized: "Bunny")),
            ("fox", String(localized: "Fox")),
            ("panda", String(localized: "Panda")),
            ("frog", String(localized: "Frog")),
            ("hamster", String(localized: "Hamster")),
            ("penguin", String(localized: "Penguin")),
            ("owl", String(localized: "Owl")),
            ("koala", String(localized: "Koala")),
            ("duck", String(localized: "Duck")),
            ("hedgehog", String(localized: "Hedgehog")),
        ]
        return animals.map { id, name in
            Pet(
                id: id, name: name,
                source: .builtIn(style == .pixel ? id : "cute_\(id)"),
                isPixelArt: style == .pixel,
                soundName: Bundle.main.url(forResource: "pet_\(id)", withExtension: "wav") != nil ? "pet_\(id)" : nil
            )
        }
    }

    private(set) var customPets: [Pet] = []

    @ObservationIgnored private var records: [CustomRecord] = []
    @ObservationIgnored private let storageKey = "customPets"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CustomRecord].self, from: data) {
            records = decoded
        }
        rebuild()
    }

    func all(style: PetStyle) -> [Pet] {
        Self.builtIn(style: style) + customPets
    }

    func pet(withID id: String, style: PetStyle) -> Pet? {
        all(style: style).first { $0.id == id }
    }

    /// Saves one GIF per mood (see `PetGIFMaker`) into Application Support and registers them as a pet.
    func addPet(name: String, gifs: [PetMood: Data]) throws -> Pet {
        let id = "custom-\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        var files: [String: String] = [:]
        for (mood, data) in gifs {
            let fileName = "\(id)_\(mood.rawValue).gif"
            try data.write(to: Self.directory.appendingPathComponent(fileName))
            files[mood.rawValue] = fileName
        }

        records.append(CustomRecord(id: id, name: name, moodFiles: files))
        save()
        rebuild()
        return customPets.last!
    }

    func remove(_ pet: Pet) {
        guard let index = records.firstIndex(where: { $0.id == pet.id }) else { return }
        let record = records.remove(at: index)
        for fileName in record.fileNames {
            try? FileManager.default.removeItem(at: Self.directory.appendingPathComponent(fileName))
        }
        save()
        rebuild()
    }

    private func rebuild() {
        customPets = records.map { record in
            var urls: [PetMood: URL] = [:]
            for mood in PetMood.allCases {
                if let fileName = record.moodFiles?[mood.rawValue] ?? record.fileName {
                    urls[mood] = Self.directory.appendingPathComponent(fileName)
                }
            }
            return Pet(id: record.id, name: record.name, source: .custom(urls))
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static var directory: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("FocusNotch", isDirectory: true)
            .appendingPathComponent("Pets", isDirectory: true)
    }
}
