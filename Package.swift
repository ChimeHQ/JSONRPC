// swift-tools-version:5.5

import PackageDescription

let settings: [SwiftSetting] = [
	.unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"])
]

let package = Package(
    name: "JSONRPC",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "JSONRPC", targets: ["JSONRPC"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "JSONRPC", dependencies: [], swiftSettings: settings),
        .testTarget(name: "JSONRPCTests", dependencies: ["JSONRPC"], swiftSettings: settings),
    ]
)
