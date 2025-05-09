// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "things_search",
  dependencies: [
    .package(
      url: "https://github.com/fnc12/sqlite-orm-swift",
      from: "0.0.1"
    ),
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
        .product(name: "SQLiteORM", package: "sqlite-orm-swift"),
        .product(name: "Fuse", package: "fuse-swift"),
      ])
  ],
)
