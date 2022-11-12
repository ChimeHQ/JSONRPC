// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "JSONRPC",
    platforms: [.macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "JSONRPC", targets: ["JSONRPC"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "JSONRPC", dependencies: []),
        .testTarget(name: "JSONRPCTests", dependencies: ["JSONRPC"]),
    ]
)
