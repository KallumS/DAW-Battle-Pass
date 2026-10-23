import SwiftUI
import AppKit
import ServiceManagement
import PassCore

enum Tab: String, CaseIterable, Identifiable {
  case pass, quests, loot, shop, wardrobe, ideas, trophies, settings
  var id: String { rawValue }
  var label: String {
    switch self {
    case .pass: return "Pass"
    case .quests: return "Quests"
    case .loot: return "Loot"
    case .shop: return "Shop"
    case .wardrobe: return "Wardrobe"
    case .ideas: return "Prompts"
    case .trophies: return "Trophies"
    case .settings: return "Settings"
    }
  }
}

struct Toast: Identifiable {
  let id = UUID()
  var text: String
  var sub: String
  var icon: String
  var rarity: Int
  var until: Date
  var coins = 0
  var xp = 0
  var trophy = false
}

/// A celebration: drawn in place of the page until she closes it, so
/// nothing underneath can be clicked by accident.
struct StageItem: Identifiable {
  enum Kind { case reward, level, checkin, redeem, season, welcome }
  let id = UUID()
  var kind: Kind
  var title = ""
  var sub = ""
  var drops: [Drop] = []
  var crate = 0            // a gift box's rarity: closed until she opens it
  var opened = false
  var tierKind = ""
  var level = 0
  var checkin: CheckinResult? = nil
  var name = ""
  var icon = ""
}

/// The app's brain: runs the game twice a second, counts her typing, saves,
/// and turns what happened into celebrations. The window and the menu bar
/// both watch it.
@MainActor
final class Model: ObservableObject {
  static let shared = Model()

  let engine: Engine
  @Published var tab: Tab = .pass
  @Published var stage: [StageItem] = []
  @Published var toasts: [Toast] = []
  @Published var ideaFilter = "all"
  @Published var selectedGear: Int? = nil
  let fx = FXStore()

  var front: FrontApp? = nil
  var counting = false
  var tapRunning = false
  var damaged = false
  let snapshot: Bool
  let saveURL: URL
  private var timer: Timer?
  private var lastSave = 0.0, dirty = false, lastRefresh = -100.0, lastTapTry = -100.0, xpAt = 0.0

  static func now() -> Double { ProcessInfo.processInfo.systemUptime }
  static func epoch() -> Int { Int(Date().timeIntervalSince1970) }

  init(snapshot: Bool = false, engine: Engine? = nil) {
    self.snapshot = snapshot
    saveURL = Save.folder().appendingPathComponent("progress.json")
    if let e = engine {
      self.engine = e
    } else {
      let (st, damaged) = Save.read(from: saveURL, epoch: Model.epoch())
      self.engine = Engine(state: st, tp: Model.now(), epoch: Model.epoch())
      self.damaged = damaged
    }
  }

  var st: GameState { engine.st }

  /// Starts the clock. Called once the app has launched.
  func start() {
    guard timer == nil, !snapshot else { return }
    engine.refresh(Model.epoch())
    engine.checkAchievements()
    _ = engine.takeNotices()   // nothing from catching up is worth a fanfare
    if !engine.st.settings.welcome {
      stage.append(StageItem(kind: .welcome))
    } else if engine.checkinAvailable(Model.epoch()) {
      stage.append(StageItem(kind: .checkin))
    }
    if damaged {
      toast("Your save was damaged", "The backup was loaded instead; the damaged file is kept beside it", "exclamationmark.triangle", 4, life: 10)
    }
    tapRunning = KeyTap.start()
    let t = Timer(timeInterval: 0.5, repeats: true) { _ in
      Task { @MainActor in Model.shared.tick() }
    }
    RunLoop.main.add(t, forMode: .common)
    timer = t
  }

  func tick() {
    let tp = Model.now(), epoch = Model.epoch()
    if !KeyTap.running && tp - lastTapTry > 5 {
      lastTapTry = tp
      tapRunning = KeyTap.start()
    }
    let keys = KeyTap.take()
    fx.calm = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    front = Watch.front()
    let s = engine.st.settings
    counting = front.map { $0.id != Watch.me && (s.everywhere || s.apps.contains($0.id)) } ?? false
    if let f = front, f.id != Watch.me, keys.letters > 0 {
      var seen = engine.st.settings.seen[f.id] ?? SeenApp(name: f.name)
      seen.name = f.name
      seen.letters += Double(keys.letters)
      seen.last = epoch
      engine.st.settings.seen[f.id] = seen
    }
    if counting {
      engine.event("letters", Double(keys.letters))
      engine.event("words", Double(keys.words))
    }
    let touched = keys.keys > 0 || Watch.secondsSinceInput() < 1.5
    engine.tick(tp, epoch, Signals(input: counting && touched))
    if tp - lastRefresh >= 2 {
      lastRefresh = tp
      engine.refresh(epoch)
      engine.checkAchievements()
    }
    handleNotices()
    let nowDate = Date()
    if toasts.contains(where: { $0.until < nowDate }) { toasts.removeAll { $0.until < nowDate } }
    if (dirty && tp - lastSave > 1) || tp - lastSave > 20 { save() }
    NSApp.dockTile.badgeLabel = stage.isEmpty ? nil : String(stage.count)
    objectWillChange.send()
  }

