// swift-tools-version: 6.2
import PackageDescription

// Host-only harness. It runs the real JohnCore NativeStateStore import on macOS against copied fixture files.
// It is not part of the app, the generator, or any Xcode project. It never uses a simulator.
let package = Package(
    name: "L27HostImporter",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../../../../native/John/Packages/JohnCore")],
    targets: [
        .executableTarget(name: "L27HostImporter", dependencies: [.product(name: "JohnCore", package: "JohnCore")]),
    ],
    swiftLanguageModes: [.v6]
)
