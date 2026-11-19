// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Core",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [.library(name: "Domain", targets: ["Domain"])],
  targets: [
    .target(
      name: "Domain"
    ),
    .testTarget(
      name: "DomainTests",
      dependencies: ["Domain"]
    ),
  ]
)
