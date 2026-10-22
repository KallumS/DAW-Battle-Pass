import SwiftUI
import AppKit
import PassCore

/// Draws every page and every celebration of a made-up, well-played save to
/// PNGs. CI runs it (`--snapshots`) so the look can be checked without a Mac
/// in front of anyone.
@MainActor
enum Snapshots {
  static func demoEngine() -> Engine {
    let epoch = Int(Date().timeIntervalSince1970)
    let e = Engine(state: GameState(epoch: epoch), tp: 0, epoch: epoch)
    e.st.profile.name = "Rosalind"
    e.st.settings.welcome = true
    e.refresh(epoch)
    let d = Dice(2026)
    e.st.level = 14
    e.st.xp = 420
    e.st.coins = 3240
    e.st.pass.tier = 23
    e.st.pass.secs = 512
    e.st.boost = 600
    for _ in 0..<14 { e.grant(Ideas.make(d, Ideas.randomKind(d), Rarity.roll(d, 2, 7, luck: 200))) }
    for s in Gear.slots.prefix(6) {
      e.grant(Gear.make(d, Rarity.roll(d, 3, 7, luck: 150), ilvl: 12, slot: s.id))
      if let uid = e.st.gear.stash.first?.uid { e.equip(uid) }
    }
    for _ in 0..<9 { e.grant(Gear.make(d, Rarity.roll(d, 1, 7, luck: 50), ilvl: 12)) }
    for r in [4, 5, 6, 7] { e.grant(Looks.title(d, r)); e.grant(Looks.banner(d, r)) }
    e.st.profile.title = 2
    e.st.profile.banner = 3
    e.st.inv.crates = [0, 2, 1, 1, 1, 0, 1]
    e.st.inv.passes = ["lipstick": 1, "coffee": 2]
    e.st.inv.tokens = ["reroll": 2, "freeze": 1, "boost": 1]
    e.st.checkin.streak = 4; e.st.checkin.best = 9; e.st.checkin.total = 21
    e.st.checkin.last = Dates.dayKey(epoch - 86400)
    e.st.stats.redeemed = 2
    e.st.stats.words = 48210; e.st.stats.active = 3600 * 31; e.st.stats.letters = 260000
    e.st.stats.tiers = 120; e.st.stats.crates = 33
    let today = Dates.dayKey(epoch)
    for i in 0..<7 {
      let k = Dates.dayKey(epoch - i * 86400)
      e.st.days[k] = Double([2400, 5400, 0, 3600, 7200, 1800, 4200][i])
      e.st.dayWords[k] = Double([620, 1430, 0, 880, 2010, 350, 1100][i])
    }
    e.st.days[today] = 2400
    e.st.daily.quests[0].progress = e.st.daily.quests[0].target * 0.6
    e.st.daily.quests[1].progress = e.st.daily.quests[1].target
    e.st.daily.quests[1].done = true
    e.st.weekly.quests[0].progress = e.st.weekly.quests[0].target * 0.35
    e.st.log = [LogEntry(id: "coffee", name: "Fancy Coffee Pass", t: epoch - 86400 * 2),
                LogEntry(id: "book", name: "New Book Pass", t: epoch - 86400 * 6)]
    e.checkAchievements()
    _ = e.takeNotices()
    e.ss.idle = false
    e.ss.words = 412
    return e
  }

  static func run(into dir: URL) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let model = Model(snapshot: true, engine: demoEngine())
    model.tapRunning = true
    model.counting = true
    func shot(_ name: String, height: CGFloat = 760) {
      let view = ContentView(model: model).frame(width: 1020, height: height)
      let r = ImageRenderer(content: view)
      r.scale = 1
      guard let img = r.nsImage, let tiff = img.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
        print("snapshot \(name): could not render")
        return
      }
      try? png.write(to: dir.appendingPathComponent(name + ".png"))
      print("snapshot \(name)")
    }
    for t in Tab.allCases {
      model.tab = t
      shot("page-\(t.rawValue)", height: 1500)
    }
    model.toast("Quest complete!", "Write 500 words", "scroll", 4)
    model.toast("Big Day I", "Write 500 words in one day", "trophy.fill", 5, coins: 40, xp: 80, trophy: true)
    model.tab = .quests
    shot("toasts")
    model.toasts = []

    let e = model.engine
    let (drops, kind) = Loot.tierRewards(season: e.st.pass.season, tier: 24, ilvl: e.st.level)
    model.stage = [StageItem(kind: .reward, title: Model.tierTitle(kind, 24), sub: "Fifteen more minutes of writing", drops: drops, tierKind: kind)]
    shot("stage-tier")
    let box = Loot.crateContents(Dice(9), Rarity.epic, ilvl: e.st.level)
    model.stage = [StageItem(kind: .reward, title: "Epic Gift Box", sub: "Click to open it", drops: box, crate: Rarity.epic)]
    shot("stage-box-closed")
    model.stage[0].opened = true
    shot("stage-box-open")
    model.stage = [StageItem(kind: .level, crate: Rarity.rare, level: 15)]
    shot("stage-level")
    model.stage = [StageItem(kind: .checkin)]
    shot("stage-checkin")
    var got = CheckinResult()
    got.day = 5; got.streak = 5; got.token = "reroll"
    model.stage = [StageItem(kind: .checkin, checkin: got)]
    shot("stage-checkin-done")
    model.stage = [StageItem(kind: .redeem, name: "New Lipstick Pass", icon: "mouth.fill")]
    shot("stage-redeem")
    model.stage = [StageItem(kind: .season, title: Loot.seasonName(e.st.pass.season + 1))]
    shot("stage-season")
    model.tapRunning = false
    model.stage = [StageItem(kind: .welcome)]
    shot("stage-welcome")
  }
}
