import SwiftUI
import UniformTypeIdentifiers

extension PetMood {
    var title: String {
        switch self {
        case .idle: String(localized: "Waiting")
        case .focus: String(localized: "Working")
        case .rest: String(localized: "Sleeping")
        case .celebrate: String(localized: "Celebrating")
        }
    }
}

/// Images dropped on the pets pane, opened in the sheet in mood order.
struct PetDraft: Identifiable {
    let id = UUID()
    var images: [URL] = []
}

/// Up to four images, one per mood, each converted to an animated GIF as soon as it's picked.
struct AddPetSheet: View {
    let model: AppModel
    let draft: PetDraft
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sources: [PetMood: URL] = [:]
    @State private var previews: [PetMood: URL] = [:]
    @State private var error: String?
    @State private var targetedMood: PetMood?
    @State private var removeBackground = true

    private static let previewDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FocusNotchPetPreviews", isDirectory: true)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Pet")
                .font(.title3.weight(.semibold))

            TextField("Name", text: $name, prompt: Text(defaultName))
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                ForEach(PetMood.allCases, id: \.self) { mood in
                    slot(mood)
                }
            }

            Toggle("Remove solid background", isOn: $removeBackground)
                .onChange(of: removeBackground) {
                    for (mood, url) in sources { setImage(url, for: mood) }
                }

            Text("Pick an image for each mood. Still images are turned into animated GIFs; empty moods use the first image.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(sources.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            for (mood, url) in zip(PetMood.allCases, draft.images) { setImage(url, for: mood) }
        }
    }

    private func slot(_ mood: PetMood) -> some View {
        VStack(spacing: 6) {
            Button { choose(for: mood) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.08).gradient)
                    if let preview = previews[mood] {
                        AnimatedGIFView(url: preview, pixelated: false)
                            .padding(6)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 98, height: 98)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(targetedMood == mood ? Color.accentColor : .clear, lineWidth: 2.5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if previews[mood] != nil {
                    Button {
                        sources[mood] = nil
                        previews[mood] = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(5)
                    .help("Remove")
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                setImage(url, for: mood)
                return true
            } isTargeted: { targeted in
                targetedMood = targeted ? mood : (targetedMood == mood ? nil : targetedMood)
            }

            Text(mood.title)
                .font(.callout)
                .lineLimit(1)
        }
    }

    /// The first picked image's file name.
    private var defaultName: String {
        PetMood.allCases.lazy.compactMap { sources[$0] }.first?.deletingPathExtension().lastPathComponent
            ?? String(localized: "My Pet")
    }

    private func choose(for mood: PetMood) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = String(localized: "Choose an image for this mood")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setImage(url, for: mood)
    }

    private func setImage(_ url: URL, for mood: PetMood) {
        do {
            let data = try PetGIFMaker.gifData(from: url, mood: mood, removeBackground: removeBackground)
            try FileManager.default.createDirectory(at: Self.previewDirectory, withIntermediateDirectories: true)
            // A fresh name each time, since decoded GIFs are cached by URL.
            let preview = Self.previewDirectory.appendingPathComponent("\(UUID().uuidString).gif")
            try data.write(to: preview)
            sources[mood] = url
            previews[mood] = preview
            error = nil
        } catch {
            self.error = String(localized: "This image couldn't be read. Please choose a PNG, JPEG or GIF file.")
        }
    }

    private func add() {
        guard let first = PetMood.allCases.lazy.compactMap({ sources[$0] }).first else { return }
        do {
            var gifs: [PetMood: Data] = [:]
            for mood in PetMood.allCases {
                gifs[mood] = try previews[mood].map { try Data(contentsOf: $0) }
                    ?? PetGIFMaker.gifData(from: first, mood: mood, removeBackground: removeBackground)
            }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let pet = try model.pets.addPet(name: String((trimmed.isEmpty ? defaultName : trimmed).prefix(40)), gifs: gifs)
            model.settings.selectedPetID = pet.id
            try? FileManager.default.removeItem(at: Self.previewDirectory)
            dismiss()
        } catch {
            self.error = String(localized: "This image couldn't be read. Please choose a PNG, JPEG or GIF file.")
        }
    }
}
