import XCTest
@testable import PassCore

final class DateTests: XCTestCase {
  func testDays() {
    XCTAssertEqual(Dates.dayKey(START), "2026-10-08", "8pm is today")
    XCTAssertEqual(Dates.dayKey(at(2026, 10, 9, 2)), "2026-10-08", "2am still counts as the day before")
    XCTAssertEqual(Dates.dayKey(at(2026, 10, 9, 5)), "2026-10-09", "5am is the new day")
    XCTAssertEqual(Dates.weekKey(START), "2026-10-05", "a week is named for its Monday")
    XCTAssertEqual(Dates.weekKey(at(2026, 10, 11, 23)), "2026-10-05", "Sunday night is the same week")
    XCTAssertEqual(Dates.weekKey(at(2026, 10, 12, 9)), "2026-10-12", "Monday morning is a new week")
    XCTAssertEqual(Dates.daysBetween("2026-10-08", "2026-10-09"), 1)
    XCTAssertEqual(Dates.daysBetween("2026-12-31", "2027-01-02"), 2, "across the new year")
    XCTAssertEqual(Dates.seasonOf(START), 10, "October 2026 is season 10")
    XCTAssertEqual(Dates.secsToNextDay(START), 8 * 3600, "the day turns at 4am")
    XCTAssertEqual(Dates.secsToNextSeason(at(2026, 12, 31, 12)), 16 * 3600, "December turns into January")
    XCTAssertEqual(Dates.hourAndWeekday(START).1, 4, "8 October 2026 is a Thursday")
  }
}

final class ClockTests: XCTestCase {
  func testPausedUntilShesWriting() {
    let r = Rig()
    r.run(600, every: nil)
    XCTAssertEqual(r.g.st.stats.active, 0, "opening the app isn't writing")
    XCTAssertTrue(r.g.ss.idle)
  }

  func testTiersEveryFifteenMinutes() {
    let r = Rig()
    r.g.refresh(r.epoch)
    r.run(15 * 60 + 1)
    XCTAssertEqual(r.g.st.pass.tier, 1, "fifteen minutes of writing unlock a tier")
    XCTAssertEqual(r.count(.tier), 1)
    r.run(45 * 60)
    XCTAssertEqual(r.g.st.pass.tier, 4, "an hour is four tiers")
    let n = r.last(.tier)!
    XCTAssertEqual(n.tierKind, "big", "and the fourth is the big one")
    XCTAssertGreaterThanOrEqual(n.drops.count, 3)
    XCTAssertGreaterThan(r.g.st.level, 1, "an hour's minutes level you up")
  }

  func testIdle() {
    let r = Rig()
    r.run(60, every: 10)
    let before = r.g.st.stats.active
    r.run(30 * 60, every: nil)
    XCTAssertLessThanOrEqual(r.g.st.stats.active - before, Rules.idleSeconds + 1, "the clock stops after the idle time")
    XCTAssertTrue(r.g.ss.idle)
    XCTAssertEqual(r.count(.idle), 1, "said once")
    r.run(5, every: 1)
    XCTAssertFalse(r.g.ss.idle, "writing again brings her back")
    XCTAssertEqual(r.count(.active), 2, "once at the start, once coming back")
  }

  func testIdleSettingAndDeepFocus() {
    let r = Rig()
    r.g.st.settings.idle = 600
    r.run(60, every: 10)
    r.run(500, every: nil)
    XCTAssertFalse(r.g.ss.idle, "the idle time is a setting")
    var charm = Gear.make(Dice(1), Rarity.legendary, ilvl: 1, slot: "charm")
    charm.power = "deep_focus"; charm.affixes = []
    r.g.st.gear.equipped["charm"] = charm
    XCTAssertEqual(r.g.idleLimit(), 600 + 180, "Deep Focus adds three minutes")
  }

  func testDtIsCapped() {
    let r = Rig()
    r.run(10, every: 1)
    let a = r.g.st.stats.active
    r.tp += 3600; r.epoch += 3600
    r.g.tick(r.tp, r.epoch, Signals(input: true))
    XCTAssertLessThanOrEqual(r.g.st.stats.active - a, 1.0, "a sleeping Mac doesn't count as an hour")
  }
}

