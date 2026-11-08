// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GearsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "GearsCore", targets: ["GearsCore"])],
    targets: [
        .target(name: "GearsCore"),
        .testTarget(name: "GearsCoreTests", dependencies: ["GearsCore"]),
    ]
)
