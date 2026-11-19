// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Features",
  defaultLocalization: "pl",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(name: "OnboardingFeature", targets: ["OnboardingFeature"])
  ],
  dependencies: [
    .package(path: "../Core"),
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      exact: "1.26.2"
    ),
  ],
  targets: [
    .target(
      name: "OnboardingFeature",
      dependencies: [
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "AuthClient", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "OnboardingFeatureTests",
      dependencies: [
        "OnboardingFeature",
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "AuthClient", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
  ]
)
