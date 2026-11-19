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
    .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
    .library(name: "ApartmentsListFeature", targets: ["ApartmentsListFeature"]),
    .library(name: "ApartmentTimelineFeature", targets: ["ApartmentTimelineFeature"]),
    .library(name: "SharingFeature", targets: ["SharingFeature"]),
    .library(name: "CaptureFeature", targets: ["CaptureFeature"]),
    .library(name: "MediaSummaryFeature", targets: ["MediaSummaryFeature"]),
    .library(name: "MediaDetailFeature", targets: ["MediaDetailFeature"]),
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
    .target(
      name: "ApartmentsListFeature",
      dependencies: [
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "ApartmentTimelineFeature",
      dependencies: [
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "AppConfigClient", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "SharingFeature",
      dependencies: [
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "CaptureFeature",
      dependencies: [
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "AppConfigClient", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "MediaSummaryFeature",
      dependencies: [
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "MediaDetailFeature",
      dependencies: [
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
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
    .testTarget(
      name: "ApartmentsListFeatureTests",
      dependencies: [
        "ApartmentsListFeature",
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "ApartmentTimelineFeatureTests",
      dependencies: [
        "ApartmentTimelineFeature",
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "AppConfigClient", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "SharingFeatureTests",
      dependencies: [
        "SharingFeature",
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "APIClient", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "CaptureFeatureTests",
      dependencies: [
        "CaptureFeature",
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "AppConfigClient", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "MediaSummaryFeatureTests",
      dependencies: [
        "MediaSummaryFeature",
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "MediaDetailFeatureTests",
      dependencies: [
        "MediaDetailFeature",
        .product(name: "Domain", package: "Core"),
        .product(name: "DesignSystem", package: "Core"),
        .product(name: "Database", package: "Core"),
        .product(name: "MediaStorage", package: "Core"),
        .product(name: "SyncEngine", package: "Core"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
  ]
)