final class XpTests: XCTestCase {
  func testLevels() {
    let r = Rig()
    XCTAssertEqual(Rules.levelNeed(1), 200)
    r.g.addXp(200, "quest")
    XCTAssertEqual(r.g.st.level, 2)
    XCTAssertEqual(r.count(.level), 1)
    XCTAssertEqual(r.g.st.inv.crates.reduce(0, +), 1, "a level gives a gift box")
    r.g.st.level = 4; r.g.st.xp = 0
    r.g.addXp(Rules.levelNeed(4), "quest")
    XCTAssertGreaterThanOrEqual(r.g.st.inv.crates[3], 1, "level 5 gives a Rare box")
    r.g.st.boost = 100
    XCTAssertEqual(r.g.addXp(10, "quest"), 20, "a boost doubles XP")
  }

  func testLettersAreSmallAndCapped() {
    let r = Rig()
    r.run(1, every: 1)
    let xp0 = r.g.st.stats.xpTotal
    r.g.event("letters", 10)
    XCTAssertEqual(r.g.st.stats.xpTotal - xp0, 1, accuracy: 0.001, "ten letters are one XP")
    // Mashing the keyboard: 5,000 letters in a minute.
    for _ in 0..<50 { r.g.event("letters", 100) }
    XCTAssertLessThanOrEqual(r.g.st.stats.xpTotal - xp0, Rules.letterXpCap + 0.001, "typing XP is capped a minute")
    XCTAssertEqual(r.g.st.stats.letters, 5010, "but every letter is still counted")
    r.run(61, every: 1)
    let xp1 = r.g.st.stats.xpTotal
    r.g.event("letters", 100)
    XCTAssertGreaterThan(r.g.st.stats.xpTotal - xp1, 9.9, "the cap resets each minute")
  }

  func testTypingGearBoostsLetters() {
    let r = Rig()
    r.run(1, every: 1)
    var pen = Gear.make(Dice(3), Rarity.common, ilvl: 1, slot: "pen")
    pen.implicit = Stat(id: "typing", value: 50); pen.affixes = []
    r.g.st.gear.equipped["pen"] = pen
    XCTAssertEqual(r.g.addXp(1, "letters"), 1.5, accuracy: 0.001, "+50% typing XP")
    XCTAssertEqual(r.g.addXp(1, "quest"), 1, accuracy: 0.001, "and only typing")
  }

  func testAnHourOfWritingIsModest() {
    // A thousand words in an hour: about 5,500 letters.
    let r = Rig()
    let xp0 = r.g.st.stats.xpTotal
    for minute in 0..<60 {
      r.run(60, every: 5)
      r.g.event("letters", minute % 2 == 0 ? 90 : 93)
      r.g.event("words", 17)
    }
    let fromTyping = r.g.st.stats.letters * Rules.xpLetter
    XCTAssertEqual(fromTyping, 5490 * 0.1, accuracy: 1)
    XCTAssertLessThan(fromTyping, 1.5 * Double(60) * Rules.xpMinute * 3, "typing is a top-up, not the whole bar")
    XCTAssertGreaterThan(r.g.st.stats.xpTotal - xp0, 700)
  }
}

final class WordTests: XCTestCase {
  func testWordsSprintsAndToasts() {
    let r = Rig()
    r.run(1, every: 1)
    for _ in 0..<10 { r.g.event("words", 30); r.run(60, every: 5) }
    XCTAssertEqual(r.g.st.stats.words, 300)
    XCTAssertEqual(r.g.st.dayWords["2026-10-08"], 300)
    XCTAssertEqual(r.count(.words), 1, "a toast at 250 words")
    XCTAssertEqual(r.g.sprintWords(), 300, accuracy: 30, "all of it inside fifteen minutes")
    r.run(16 * 60, every: 5)
    XCTAssertEqual(r.g.sprintWords(), 0, "the sprint window moves on")
    XCTAssertEqual(r.g.st.stats.sprintBest, 300, accuracy: 30)
  }

