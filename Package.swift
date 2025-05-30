// swift-tools-version: 5.9
// Package.swift - SSHClient Swift 标准包配置 (优化版，用于集成到其他项目)

import PackageDescription

let package = Package(
    name: "SSHClient",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SSHClient",
            targets: ["SSHClient"]
        )
    ],
    dependencies: [
        // 核心SSH功能依赖
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SSHClient",
            dependencies: [
                .product(name: "Citadel", package: "Citadel"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/SSHClient"
        ),
        .testTarget(
            name: "SSHClientTests",
            dependencies: ["SSHClient"],
            path: "Tests/SSHClientTests"
        )
    ]
) 