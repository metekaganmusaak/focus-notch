// PetForge — builds the pet GIFs and the app icon bundled with Focus Notch.
//
// Run from the repository root:
//   swift run -c release --package-path Tools/PetForge petforge pixel [--preview out.png]
//       Draws the 32×32 pixel-art pets (pixel style).
//   swift run -c release --package-path Tools/PetForge petforge cute Tools/Art [--preview out.png]
//       Animates the Codex character sheets in Tools/Art (cute style).
//   swift run -c release --package-path Tools/PetForge petforge icon Tools/Art/icon.png [--preview out.png]
//       Cuts the app icon out of the Codex artwork.
//   swift run -c release --package-path Tools/PetForge petforge sounds
//       Synthesizes the notification chimes.
//
// Every GIF is decoded again with ImageIO and checked against its source frames.

import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let petsDirectory = root.appendingPathComponent("FocusNotch/Resources/Pets")
let iconDirectory = root.appendingPathComponent("FocusNotch/Resources/Assets.xcassets/AppIcon.appiconset")
let soundsDirectory = root.appendingPathComponent("FocusNotch/Resources/Sounds")

func option(_ name: String) -> URL? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return URL(fileURLWithPath: arguments[index + 1])
}

func input() -> URL {
    guard arguments.count >= 2, !arguments[1].hasPrefix("--") else {
        print("Missing input path. See the usage at the top of main.swift.")
        exit(1)
    }
    return URL(fileURLWithPath: arguments[1])
}

try FileManager.default.createDirectory(at: petsDirectory, withIntermediateDirectories: true)

switch arguments.first {
case "pixel":
    let rows = try generatePixelPets(into: petsDirectory)
    print("Wrote \(rows.count) pixel GIFs to \(petsDirectory.path)")
    if let preview = option("--preview") {
        try contactSheet(rows, cell: 160).writePNG(to: preview)
    }
case "cute":
    let rows = try generateCutePets(from: input(), into: petsDirectory)
    print("Wrote \(rows.count) cute GIFs to \(petsDirectory.path)")
    if let preview = option("--preview") {
        try contactSheet(rows, cell: cuteCanvas).writePNG(to: preview)
    }
case "icon":
    let icon = try generateAppIcon(from: input(), into: iconDirectory)
    print("Wrote app icon to \(iconDirectory.path)")
    if let preview = option("--preview") {
        try contactSheet([[icon]], cell: 1024).writePNG(to: preview)
    }
case "sounds":
    let names = try generateChimes(into: soundsDirectory)
    print("Wrote \(names.joined(separator: ", ")) to \(soundsDirectory.path)")
default:
    print("Usage: petforge pixel|cute|icon|sounds … (see the top of main.swift)")
    exit(1)
}