  func testWordsMoveQuests() {
    let r = Rig()
    r.g.refresh(r.epoch)
    r.g.st.daily.quests = [Engine.makeQuest(Dice(1), Rules.questTemplate("words")!, "daily")]
    let target = r.g.st.daily.quests[0].target
    r.run(1, every: 1)
    r.g.event("words", target)
    XCTAssertTrue(r.g.st.daily.quests[0].done)
    XCTAssertEqual(r.count(.quest), 1)
  }

  func testDaysWritten() {
    let r = Rig()
    r.run(30, every: 1)
    XCTAssertEqual(r.g.st.stats.daysWritten, 1)
    r.epoch += 86400
    r.run(30, every: 1)
    XCTAssertEqual(r.g.st.stats.daysWritten, 2)
  }
}

final class QuestTests: XCTestCase {
  func testQuestSets() {
    for seed in 1...200 {
      let d = Engine.makeQuests(Dice(seed), "daily")
      XCTAssertEqual(d.count, 3)
      XCTAssertEqual(d[0].kind, "minutes")
      XCTAssertEqual(Set(d.map(\.kind)).count, 3, "no kind twice")
      let w = Engine.makeQuests(Dice(seed), "weekly")
      XCTAssertEqual(w.count, 4)
      XCTAssertEqual(w[1].kind, "dailies")
      XCTAssertTrue(w.allSatisfy { $0.crate == 4 }, "a weekly gives a Rare box")
      for q in d + w {
        XCTAssertFalse(q.text.contains("%"), q.text)
        XCTAssertGreaterThan(q.target, 0)
      }
    }
  }

  func testClaimAndBonus() {
    let r = Rig()
    r.g.refresh(r.epoch)
    for i in r.g.st.daily.quests.indices { r.g.st.daily.quests[i].progress = r.g.st.daily.quests[i].target; r.g.st.daily.quests[i].done = true }
    let coins = r.g.st.coins
    for i in r.g.st.daily.quests.indices { XCTAssertTrue(r.g.claimQuest("daily", i)) }
    XCTAssertFalse(r.g.claimQuest("daily", 0), "not twice")
    XCTAssertGreaterThan(r.g.st.coins, coins)
    XCTAssertTrue(r.g.st.daily.bonus)
    XCTAssertGreaterThanOrEqual(r.g.st.inv.crates[2], 1, "all three claimed: an Uncommon box")
  }

  func testUnclaimedAreClaimedAtTheTurn() {
    let r = Rig()
    r.g.refresh(r.epoch)
    r.g.st.daily.quests[0].done = true
    r.g.st.daily.quests[0].progress = r.g.st.daily.quests[0].target
    let coins = r.g.st.coins
    r.g.refresh(r.epoch + 86400)
    XCTAssertGreaterThan(r.g.st.coins, coins, "nothing earned is lost to the clock")
    XCTAssertEqual(r.g.st.daily.key, "2026-10-09")
  }

  func testMinutesAndDailiesChain() {
    let r = Rig()
    r.g.refresh(r.epoch)
    let target = r.g.st.daily.quests[0].target
    r.run(Int(target) + 5)
    XCTAssertTrue(r.g.st.daily.quests[0].done, "writing time fills the minutes quest")
    XCTAssertGreaterThanOrEqual(r.g.st.weekly.quests[1].progress, 1, "and a daily done counts for the week")
  }

  func testReroll() {
    let r = Rig()
    r.g.refresh(r.epoch)
    XCTAssertEqual(r.g.st.inv.tokens["reroll"], 1, "she starts with one reroll")
    let before = r.g.st.daily.quests[1]
    XCTAssertTrue(r.g.reroll("daily", 1))
    XCTAssertNotEqual(r.g.st.daily.quests[1].kind, before.kind)
    XCTAssertFalse(r.g.reroll("daily", 1), "no tokens left")
  }
}

