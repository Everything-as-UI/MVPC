// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MVPC",
    platforms: [.macOS(.v12), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "MVPC", targets: ["MVPC"]),
        .library(name: "SwiftLangUI", targets: ["SwiftLangUI"])
    ],
    dependencies: [
        .package(path: "../DocumentUI")
    ],
    targets: [
        .target(name: "MVPC", dependencies: ["SwiftLangUI"]),
        .target(name: "SwiftLangUI", dependencies: ["DocumentUI"]),
        .testTarget(name: "MVPCTests", dependencies: ["MVPC"])
    ]
)
