// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KoiPond",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "KoiPond", targets: ["KoiPond"]),
    ],
    targets: [
        .target(
            name: "KoiPond",
            resources: [.process("Shaders")]
        ),
        .testTarget(name: "KoiPondTests", dependencies: ["KoiPond"]),
    ]
)
