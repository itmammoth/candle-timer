// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "candle-timer",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "candle-timer", targets: ["CandleTimer"])
  ],
  targets: [
    .executableTarget(name: "CandleTimer"),
    .testTarget(name: "CandleTimerTests", dependencies: ["CandleTimer"])
  ]
)
