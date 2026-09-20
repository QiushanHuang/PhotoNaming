// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhotoNaming",
    platforms: [.macOS(.v14)],
    products: [.library(name: "NamingCore", targets: ["NamingCore"]), .executable(name: "PhotoNaming", targets: ["PhotoNaming"])],
    targets: [
        .target(name: "NamingCore"),
        .executableTarget(name: "PhotoNaming", dependencies: ["NamingCore"]),
        .testTarget(name: "NamingCoreTests", dependencies: ["NamingCore"])
    ],
    swiftLanguageModes: [.v5]
)
