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
    .testTarget(
      name: "DomainTests",
      dependencies: ["Domain"]
    ),
    .testTarget(
      name: "DesignSystemTests",
      dependencies: ["DesignSystem", "Domain"]
    ),
  ]
)
