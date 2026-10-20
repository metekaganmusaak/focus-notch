// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PetForge",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "petforge"),
    ]
)
