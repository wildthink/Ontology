// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ontology",
    platforms: [
        .macOS(.v15),
        .iOS(.v16),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "Ontology",
            targets: ["Ontology"]),
        .library(
            name: "Presentation",
            targets: ["Presentation"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Ontology"),
        .target(
            name: "Presentation",
            dependencies: [
                "Ontology"
            ]
        ),
        .testTarget(
            name: "OntologyTests",
            dependencies: ["Ontology"]
        ),
    ]
)