  /// Every button goes through here: do it, celebrate it, save soon.
  func act(_ f: (Engine) -> Void) {
    f(engine)
    dirty = true
    handleNotices()
    objectWillChange.send()
  }

  func save() {
    guard !snapshot else { return }
    do {
      try Save.write(engine.st, to: saveURL)
      lastSave = Model.now()
      dirty = false
    } catch {
      NSLog("Writing Battle Pass: could not save: \(error)")
    }
  }

  // Celebrations -----------------------------------------------------------------------

  func sound(_ name: String) {
    guard engine.st.settings.sound, !snapshot else { return }
    NSSound(named: NSSound.Name(name))?.play()
  }

  func toast(_ text: String, _ sub: String, _ icon: String, _ rarity: Int, life: Double = 4.5,
             coins: Int = 0, xp: Int = 0, trophy: Bool = false) {
    toasts.append(Toast(text: text, sub: sub, icon: icon, rarity: rarity, until: Date().addingTimeInterval(life),
                        coins: coins, xp: xp, trophy: trophy))
    if toasts.count > 5 { toasts.removeFirst(toasts.count - 5) }
  }

  /// Where the pointer is in the window, for bursts at a button.
  func pointer() -> CGPoint {
    guard let w = NSApp.keyWindow, let v = w.contentView else { return CGPoint(x: 500, y: 300) }
    let p = w.mouseLocationOutsideOfEventStream
    return CGPoint(x: p.x, y: v.bounds.height - p.y)
  }

  var toastCorner: CGPoint {
    let w = NSApp.keyWindow?.contentView?.bounds.width ?? 1000
    return CGPoint(x: w - 170, y: 150)
  }

  static func tierTitle(_ kind: String, _ tier: Int) -> String {
    switch kind {
    case "finale": return "Tier \(tier): the season finale!"
    case "legendary": return "Tier \(tier): a Legendary tier!"
    case "milestone": return "Tier \(tier): a milestone!"
    case "big": return "Tier \(tier): an hour of writing!"
    default: return "Tier \(tier) unlocked"
    }
  }

  func handleNotices() {
    for n in engine.takeNotices() {
      switch n.kind {
      case .tier:
        stage.append(StageItem(kind: .reward, title: Model.tierTitle(n.tierKind, n.tier),
                               sub: "Fifteen more minutes of writing", drops: n.drops, tierKind: n.tierKind))
        sound(n.tierKind == "small" ? "Glass" : "Hero")
      case .crate:
        stage.append(StageItem(kind: .reward, title: Rarity.name(n.rarity) + " Gift Box", sub: "Click to open it",
                               drops: n.drops, crate: n.rarity))
      case .level:
        stage.append(StageItem(kind: .level, crate: n.crate, level: n.level))
        sound("Glass")
      case .checkin:
        if let i = stage.firstIndex(where: { $0.kind == .checkin && $0.checkin == nil }) {
          stage[i].checkin = n.checkin
        } else {
          stage.append(StageItem(kind: .checkin, checkin: n.checkin))
        }
        fx.confetti(at: CGPoint(x: (NSApp.keyWindow?.contentView?.bounds.width ?? 1000) / 2, y: 260), count: 50)
        sound("Purr")
      case .redeem:
        stage.append(StageItem(kind: .redeem, name: n.name, icon: n.icon))
        sound("Hero")
      case .season:
        stage.append(StageItem(kind: .season, title: n.text))
      case .quest:
        toast("Quest complete!", n.text, "scroll", n.rarity)
        fx.confetti(at: toastCorner, count: 40, speed: 300)
        sound("Purr")
      case .claim:
        let p = pointer()
        fx.coins(from: p, count: min(30, n.coins / 5 + 6))
        fx.burst(at: p, count: 24, colours: [Theme.rarity(4), Theme.accent, Theme.bright], speed: 300)
        if n.crate > 0 { toast("Quest reward", Rarity.name(n.crate) + " Gift Box added to Loot", "gift.fill", n.crate) }
        sound("Tink")
      case .ach:
        toast(n.name, n.text + (n.title.map { "  -  title: " + $0 } ?? ""), "trophy.fill", n.final ? 6 : 5,
              life: 6, coins: n.coins, xp: n.xp, trophy: true)
        fx.confetti(at: CGPoint(x: (NSApp.keyWindow?.contentView?.bounds.width ?? 1000) / 2, y: 140), count: 70)
        sound("Hero")
      case .toast:
        toast(n.text, n.sub, n.icon, max(1, n.rarity))
      case .coins:
        fx.coinBump = 1
        fx.floater("+" + Fmt.num(n.amount), at: CGPoint(x: fx.coinPos.x, y: fx.coinPos.y + 22), colour: Theme.coin)
      case .purchase:
        toast("Bought " + n.name, "-" + Fmt.num(n.price) + " coins", n.icon, max(4, n.rarity))
        let p = pointer()
        fx.burst(at: p, count: 30, colours: [Theme.coin, Theme.accent, Theme.bright], speed: 320)
        fx.ring(at: p, colour: Theme.coin)
        sound("Bottle")
      case .idle:
        toast("Paused", "No writing for a few minutes, so the clock has stopped", "pause.circle", 1)
      case .active:
        toast("Writing", "The clock is running", "pencil", 3, life: 3)
      case .equip:
        toast("Wearing", n.text, "sparkles", n.rarity, life: 3)
      case .words:
        toast(n.text, n.sub, "pencil.and.outline", n.rarity)
        fx.confetti(at: toastCorner, count: 30, speed: 260)
      }
    }
    let tp = Model.now()
    if engine.ss.xpGained >= 1 && tp - xpAt > 0.7 {
      fx.floater("+" + Fmt.num(engine.ss.xpGained) + " XP", at: CGPoint(x: fx.xpPos.x, y: fx.xpPos.y - 8), colour: Theme.xp)
      fx.burst(at: fx.xpPos, count: 6, colours: [Theme.xp], speed: 90, size: 3)
      engine.ss.xpGained = 0
      xpAt = tp
    }
  }

