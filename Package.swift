// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ontology",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11)],
    products: [
        .library(
            name: "Ontology",
            targets: ["Ontology"]),
        .library(
            name: "Presentation",
            targets: ["Presentation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/davdroman/Period.git", from: "1.1.0"),
//        .package(url: "https://github.com/apple/swift-log", from: "1.10.1"),
//        .package(url: "https://github.com/mattt/swift-yyjson.git", from: "0.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Ontology"),
        .target(
            name: "Presentation",
            dependencies: [
                "Ontology",
                .product(name: "Period", package: "period"),
            ]
        ),
        .testTarget(
            name: "OntologyTests",
            dependencies: ["Ontology"]
        ),
    ]
)
