import SwiftUI
import AppKit
import PassCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    Model.shared.start()
  }
  /// Closing the window doesn't stop the clock: the app lives on in the
  /// menu bar and keeps counting. Quit stops it.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationWillTerminate(_ notification: Notification) {
    Model.shared.save()
  }
}

struct WritingBattlePassApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @ObservedObject var model = Model.shared

  var body: some Scene {
    Window("Writing Battle Pass", id: "main") {
      ContentView(model: model)
        .frame(minWidth: 880, minHeight: 640)
    }
    .defaultSize(width: 1020, height: 760)
    .windowResizability(.contentMinSize)

    MenuBarExtra {
      MenuContent(model: model)
    } label: {
      MenuLabel(model: model)
    }
  }
}

struct MenuLabel: View {
  @ObservedObject var model: Model
  var body: some View {
    let idle = model.engine.ss.idle
    HStack(spacing: 3) {
      Image(systemName: idle ? "pencil.slash" : "pencil.line")
      Text(idle ? "Paused" : Fmt.clock(model.secsToTier))
        .monospacedDigit()
    }
  }
}

struct MenuContent: View {
  @ObservedObject var model: Model
  @Environment(\.openWindow) private var openWindow
  var body: some View {
    let st = model.st
    Text("Level \(st.level)  ·  Tier \(st.pass.tier)  ·  \(Fmt.num(st.coins)) coins")
    Text(model.statusLine)
    Text("Today: \(Fmt.dur(st.days[Dates.dayKey(Model.epoch())] ?? 0)), \(Fmt.num(st.dayWords[Dates.dayKey(Model.epoch())] ?? 0)) words")
    if !model.stage.isEmpty {
      Text("\(model.stage.count) reward\(model.stage.count == 1 ? "" : "s") waiting")
    }
    Divider()
    Button("Open Writing Battle Pass") {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }
    .keyboardShortcut("o")
    Divider()
    Button("Quit") {
      model.save()
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