final class CheckinTests: XCTestCase {
  func testStreaksAndFreezes() {
    let r = Rig()
    XCTAssertTrue(r.g.checkinAvailable(r.epoch))
    let a = r.g.checkin(r.epoch)!
    XCTAssertEqual(a.day, 1); XCTAssertEqual(a.coins, 25)
    XCTAssertNil(r.g.checkin(r.epoch), "once a day")
    XCTAssertEqual(r.g.checkin(r.epoch + 86400)!.streak, 2)
    // Miss a day with no freeze: the streak breaks.
    let c = r.g.checkin(r.epoch + 3 * 86400)!
    XCTAssertEqual(c.streak, 1); XCTAssertTrue(c.broke)
    // Miss a day with a freeze: kept.
    r.g.st.inv.tokens["freeze"] = 1
    let d = r.g.checkin(r.epoch + 5 * 86400)!
    XCTAssertEqual(d.streak, 2); XCTAssertEqual(d.freezes, 1)
    XCTAssertEqual(r.g.st.inv.tokens["freeze"], 0)
  }

  func testDaySevenBox() {
    let r = Rig()
    for i in 0..<7 { r.g.checkin(r.epoch + i * 86400) }
    XCTAssertEqual(r.g.st.inv.crates[4], 1, "day seven gives an Epic box")
    XCTAssertEqual(r.g.st.inv.crates[2], 1, "day three an Uncommon")
  }
}

final class ShopTests: XCTestCase {
  func testBuyRedeem() {
    let r = Rig()
    XCTAssertFalse(r.g.buy("gig"), "not without the coins")
    r.g.st.coins = 2500
    XCTAssertTrue(r.g.buy("gig"))
    XCTAssertEqual(r.g.st.coins, 300)
    XCTAssertEqual(r.g.st.inv.passes["gig"], 1)
    XCTAssertTrue(r.g.redeem("gig", r.epoch))
    XCTAssertNil(r.g.st.inv.passes["gig"])
    XCTAssertEqual(r.g.st.log.first?.name, "Gig Ticket Pass")
    XCTAssertEqual(r.count(.redeem), 1)
    XCTAssertFalse(r.g.redeem("gig", r.epoch))
  }

  func testTokensBoxesAndDeals() {
    let r = Rig()
    r.g.st.coins = 10000
    XCTAssertTrue(r.g.buy("boost"))
    XCTAssertTrue(r.g.useBoost())
    XCTAssertEqual(r.g.st.boost, Rules.boostSeconds)
    XCTAssertTrue(r.g.buy("crate5"))
    XCTAssertEqual(r.g.st.inv.crates[4], 1)
    r.g.refresh(r.epoch)
    XCTAssertEqual(r.g.st.shop.deals.count, 3)
    XCTAssertTrue(r.g.st.shop.deals.allSatisfy { (4...6).contains($0.drop.rarity) })
    XCTAssertTrue(r.g.buyDeal(0))
    XCTAssertFalse(r.g.buyDeal(0), "a deal sells once")
  }

  func testHerOwnRewards() {
    let r = Rig()
    let id = r.g.addReward(name: "Spa Day Pass", price: 7000)
    XCTAssertEqual(r.g.shopItem(id)?.price, 7000)
    var item = r.g.shopItem(id)!
    item.price = 6500; item.name = "  "
    r.g.updateReward(item)
    XCTAssertEqual(r.g.shopItem(id)?.price, 6500)
    XCTAssertEqual(r.g.shopItem(id)?.name, "Spa Day Pass", "a blank name keeps the old one")
    r.g.st.coins = 7000
    XCTAssertTrue(r.g.buy(id))
    XCTAssertFalse(r.g.removeReward(id), "not while she owns one")
    XCTAssertTrue(r.g.redeem(id, r.epoch))
    XCTAssertTrue(r.g.removeReward(id))
    XCTAssertNil(r.g.shopItem(id))
  }
}

final class GearTests: XCTestCase {
  func testEquipSalvage() {
    let r = Rig()
    let a = r.g.grant(Gear.make(Dice(5), Rarity.rare, ilvl: 3, slot: "phones"))
    let b = r.g.grant(Gear.make(Dice(6), Rarity.epic, ilvl: 3, slot: "phones"))
    XCTAssertEqual(r.g.st.gear.stash.count, 2)
    let ua = r.g.st.gear.stash[1].uid!, ub = r.g.st.gear.stash[0].uid!
    XCTAssertTrue(r.g.equip(ua))
    XCTAssertEqual(r.g.st.gear.equipped["phones"]?.name, a.name)
    XCTAssertTrue(r.g.equip(ub))
    XCTAssertEqual(r.g.st.gear.equipped["phones"]?.name, b.name, "the new one goes on")
    XCTAssertEqual(r.g.st.gear.stash.count, 1, "the old one back in the wardrobe")
    XCTAssertGreaterThan(r.g.bonus("coins"), 0, "headphones' implicit is coins")
    let coins = r.g.st.coins
    XCTAssertGreaterThan(r.g.salvage(ua), 0)
    XCTAssertGreaterThan(r.g.st.coins, coins)
  }

