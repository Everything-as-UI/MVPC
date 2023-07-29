// swift-tools-version: 5.7

import PackageDescription

let dependencies: [Package.Dependency]
if Context.environment["ALLUI_ENV"] == "LOCAL" {
    dependencies = [.package(name: "SwiftLangUI", path: "../SwiftLangUI")]
} else {
    dependencies = [.package(url: "https://github.com/Everything-as-UI/SwiftLangUI.git", branch: "main")]
}

let package = Package(
    name: "MVPC",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "MVPCKit", targets: ["MVPCKit"])
    ],
    dependencies: dependencies,
    targets: [
        .target(name: "MVPCKit", dependencies: ["SwiftLangUI"]),
        .testTarget(name: "MVPCTests", dependencies: ["MVPCKit"])
    ]
)
