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
  dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "KinoKitGenerated",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
      ],
      plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
      ]
    ),
    .target(name: "KinoKitCore"),
    .target(
      name: "KinoKitTransport",
      dependencies: [
        "KinoKitCore",
        "KinoKitGenerated",
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
      ]
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
        "KinoKitGenerated",
        "KinoKitTransport",
        "KinoKitAuth",
        "KinoKitPlayback",
      ]
    ),
    .executableTarget(
      name: "KinoKitProbe",
      dependencies: ["KinoKit"],
      path: "Probe/KinoKitProbe"
    ),
    .testTarget(
      name: "KinoKitTests",
      dependencies: ["KinoKit"]
    ),
  ]
)
