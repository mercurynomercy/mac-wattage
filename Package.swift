// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacWattage",
    platforms: [.macOS("13.0")],
    products: [
        .library(name: "MacWattage", targets: ["MacWattage"]),
    ],
    dependencies: [],  // Zero external deps
    targets: [
        .target(
            name: "MacWattage",
            path: "MacWattage",
            exclude: ["Info.plist"],
            sources: [
                "Shared/Logger.swift",
                "Metrics/IOKitAdapter.swift",
                "Metrics/PowerEstimator.swift",
                "Metrics/PlatformDetector.swift",
                "Data/PowerRecord.swift",
                "Data/PowerLogService.swift",
                "Data/RotationManager.swift",
                "Data/Store.swift",
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
            ]
        ),
        .testTarget(
            name: "MacWattageTests",
            dependencies: ["MacWattage"],
            path: "MacWattageTests",
            exclude: ["Info.plist"],
            sources: [
                "Mocks.swift",
                "PowerEstimatorTests.swift",
                "PlatformDetectorTests.swift",
                "PowerLogServiceTests.swift",
                "RotationManagerTests.swift",
                "StoreTests.swift",
            ],
        ),
    ]
)
