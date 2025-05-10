// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "things_search",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3"),
    .package(
      url: "https://github.com/krisk/fuse-swift.git",
      from: "1.4.0"
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "things_search",
      dependencies: [
        .product(name: "SQLite", package: "SQLite.swift"),
        .product(name: "Fuse", package: "fuse-swift"),
      ])
  ],
)
