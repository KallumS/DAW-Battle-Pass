import XCTest
@testable import PassCore

final class LootTests: XCTestCase {
  func testDice() {
    XCTAssertEqual(Dice(5).next(), Dice(5).next(), "a seed is the same dice")
    let d = Dice(7)
    for _ in 0..<10000 {
      let x = d.next(); XCTAssertTrue(x >= 0 && x < 1)
      XCTAssertTrue((3...9).contains(d.between(3, 9)))
    }
    XCTAssertEqual(seedOf("tier", 10, 37), seedOf("tier", 10, 37))
    XCTAssertNotEqual(seedOf("tier", 10, 37), seedOf("tier", 10, 38))
  }

  func testArticles() {
    XCTAssertEqual(articles("a estate agent and a florist"), "an estate agent and a florist")
    XCTAssertEqual(articles("A ode"), "An ode")
    XCTAssertEqual(articles("Margot Vale, a idea"), "Margot Vale, an idea")
    XCTAssertEqual(plural("Story"), "Stories")
  }

  func testLuck() {
    func epics(_ luck: Double) -> Int {
      let d = Dice(3); var n = 0
      for _ in 0..<20000 where Rarity.roll(d, luck: luck) >= Rarity.epic { n += 1 }
      return n
    }
    XCTAssertGreaterThan(epics(100), epics(0) * 2, "luck makes rare things likelier")
  }

  /// Every prompt kind at every rarity, thousands of times: no blanks, no
  /// placeholders, no "a apple", and rarer is never shorter than Poor.
  func testEveryIdeaAtEveryRarity() {
    // Each broken rule is reported once, with a count and an example, so
    // one mistake can't bury the others in the log.
    var broken: [String: (Int, String)] = [:]
    func flag(_ rule: String, _ example: String) {
      let n = (broken[rule]?.0 ?? 0) + 1
      broken[rule] = (n, broken[rule]?.1 ?? example)
    }
    let d = Dice(2026)
    var seen: [String: Int] = [:]
    for k in Ideas.all {
      for r in 1...7 {
        var totalLen = 0
        for _ in 0..<150 {
          let x = Ideas.make(d, k.id, r)
          if x.type != "idea" || x.kind != k.id { flag("\(k.id): wrong type", x.text) }
          if x.text.isEmpty { flag("\(k.id) \(Rarity.name(r)): no text", "") }
          if x.sub.isEmpty { flag("\(k.id) \(Rarity.name(r)): no line under it", x.text) }
          for bad in ["%", "{", "  ", " a a", " a e", " a i", " a o", " a u", "..", "nil"] {
            if (x.text + " " + x.sub).lowercased().contains(bad) { flag("\(k.id): '\(bad)'", x.text + " / " + x.sub) }
          }
          if let f = x.text.first, String(f) != String(f).uppercased() { flag("\(k.id): starts lower case", x.text) }
          totalLen += x.text.count + x.sub.count
          seen[x.text, default: 0] += 1
        }
        if r == Rarity.mythic && totalLen <= 150 * 20 { flag("\(k.id): Mythic prompts too short", "") }
      }
    }
    for (rule, (n, example)) in broken.sorted(by: { $0.key < $1.key }) {
      XCTFail("\(rule) (\(n) times), e.g. \(example)")
    }
    XCTAssertGreaterThan(seen.count, 4000, "endless: thousands of different prompts")
  }

  func testRarerIsRicher() {
    for k in Ideas.all where !["title", "penname", "mash"].contains(k.id) {
      var lens = [Int](repeating: 0, count: 8)
      let d = Dice(77)
      for r in [Rarity.common, Rarity.mythic] {
        for _ in 0..<200 { let x = Ideas.make(d, k.id, r); lens[r] += x.text.count + x.sub.count }
      }
      XCTAssertGreaterThan(lens[Rarity.mythic], lens[Rarity.common], "\(k.id): Mythic is richer than Common")
    }
  }

