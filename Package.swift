// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DogPace",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "DogPaceCore", targets: ["DogPaceCore"]),
    ],
    dependencies: [
        .package(path: "../src/Asherlc__whoop-ble-swift"),
    ],
    targets: [
        // Compiles the iOS app sources on this Mac so the session and screen typecheck
        // without an iOS simulator. The Xcode app target is what runs on the phone.
        .target(
            name: "SessionCompile",
            dependencies: [
                "DogPaceCore",
                .product(name: "WhoopBLE", package: "Asherlc__whoop-ble-swift"),
            ],
            path: "App",
            exclude: ["DogPaceApp.swift"]
        ),
        .target(name: "DogPaceCore"),
        .executableTarget(
            name: "pace-check",
            dependencies: ["DogPaceCore"]
        ),
        .testTarget(
            name: "DogPaceCoreTests",
            dependencies: ["DogPaceCore"]
        ),
    ]
)
