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
    .library(name: "AuthClient", targets: ["AuthClient"]),
    .library(name: "APIClient", targets: ["APIClient"]),
    .library(name: "AppConfigClient", targets: ["AppConfigClient"]),
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
    .package(
      url: "https://github.com/apple/swift-openapi-generator",
      exact: "1.14.4"
    ),
    .package(
      url: "https://github.com/apple/swift-openapi-runtime",
      exact: "1.13.4"
    ),
    .package(
      url: "https://github.com/apple/swift-openapi-urlsession",
      exact: "1.4.0"
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
    .target(
      name: "AuthClient",
      dependencies: [
        "Domain",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "APIClient",
      dependencies: [
        "Domain",
        "AuthClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
      ],
      plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
      ]
    ),
    .target(
      name: "AppConfigClient",
      dependencies: [
        "Domain",
        "APIClient",
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
    .testTarget(
      name: "AuthClientTests",
      dependencies: [
        "AuthClient",
        "Domain",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "APIClientTests",
      dependencies: [
        "APIClient",
        "AuthClient",
        "Domain",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
      ]
    ),
    .testTarget(
      name: "AppConfigClientTests",
      dependencies: [
        "AppConfigClient",
        "APIClient",
        "Domain",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
  ]
)
