// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Core",
  defaultLocalization: "pl",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(name: "Domain", targets: ["Domain"]),
    .library(name: "DesignSystem", targets: ["DesignSystem"]),
    .library(name: "Database", targets: ["Database"]),
    .library(name: "MediaStorage", targets: ["MediaStorage"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      exact: "1.26.2"
    ),
    .package(
      url: "https://github.com/pointfreeco/sqlite-data",
      exact: "1.13.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies",
      exact: "1.17.2"
    ),
  ],
  targets: [
    .target(
      name: "Domain"
    ),
    .target(
      name: "DesignSystem",
      dependencies: ["Domain"],
      resources: [.process("Resources")]
    ),
    .target(
      name: "Database",
      dependencies: [
        "Domain",
        .product(name: "SQLiteData", package: "sqlite-data"),
      ]
    ),
    .target(
      name: "MediaStorage",
      dependencies: [
        "Domain",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "DomainTests",
      dependencies: ["Domain"]
    ),
    .testTarget(
      name: "DesignSystemTests",
      dependencies: ["DesignSystem", "Domain"]
    ),
    .testTarget(
      name: "DatabaseTests",
      dependencies: [
        "Database",
        "Domain",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SQLiteData", package: "sqlite-data"),
      ]
    ),
    .testTarget(
      name: "MediaStorageTests",
      dependencies: [
        "MediaStorage",
        "Domain",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
  ]
)
