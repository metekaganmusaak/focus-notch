import Foundation
import ImageIO
import Observation

enum PetMood: String {
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
        /// A GIF the user added; used for every mood.
        case custom(URL)
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
        case .custom(let url):
            url
        }
    }
}

enum PetImportError: Error {
    case unreadableImage
}

@Observable
final class PetStore {
    private struct CustomRecord: Codable {
        let id: String
        var name: String
        let fileName: String
    }

    static let defaultPetID = "cat"

    /// The bundled pets. IDs are shared between styles so a choice survives a style
    /// switch; the pixel style only has the first six animals.
    static func builtIn(style: PetStyle) -> [Pet] {
        let pixel = [
            ("cat", String(localized: "Cat")),
            ("dog", String(localized: "Dog")),
            ("bunny", String(localized: "Bunny")),
            ("fox", String(localized: "Fox")),
            ("panda", String(localized: "Panda")),
            ("frog", String(localized: "Frog")),
        ]
        let cuteOnly = [
            ("hamster", String(localized: "Hamster")),
            ("penguin", String(localized: "Penguin")),
            ("owl", String(localized: "Owl")),
            ("koala", String(localized: "Koala")),
            ("duck", String(localized: "Duck")),
            ("hedgehog", String(localized: "Hedgehog")),
        ]
        return (style == .pixel ? pixel : pixel + cuteOnly).map { id, name in
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

    /// Copies a GIF into Application Support and registers it as a pet.
    func importGIF(from source: URL) throws -> Pet {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        guard let image = CGImageSourceCreateWithURL(source as CFURL, nil),
              CGImageSourceGetCount(image) > 0 else {
            throw PetImportError.unreadableImage
        }

        let id = "custom-\(UUID().uuidString)"
        let fileName = "\(id).gif"
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: Self.directory.appendingPathComponent(fileName))

        records.append(CustomRecord(id: id, name: source.deletingPathExtension().lastPathComponent, fileName: fileName))
        save()
        rebuild()
        return customPets.last!
    }

    func remove(_ pet: Pet) {
        guard let index = records.firstIndex(where: { $0.id == pet.id }) else { return }
        let record = records.remove(at: index)
        try? FileManager.default.removeItem(at: Self.directory.appendingPathComponent(record.fileName))
        save()
        rebuild()
    }

    private func rebuild() {
        customPets = records.map {
            Pet(id: $0.id, name: $0.name, source: .custom(Self.directory.appendingPathComponent($0.fileName)))
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
