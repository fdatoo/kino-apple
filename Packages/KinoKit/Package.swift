// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "KinoKit",
  platforms: [
    .iOS(.v17),
    .tvOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "KinoKit", targets: ["KinoKit"])
  ],
  targets: [
    .target(name: "KinoKitCore"),
    .target(
      name: "KinoKitTransport",
      dependencies: ["KinoKitCore"]
    ),
    .target(
      name: "KinoKitAuth",
      dependencies: ["KinoKitCore", "KinoKitTransport"]
    ),
    .target(
      name: "KinoKitPlayback",
      dependencies: ["KinoKitCore", "KinoKitTransport"]
    ),
    .target(
      name: "KinoKit",
      dependencies: [
        "KinoKitCore",
        "KinoKitTransport",
        "KinoKitAuth",
        "KinoKitPlayback",
      ]
    ),
    .testTarget(
      name: "KinoKitTests",
      dependencies: ["KinoKit"]
    ),
  ]
)