  func testFullWardrobeSellsTheWeakest() {
    let r = Rig()
    let d = Dice(9)
    for _ in 0..<Rules.stashMax { r.g.grant(Gear.make(d, Rarity.rare, ilvl: 1)) }
    r.g.grant(Gear.make(d, Rarity.poor, ilvl: 1))
    XCTAssertEqual(r.g.st.gear.stash.count, Rules.stashMax)
    XCTAssertFalse(r.g.st.gear.stash.contains { $0.rarity == Rarity.poor }, "the Poor one was sold")
  }

  func testGearNeverShortensATier() {
    let r = Rig()
    let d = Dice(11)
    for s in Gear.slots { r.g.st.gear.equipped[s.id] = Gear.make(d, Rarity.mythic, ilvl: 100, slot: s.id) }
    r.run(15 * 60 - 30)
    XCTAssertEqual(r.g.st.pass.tier, 0, "Mythic everything, and a tier still takes fifteen minutes")
  }
}

final class CosmeticTests: XCTestCase {
  func testBinningTitlesAndBanners() {
    let r = Rig()
    for (i, rr) in [2, 5, 1, 6].enumerated() {
      r.g.grant(Drop(type: "title", rarity: rr, name: "Title", icon: "crown", text: "T\(i)"))
    }
    r.g.st.profile.title = 3                        // wearing T3
    XCTAssertTrue(r.g.binTitle(1))                  // T1 goes
    XCTAssertEqual(r.g.st.cos.titles.map(\.text), ["T0", "T2", "T3"])
    XCTAssertEqual(r.g.activeTitle(), "T3", "still wearing the same title")
    XCTAssertTrue(r.g.binTitle(2))                  // the worn one
    XCTAssertEqual(r.g.st.profile.title, -1, "binning the worn title wears none")
    XCTAssertFalse(r.g.binTitle(9))
    let coins = r.g.st.coins
    for rr in [1, 2, 4] { r.g.grant(Looks.banner(Dice(rr), rr)) }
    r.g.st.profile.banner = 0                       // wearing a Poor banner
    r.g.st.profile.title = 1                        // wearing T2 (Poor)
    let n = r.g.binCosmeticsUpTo(Rarity.common)
    XCTAssertEqual(n, 2, "T0 and the Common banner; the worn ones stay")
    XCTAssertEqual(r.g.st.cos.titles.map(\.text), ["T2"])
    XCTAssertEqual(r.g.st.profile.title, 0)
    XCTAssertEqual(r.g.st.cos.banners.map(\.rarity), [1, 4])
    XCTAssertEqual(r.g.st.profile.banner, 0)
    XCTAssertEqual(r.g.st.coins, coins, "binned for nothing")
  }
}

final class CrateTests: XCTestCase {
  func testOpening() {
    let r = Rig()
    r.g.st.inv.crates[3] = 1
    let drops = r.g.openCrate(4)!
    XCTAssertGreaterThanOrEqual(drops.count, 3)
    XCTAssertGreaterThanOrEqual(drops[0].rarity, 4)
    XCTAssertNil(r.g.openCrate(4), "none left")
    XCTAssertEqual(r.g.ss.notices.first { $0.kind == .crate }?.drops.count, drops.count)
  }

  func testCrateBeforeLevel() {
    let r = Rig()
    r.g.st.xp = Rules.levelNeed(1) - 1
    r.g.st.inv.crates[6] = 1
    // A Mythic box is all but certain to hold enough XP to level.
    for _ in 0..<1 { _ = r.g.openCrate(7) }
    if let li = r.g.ss.notices.firstIndex(where: { $0.kind == .level }) {
      let ci = r.g.ss.notices.firstIndex { $0.kind == .crate }!
      XCTAssertLessThan(ci, li, "the box opens before the level-up it causes")
    }
  }
}