  func closeStage() {
    guard !stage.isEmpty else { return }
    let s = stage.removeFirst()
    if s.kind == .welcome {
      engine.st.settings.welcome = true
      dirty = true
      if engine.checkinAvailable(Model.epoch()) { stage.insert(StageItem(kind: .checkin), at: 0) }
    }
    objectWillChange.send()
  }

  func openStageCrate() {
    guard !stage.isEmpty, stage[0].crate > 0, !stage[0].opened else { return }
    stage[0].opened = true
    stage[0].sub = "Added to your things"
    let r = stage[0].crate
    let w = NSApp.keyWindow?.contentView?.bounds.width ?? 1000
    fx.burst(at: CGPoint(x: w / 2, y: 330), count: 40 + r * 10, colours: [Theme.rarity(r), Theme.bright, Theme.accent], speed: 420, size: 5)
    fx.ring(at: CGPoint(x: w / 2, y: 330), colour: Theme.rarity(r), radius: 160, life: 0.9)
    if r >= Rarity.epic { fx.confetti(at: CGPoint(x: w / 2, y: 300), count: 80) }
    sound(r >= Rarity.legendary ? "Hero" : "Pop")
    objectWillChange.send()
  }

  /// Opens a box from Loot or a level-up: it plays on the stage.
  func openCrate(_ r: Int) {
    act { _ = $0.openCrate(r) }
    tab = .loot
  }

  // Settings ----------------------------------------------------------------------------

  func setAutostart(_ on: Bool) {
    do {
      if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      engine.st.settings.autostart = on
      dirty = true
    } catch {
      toast("Couldn't change that", "Move the app into Applications and try again", "exclamationmark.triangle", 1, life: 6)
    }
    objectWillChange.send()
  }

  func toggleApp(_ id: String, _ on: Bool) {
    act { e in
      e.st.settings.apps.removeAll { $0 == id }
      if on { e.st.settings.apps.append(id) }
    }
  }

  // For the window ----------------------------------------------------------------------

  var waitingDot: Set<Tab> {
    var s = Set<Tab>()
    let ep = Model.epoch()
    if engine.checkinAvailable(ep) || (st.daily.quests + st.weekly.quests).contains(where: { $0.done && !$0.claimed }) { s.insert(.quests) }
    if st.inv.crates.contains(where: { $0 > 0 }) { s.insert(.loot) }
    if st.shop.deals.contains(where: { !$0.bought && st.coins >= $0.price }) { s.insert(.shop) }
    return s
  }

  var secsToTier: Double { Rules.tierSeconds - st.pass.secs }

  var statusLine: String {
    if engine.ss.idle {
      return counting ? "Paused - start writing" : "Paused - open your writing app"
    }
    return "Next tier in " + Fmt.clock(secsToTier)
  }
}
