// swift-tools-version: 6.2

import PackageDescription

func coreDependencies(_ names: [String]) -> [Target.Dependency] {
  names.map { .product(name: $0, package: "Core") } + [
    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
  ]
}

func featureTargets(name: String, core: [String]) -> [Target] {
  let deps = coreDependencies(core)
  return [
    .target(name: name, dependencies: deps),
    .testTarget(name: "\(name)Tests", dependencies: [.byName(name: name)] + deps),
  ]
}

let featureSpecs: [(name: String, core: [String])] = [
  ("OnboardingFeature", ["Domain", "DesignSystem", "Database", "AuthClient", "APIClient"]),
  ("ApartmentsListFeature", ["Domain", "DesignSystem", "Database", "APIClient", "SyncEngine"]),
  (
    "ApartmentTimelineFeature",
    [
      "Domain", "DesignSystem", "Database", "APIClient", "AppConfigClient", "MediaStorage",
      "SyncEngine",
    ]
  ),
  ("SharingFeature", ["Domain", "DesignSystem", "Database", "APIClient", "SyncEngine"]),
  ("CaptureFeature", ["Domain", "DesignSystem", "AppConfigClient", "MediaStorage"]),
  ("MediaSummaryFeature", ["Domain", "DesignSystem", "Database", "MediaStorage", "SyncEngine"]),
  ("MediaDetailFeature", ["Domain", "DesignSystem", "Database", "MediaStorage", "SyncEngine"]),
  (
    "ProfileFeature",
    ["Domain", "DesignSystem", "Database", "AuthClient", "APIClient", "MediaStorage"]
  ),
]

let package = Package(
  name: "Features",
  defaultLocalization: "pl",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: featureSpecs.map { .library(name: $0.name, targets: [$0.name]) },
  dependencies: [
    .package(path: "../Core"),
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      exact: "1.26.2"
    ),
  ],
  targets: featureSpecs.flatMap { featureTargets(name: $0.name, core: $0.core) }
)
