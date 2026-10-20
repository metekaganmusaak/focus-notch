# Focus Notch for macOS

The native macOS app, built with SwiftUI and AppKit. It draws a black panel that blends into the MacBook notch, grows "wings" for your pet and the countdown while a session runs, and opens into a full panel when you hover over it.

See the [main README](../README.md) for features, screenshots and how to use the app.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later (built with Xcode 26)

## Running

1. Open `FocusNotch.xcodeproj` in Xcode.
2. Press **Run** (⌘R).

The app has no Dock icon. Open its settings from the ⚙ button in the notch panel, from the menu bar icon, or by launching the app again.

The project signs with "Sign to Run Locally". To ship it to other Macs, pick your own team under **Signing & Capabilities** and notarize the build.

To build a release from the command line and install it:

```sh
xcodebuild -project FocusNotch.xcodeproj -scheme FocusNotch -configuration Release -derivedDataPath /tmp/fn-build build
pkill -x FocusNotch
rm -rf /Applications/FocusNotch.app
ditto /tmp/fn-build/Build/Products/Release/FocusNotch.app /Applications/FocusNotch.app
open /Applications/FocusNotch.app
```

## Project layout

| Folder | Contents |
| --- | --- |
| `FocusNotch/App` | App entry point, `AppModel` (connects timer events to the notch, sounds and notifications), menu bar menu |
| `FocusNotch/Timer` | `PomodoroEngine` (phases, reminders, finishing), `StatsStore` (per day and per topic), `TopicStore` |
| `FocusNotch/Notch` | The notch panel, its shape, hover tracking and SwiftUI views |
| `FocusNotch/Pets` | `PetStore` (bundled cute and pixel pets plus custom pets), `PetGIFMaker` (turns user images into per-mood GIFs) and the GIF player |
| `FocusNotch/Settings` | `SettingsStore` and the settings window |
| `FocusNotch/Support` | Themes, time formatting, notifications, language override |
| `FocusNotch/Resources` | Pet GIFs, sounds, app icon, `Localizable.xcstrings` |
| `Tools/PetForge` | Swift package that generates the pet GIFs, the app icon and the chimes |
| `Tools/Art` | Codex-generated source art (pet character sheets and the icon) |

## Regenerating pets, icon and sounds

Run these from the `macos/` folder:

```sh
# Pixel style: pets drawn in code (Tools/PetForge/Sources/petforge/PixelPets.swift)
swift run -c release --package-path Tools/PetForge petforge pixel --preview /tmp/pixel.png

# Cute style: animated GIFs from the Codex character sheets in Tools/Art
swift run -c release --package-path Tools/PetForge petforge cute Tools/Art --preview /tmp/cute.png

# App icon, cut out of the Codex artwork
swift run -c release --package-path Tools/PetForge petforge icon Tools/Art/icon.png

# Notification chimes (synthesized)
swift run -c release --package-path Tools/PetForge petforge sounds
```

Each character sheet is a 2×2 grid on a flat magenta (#FF00FF) background: idle top left, focus (at a laptop) top right, sleeping bottom left, celebrating bottom right. PetForge removes the background, separates the poses, adds breathing, hopping, "z" and sparkle animations, and writes the GIFs to `FocusNotch/Resources/Pets/`. Every GIF is decoded again with ImageIO and checked pixel by pixel.

To add a pet:

1. Generate a sheet with the same layout; giving Codex `Tools/Art/cat.png` as a style reference keeps the look consistent.
2. Add a pixel version in `PixelPets.swift`.
3. Add the name to `cutePetNames` in `CutePets.swift` and to `PetStore.builtIn` in the app (and `ANIMALS` in `windows/src/main/pets.js`).

The pet click sounds (`Resources/Sounds/pet_*.wav`) are CC0 recordings; their sources are listed in [ASSETS.md](../ASSETS.md).

## Translations

All text lives in `FocusNotch/Resources/Localizable.xcstrings`, with a comment for translators on every key. The Windows app takes its translations from this file too (`npm run sync` in `windows/`). When you add text, Xcode adds the key to the catalog on build; fill in the translations in Xcode's String Catalog editor.
