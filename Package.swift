// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "JSONRPC",
    platforms: [.macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "JSONRPC", targets: ["JSONRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable", "0.6.0"..<"0.6.3"),
    ],
    targets: [
        .target(name: "JSONRPC", dependencies: ["AnyCodable"]),
        .testTarget(name: "JSONRPCTests", dependencies: ["JSONRPC"]),
    ]
)
