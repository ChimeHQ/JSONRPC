// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JSONRPC",
    platforms: [.macOS(.v10_10), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "JSONRPC", targets: ["JSONRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.0"),
        .package(url: "https://github.com/g-mark/NullCodable", from: "1.1.0"),
    ],
    targets: [
        .target(name: "JSONRPC", dependencies: ["AnyCodable", "NullCodable"]),
        .testTarget(name: "JSONRPCTests", dependencies: ["JSONRPC"]),
    ]
)