final class SeasonTests: XCTestCase {
  func testNewMonthNewSeason() {
    let r = Rig(at(2026, 10, 31, 20))
    r.g.refresh(r.epoch)
    r.g.st.pass.tier = 12
    r.g.refresh(at(2026, 11, 1, 10))
    XCTAssertEqual(r.g.st.pass.season, 11)
    XCTAssertEqual(r.g.st.pass.tier, 0)
    XCTAssertEqual(r.g.st.seasons["10"], 12)
    XCTAssertEqual(r.count(.season), 1)
  }
}

final class AchievementTests: XCTestCase {
  func testWordAchievements() {
    let r = Rig()
    r.g.st.stats.words = 1000
    r.g.checkAchievements()
    XCTAssertEqual(r.g.st.ach["words"], 1)
    XCTAssertEqual(r.last(.ach)?.text, "Write 1,000 words")
    r.g.st.stats.words = 2_000_000
    r.g.checkAchievements()
    XCTAssertEqual(r.g.st.ach["words"], 7, "every tier passed is awarded")
    XCTAssertTrue(r.g.st.cos.titles.contains { $0.text == "The Prolific" }, "and the last gives its title")
  }

  func testEveryAchievementReads() {
    for a in Achievements.all {
      for t in 1...a.goals.count { XCTAssertFalse(Achievements.text(a, t).contains("%"), a.id) }
      XCTAssertEqual(a.goals, a.goals.sorted(), a.id)
    }
  }
}

final class SaveTests: XCTestCase {
  func testRoundTrip() throws {
    let r = Rig()
    r.g.refresh(r.epoch)
    r.g.st.coins = 1234
    r.g.grant(Gear.make(Dice(2), Rarity.mythic, ilvl: 9))
    r.g.grant(Ideas.make(Dice(2), "character", Rarity.epic))
    r.g.grant(Looks.banner(Dice(2), Rarity.legendary))
    let data = try Save.encode(r.g.st)
    let back = Save.decode(data)!
    XCTAssertEqual(back, r.g.st)
  }

  func testOldSavesAreFilledIn() {
    let json = #"{"coins": 50, "level": 3, "settings": {"idle": 5}, "stats": {"words": 9}, "nonsense": true}"#
    let st = Save.decode(json.data(using: .utf8)!)!
    XCTAssertEqual(st.coins, 50)
    XCTAssertEqual(st.level, 3)
    XCTAssertEqual(st.stats.words, 9)
    XCTAssertEqual(st.settings.idle, 60, "nonsense is put right")
    XCTAssertEqual(st.rewards.count, Rules.defaultRewards.count, "missing things come from a fresh state")
    XCTAssertEqual(st.inv.crates.count, 7)
  }

  func testWrongTypesAreReplaced() {
    let json = #"{"coins": "lots", "profile": {"name": 7}, "settings": {"sound": 1}}"#
    let st = Save.decode(json.data(using: .utf8)!)!
    XCTAssertEqual(st.coins, 0)
    XCTAssertEqual(st.profile.name, "Writer")
    XCTAssertTrue(st.settings.sound)
  }

  func testAtomicWritesAndDamage() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wbp-\(UUID().uuidString)")
    let url = dir.appendingPathComponent("progress.json")
    var st = GameState(epoch: START)
    st.coins = 1
    try Save.write(st, to: url)
    st.coins = 2
    try Save.write(st, to: url)
    XCTAssertEqual(Save.read(from: url, epoch: START).state.coins, 2)
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("bak").path), "the old one is kept")
    try "{ broken".data(using: .utf8)!.write(to: url)
    let (back, damaged) = Save.read(from: url, epoch: START)
    XCTAssertTrue(damaged)
    XCTAssertEqual(back.coins, 1, "a damaged save falls back to the backup")
    let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    XCTAssertTrue(files.contains { $0.contains("damaged") }, "and the damaged one is kept aside")
    XCTAssertEqual(Save.read(from: dir.appendingPathComponent("none.json"), epoch: START).state.coins, 0)
  }
}