  func testGear() {
    let d = Dice(31)
    let counts = [0, 0, 1, 2, 3, 3, 4]
    for r in 1...7 {
      for _ in 0..<400 {
        let g = Gear.make(d, r, ilvl: d.between(1, 120))
        let slot = Gear.slot(g.slot!)!
        XCTAssertEqual(g.affixes?.count, counts[r - 1], "affixes by rarity")
        let ids = g.affixes!.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "no affix twice")
        XCTAssertFalse(ids.contains(slot.implicit), "never the implicit again")
        XCTAssertEqual(g.implicit?.id, slot.implicit)
        XCTAssertEqual(g.power != nil, r >= Rarity.legendary, "powers on Legendary and Mythic")
        XCTAssertTrue(slot.bases.contains(g.base!))
        XCTAssertTrue(g.affixes!.allSatisfy { $0.value >= 1 })
        switch r {
        case Rarity.poor: XCTAssertTrue(Gear.junk.contains { g.name.hasPrefix($0 + " ") }, g.name)
        case Rarity.common: XCTAssertEqual(g.name, g.base)
        case Rarity.legendary: XCTAssertTrue(g.name.contains("'s "), g.name)
        case Rarity.mythic: XCTAssertTrue(g.name.contains(", "), g.name)
        default: break
        }
        for (id, v) in Gear.stats(g) { XCTAssertFalse(Gear.statLine(id, v).contains("%d"), id) }
      }
    }
    XCTAssertGreaterThan(Gear.score(Gear.make(Dice(1), 7, ilvl: 50)), Gear.score(Gear.make(Dice(1), 2, ilvl: 50)))
  }

  func testCratesAndTiers() {
    let d = Dice(5)
    for r in 2...7 {
      for _ in 0..<200 {
        let c = Loot.crateContents(d, r)
        XCTAssertEqual(c.count, 3)
        XCTAssertGreaterThanOrEqual(c[0].rarity, r, "one at least the box's rarity")
        XCTAssertTrue(c.allSatisfy { $0.rarity >= r - 2 || $0.type == "token" })
      }
    }
    let (a, ka) = Loot.tierRewards(season: 10, tier: 37, ilvl: 5)
    let (b, _) = Loot.tierRewards(season: 10, tier: 37, ilvl: 5)
    XCTAssertEqual(a, b, "a tier's reward is a function of season and tier")
    XCTAssertEqual(ka, "small")
    XCTAssertEqual(Loot.tierKind(4), "big")
    XCTAssertEqual(Loot.tierKind(10), "milestone")
    XCTAssertEqual(Loot.tierKind(25), "legendary")
    XCTAssertEqual(Loot.tierKind(100), "finale")
    XCTAssertEqual(Loot.tierKind(120), "big", "bonus tiers go on")
    let (fin, _) = Loot.tierRewards(season: 10, tier: 100, ilvl: 5)
    XCTAssertTrue(fin.contains { $0.type == "title" && $0.text.hasPrefix("Champion of ") })
    for t in 1...130 { XCTAssertFalse(Loot.tierRewards(season: 11, tier: t, ilvl: 3).0.isEmpty) }
    XCTAssertFalse(Loot.seasonName(10).isEmpty)
  }

  func testTitlesAndBanners() {
    let d = Dice(8)
    for r in 1...7 {
      for _ in 0..<100 {
        let t = Looks.title(d, r)
        XCTAssertFalse(t.text.isEmpty)
        let b = Looks.banner(d, r)
        XCTAssertNotNil(b.banner)
        XCTAssertEqual(b.banner!.glyph != nil, r >= Rarity.rare)
      }
    }
  }

  func testShopIsSane() {
    let ids = (Rules.defaultRewards + Rules.fixedShop).map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count, "every shop id is different")
    XCTAssertEqual(Rules.defaultRewards.map(\.price), Rules.defaultRewards.map(\.price).sorted(), "cheapest first")
  }

  /// Prints a sample of every reward at every rarity - read it before and
  /// after changing a word list (it's in the CI log under "Demo").
  func testDemo() {
    let d = Dice(seedOf("demo", 1))
    var out = ["", "==== Demo: every reward at every rarity ===="]
    for k in Ideas.all {
      out.append("-- \(k.label)")
      for r in 1...7 {
        let x = Ideas.make(d, k.id, r)
        out.append("  [\(Rarity.name(r))] \(x.text)  //  \(x.sub)")
      }
    }
    out.append("-- Wardrobe")
    for r in 1...7 {
      let g = Gear.make(d, r, ilvl: 10)
      let stats = Gear.stats(g).map { Gear.statLine($0.key, $0.value) }.sorted().joined(separator: "; ")
      out.append("  [\(Rarity.name(r))] \(g.name) (\(g.sub)) \(stats)\(g.power.map { "  POWER: " + (Gear.power($0)?.text ?? $0) } ?? "")")
    }
    out.append("-- Titles and banners")
    for r in 1...7 { out.append("  [\(Rarity.name(r))] \(Looks.title(d, r).text)  /  \(Looks.banner(d, r).text)") }
    out.append("-- Seasons: " + (10...15).map { Loot.seasonName($0) }.joined(separator: ", "))
    print(out.joined(separator: "\n"))
  }
}

/// The economy: about how many coins an hour of writing earns, all told -
/// tiers, quests, check-ins, gift boxes, achievements - which is what the
/// prices are set from. Printed in the CI log under "Economy".
final class EconomyTests: XCTestCase {
  func testCoinsAnHour() {
    let r = Rig()
    var hours = 0.0
    for day in 0..<14 {
      r.epoch = START + day * 86400 - 3600 * 2
      r.g.refresh(r.epoch)
      r.g.checkin(r.epoch)
      // Two hours of writing: about 1,000 words an hour.
      for minute in 0..<120 {
        r.run(60, every: 7)
        r.g.event("letters", 92)
        r.g.event("words", 17)
        if minute % 10 == 0 {
          r.g.checkAchievements()
          for s in ["daily", "weekly"] { for i in 0..<4 { r.g.claimQuest(s, i) } }
          for c in 1...7 { while r.g.openCrate(c) != nil {} }
          r.g.salvageUpTo(Rarity.common)
        }
      }
      hours += 2
      r.run(600, every: nil)
    }
    let perHour = r.g.st.stats.coinsEarned / hours
    let levels = r.g.st.level
    print("\n==== Economy: \(Int(perHour)) coins an hour of writing; level \(levels) after \(Int(hours)) hours; tier \(r.g.st.pass.tier) ====")
    for item in Rules.defaultRewards {
      print("  " + item.name.padding(toLength: 24, withPad: " ", startingAt: 0)
            + String(format: "%6d coins  about %.1f hours", item.price, Double(item.price) / perHour))
    }
    XCTAssertTrue((350...900).contains(perHour), "about 550 coins an hour (\(perHour))")
  }
}
