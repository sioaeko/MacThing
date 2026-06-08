// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacThing",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacThingCore", targets: ["MacThingCore"]),
        .executable(name: "MacThing", targets: ["MacThing"]),
        .executable(name: "MacThingCLI", targets: ["MacThingCLI"]),
        .executable(name: "MacThingSelfTest", targets: ["MacThingSelfTest"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(
            name: "MacThingCore",
            dependencies: ["CSQLite"]
        ),
        .executableTarget(
            name: "MacThing",
            dependencies: ["MacThingCore"]
        ),
        .executableTarget(
            name: "MacThingCLI",
            dependencies: []
        ),
        .executableTarget(
            name: "MacThingSelfTest",
            dependencies: ["MacThingCore"]
        )
    ]
)
