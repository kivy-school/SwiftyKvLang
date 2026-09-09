// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyKvLang",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // KV language parser library
        .library(
            name: "KvParser",
            targets: ["KvParser"]
        ),
        // Kivy widget registry library
        .library(
            name: "KivyWidgetRegistry",
            targets: ["KivyWidgetRegistry"]
        ),
        // Performance benchmark executable
        .executable(
            name: "benchmark",
            targets: ["Benchmark"]
        ),
        // Test parser executable
        .executable(
            name: "test-parser",
            targets: ["TestParser"]
        ),
    ],
    dependencies: [
        // PySwiftAST for parsing Python code in event handlers
        .package(url: "https://github.com/Py-Swift/PySwiftAST.git", exact: "0.0.1")
    ],
    targets: [
        // Kivy widget registry target
        .target(
            name: "KivyWidgetRegistry",
            dependencies: [],
            path: "Sources/KivyWidgetRegistry"
        ),
        
        // KV language parser target
        .target(
            name: "KvParser",
            dependencies: [
                .product(name: "PySwiftAST", package: "PySwiftAST")
            ],
            path: "Sources/KvParser"
        ),
        
        // Performance benchmark executable
        .executableTarget(
            name: "Benchmark",
            dependencies: ["KvParser"],
            path: "Sources/Benchmark"
        ),
        
        // Test parser executable
        .executableTarget(
            name: "TestParser",
            dependencies: ["KvParser"],
            path: "Sources/TestParser"
        ),
        
        // Tests for KV parser
        .testTarget(
            name: "KvParserTests",
            dependencies: ["KvParser"],
            path: "Tests/KvParserTests",
            resources: [
                .copy("Resources/style.kv")
            ]
        ),
    ]
)
