// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ontology",
    platforms: [.macOS(.v26), .iOS(.v18), .tvOS(.v18), .watchOS(.v11)],
    products: [
        .library(
            name: "Ontology",
            targets: ["Ontology"]),
        .library(
            name: "OntologyApple",
            targets: ["OntologyApple"]),
        .library(
            name: "OntologyOKF",
            targets: ["OntologyOKF"]),
        .library(
            name: "OntologyGoogle",
            targets: ["OntologyGoogle"]),
        .library(
            name: "Presentation",
            targets: ["Presentation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/davdroman/Period.git", from: "1.1.0"),
        .package(url: "https://github.com/wildthink/Units", branch: "main"),
        .package(url: "https://github.com/mattt/swift-yyjson.git", from: "0.5.0"),
        .package(url: "https://github.com/marcprux/universal.git", from: "6.0.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Ontology",
            dependencies: [
                .product(name: "Period", package: "period"),
                .product(name: "Units", package: "Units"),
                .product(name: "YYJSON", package: "swift-yyjson"),
                .product(name: "Universal", package: "universal"),
            ]
        ),
        .target(
            name: "OntologyApple",
            dependencies: ["Ontology"]
        ),
        .target(
            name: "OntologyOKF",
            dependencies: [
                .target(name: "Ontology"),
                .product(name: "Universal", package: "universal"),
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "Presentation",
            dependencies: [
                "OntologyApple",
                .product(name: "Period", package: "period"),
            ]
        ),
        .target(
            name: "OntologyGoogle",
            dependencies: ["Ontology"]
        ),
        .testTarget(
            name: "OntologyTests",
            dependencies: ["Ontology", "OntologyApple", "OntologyOKF", "OntologyGoogle"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
