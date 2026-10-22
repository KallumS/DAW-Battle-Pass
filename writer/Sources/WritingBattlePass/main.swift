import AppKit

// `--snapshots <folder>` draws every page and celebration to PNGs and quits:
// how CI shows what the window looks like without anyone at a Mac.
if let i = CommandLine.arguments.firstIndex(of: "--snapshots") {
  let dir = CommandLine.arguments.count > i + 1 ? CommandLine.arguments[i + 1] : "snapshots"
  let app = NSApplication.shared
  app.setActivationPolicy(.accessory)
  DispatchQueue.main.async {
    Task { @MainActor in
      Snapshots.run(into: URL(fileURLWithPath: dir))
      exit(0)
    }
  }
  app.run()
} else {
  WritingBattlePassApp.main()
}
