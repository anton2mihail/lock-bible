// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "JohnCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "JohnCore", targets: ["JohnCore"])],
    targets: [
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
        .systemLibrary(name: "CZlib", path: "Sources/CZlib"),
        .target(name: "JohnCore", dependencies: ["CSQLite", "CZlib"], path: "Sources/JohnCore"),
        .testTarget(name: "JohnCoreTests", dependencies: ["JohnCore"], path: "Tests/JohnCoreTests"),
    ],
    swiftLanguageModes: [.v6]
)
