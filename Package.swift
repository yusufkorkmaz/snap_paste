// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SnapPaste",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SnapPaste", targets: ["SnapPaste"]),
    ],
    targets: [
        .target(name: "SnapPasteCore"),
        .executableTarget(name: "SnapPaste", dependencies: ["SnapPasteCore"]),
        .testTarget(name: "SnapPasteCoreTests", dependencies: ["SnapPasteCore"]),
    ]
)
