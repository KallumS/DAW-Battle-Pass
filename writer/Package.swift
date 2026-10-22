// swift-tools-version:5.9
// Writing Battle Pass: a season pass for writing, as a Mac app.
// PassCore is the game (pure Swift, Foundation only, tested); WritingBattlePass
// is the window, the menu bar and the watcher that counts typing.
import PackageDescription

let package = Package(
  name: "WritingBattlePass",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "WritingBattlePass", targets: ["WritingBattlePass"]),
  ],
  targets: [
    .target(name: "PassCore"),
    .executableTarget(name: "WritingBattlePass", dependencies: ["PassCore"]),
    .testTarget(name: "PassCoreTests", dependencies: ["PassCore"]),
  ]
)
