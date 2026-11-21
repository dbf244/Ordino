// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OrdinoCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "OrdinoCore", targets: ["OrdinoCore"]),
    ],
    targets: [
        .target(
            name: "OrdinoCore",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "OrdinoCoreTests",
            dependencies: ["OrdinoCore"],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
