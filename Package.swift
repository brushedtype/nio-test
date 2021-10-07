// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "nio-test",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(name: "nio-test", targets: ["nio-test"]),
    ],
    dependencies: [
        .package(name: "swift-nio", url: "git@github.com:apple/swift-nio.git", from: "2.32.3"),
        .package(name: "swift-nio-transport-services", url: "git@github.com:apple/swift-nio-transport-services.git", from: "1.1.1"),
    ],
    targets: [
        .target(name: "nio-test", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
        ]),
        .testTarget(name: "nio-testTests", dependencies: ["nio-test"], resources: [.copy("response-payload.json")]),
    ]
)
