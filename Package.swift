// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PocketBonhamEngine", platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "BonhamCore", targets: ["BonhamCore"]),
    .library(name: "BonhamRender", targets: ["BonhamRender"]),
    .executable(name: "bonham-validate-kit", targets: ["KitValidator"]),
  ],
  targets: [
    .target(
      name: "BonhamRender", publicHeadersPath: "include",
      cxxSettings: [.unsafeFlags(["-std=c++17"])]), .target(name: "BonhamCore"),
    .executableTarget(name: "KitValidator", dependencies: ["BonhamCore"]),
    .testTarget(
      name: "BonhamCoreTests", dependencies: ["BonhamCore", "BonhamRender"],
      resources: [.copy("Fixtures")]),
  ], cxxLanguageStandard: .cxx17)
