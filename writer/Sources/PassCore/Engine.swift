import Foundation

/// The rules of the game. Holds the saved state (`st`) and the session
/// (`ss`, what lives only while the app runs) and changes them; what the
/// window should celebrate is pushed onto `ss.notices` for it to animate.
///
/// The time is always passed in, twice over: `tp`, a clock in seconds for
/// idling and dt; `epoch`, Unix time, for days, weeks and seasons. So the
/// tests can run a week in a second.
///
/// The shape of it:
///   - Writing time fills the SEASON PASS: a tier every fifteen minutes,
///     every fourth (each hour) a big one. A season is a calendar month with
///     a 100-tier track, then endless bonus tiers.
///   - Everything you do earns XP - every letter typed a little - which fills
///     the LEVEL bar; every level gives a gift box.
///   - Daily CHECK-IN on a seven-day calendar, a streak, Streak Freezes.
///   - Three DAILY and four WEEKLY QUESTS: words, sprints, sittings.
///   - COINS buy passes (permission slips: a gig ticket, new trainers...),
///     tokens and gift boxes in the SHOP, and three Daily Deals.
///   - A WARDROBE in the manner of Diablo: eight slots of clothes and kit, affixes that boost XP,
///     coins, loot and more, Legendary powers. Sell what you don't want.
///   - ACHIEVEMENTS in series, each with tiers.
public final class Engine {
  public var st: GameState
  public var ss: Session

  public init(state: GameState, tp: Double, epoch: Int) {
    var state = state
    state.stats.sessions += 1
    st = state
    let (h, w) = Dates.hourAndWeekday(epoch)
    ss = Session(start: tp, lastInput: tp - 1e6, xpWinStart: tp, hour: h, wday: w,
                 rnd: Dice(seedOf("session", epoch, tp)))
    // Paused until she writes something.
    ss.idle = true
    ss.epoch = epoch
    ss.wordsToast = st.dayWords[Dates.dayKey(epoch)] ?? 0
  }

  func notice(_ n: Notice) { ss.notices.append(n) }

  /// Hands the window everything that happened since it last asked.
  public func takeNotices() -> [Notice] {
    let n = ss.notices
    ss.notices = []
    return n
  }

  // Gear bonuses ----------------------------------------------------------------

  public func bonus(_ stat: String) -> Double {
    var total = 0
    for item in st.gear.equipped.values {
      if let i = item.implicit, i.id == stat { total += i.value }
      for a in item.affixes ?? [] where a.id == stat { total += a.value }
    }
    return Double(total)
  }

  public func hasPower(_ id: String) -> Bool {
    st.gear.equipped.values.contains { $0.power == id }
  }

  public func gearScore() -> Int { Engine.gearScore(st) }

  static func gearScore(_ st: GameState) -> Int {
    st.gear.equipped.values.reduce(0) { $0 + Gear.score($1) }
  }

  public func idleLimit() -> Double {
    var limit = st.settings.idle + bonus("grace")
    if hasPower("deep_focus") { limit += 180 }
    return limit
  }

  // XP, levels, coins ---------------------------------------------------------------

  static let sourceStat = ["letters": "typing", "idea": "ideas"]

  func levelCrate(_ level: Int) -> Int {
    if level % 50 == 0 { return 7 }
    if level % 25 == 0 { return 6 }
    if level % 10 == 0 { return 5 }
    if level % 5 == 0 { return 4 }
    return Rarity.roll(ss.rnd, 2, 3, luck: bonus("luck"))
  }

  /// Returns the XP actually given.
  @discardableResult
  public func addXp(_ base: Double, _ source: String) -> Double {
    if base <= 0 { return 0 }
    var base = base
    if source == "letters" {
      // Typing XP is capped a minute, so holding a key down or mashing the
      // keyboard can't farm levels.
      let now = ss.now ?? ss.start
      if now - ss.xpWinStart >= 60 { ss.xpWinStart = now; ss.xpWinAmount = 0 }
      let room = Rules.letterXpCap - ss.xpWinAmount
      if room <= 0 { return 0 }
      base = min(base, room)
      ss.xpWinAmount += base
    }
    var pct = bonus("xp")
    if let s = Engine.sourceStat[source] { pct += bonus(s) }
    if ss.active >= 3600 { pct += bonus("endure") }
    if ss.active >= 7200 && hasPower("marathon") { pct += 50 }
    if ss.hour < 5 { pct += bonus("night") }
    if ss.hour >= 5 && ss.hour < 9 { pct += bonus("dawn") }
    if ss.wday == 0 || ss.wday == 6 { pct += bonus("weekend") }
    var xp = base * (1 + pct / 100)
    if st.boost > 0 { xp *= 2 }
    st.xp += xp
    st.stats.xpTotal += xp
    ss.xpGained += xp
    while st.xp >= Rules.levelNeed(st.level) {
      st.xp -= Rules.levelNeed(st.level)
      st.level += 1
      let r = levelCrate(st.level)
      st.inv.crates[r - 1] += 1
      var n = Notice(.level); n.level = st.level; n.crate = r
      notice(n)
    }
    return xp
  }

  /// Coins found (not refunds or sales) get the coin bonus and Midas Touch.
  @discardableResult
  public func addCoins(_ amount: Double, found: Bool) -> Int {
    var n = roundHalf(amount)
    if n <= 0 { return 0 }
    if found {
      let mult: Double = 1 + bonus("coins") / 100
      n = roundHalf(Double(n) * mult)
      if hasPower("midas") && ss.rnd.next() < 0.10 {
        n *= 2
        notice(Notice(.toast, text: "Midas Touch!", sub: "Coins doubled", icon: "coin", rarity: 6))
      }
    }
    st.coins += n
    st.stats.coinsEarned += Double(n)
    var c = Notice(.coins); c.amount = n
    notice(c)
    return n
  }

  // Granting a drop -------------------------------------------------------------------

  func newId() -> Int { let id = st.nextId; st.nextId += 1; return id }

  func remember(_ d: Drop) {
    var r = d
    r.affixes = nil; r.implicit = nil
    st.recent.insert(r, at: 0)
    if st.recent.count > 12 { st.recent.removeLast(st.recent.count - 12) }
  }

  func stashGear(_ item: Drop) {
    var item = item
    if item.uid == nil { item.uid = newId() }
    st.gear.stash.insert(item, at: 0)
    if st.gear.stash.count > Rules.stashMax {
      // Full: sell the weakest thing in it.
      var worst = Int.max, wi = 0
      for (i, it) in st.gear.stash.enumerated() {
        let sc = Gear.score(it) + it.rarity * 100
        if sc < worst { worst = sc; wi = i }
      }
      let sold = st.gear.stash.remove(at: wi)
      let v = Gear.sellValue(sold)
      st.coins += v
      notice(Notice(.toast, text: "Wardrobe full", sub: "Sold \(sold.name) for \(v) coins", icon: "coin", rarity: sold.rarity))
    }
  }

  @discardableResult
  public func grant(_ d: Drop) -> Drop {
    var d = d
    if d.type != "coins" && d.type != "xp" {
      if d.rarity >= Rarity.legendary { st.stats.legendaries += 1 }
      if d.rarity >= Rarity.mythic { st.stats.mythics += 1 }
    }
    switch d.type {
    case "coins":
      let n = addCoins(Double(d.amount ?? 0), found: true)
      d.amount = n; d.text = "\(n) coins"
    case "xp": addXp(Double(d.amount ?? 0), "drop")
    case "token": st.inv.tokens[d.token ?? "reroll", default: 0] += d.amount ?? 1
    case "crate": st.inv.crates[d.rarity - 1] += 1
    case "gear": stashGear(d)
    case "idea":
      d.uid = newId()
      d.t = ss.epoch
      st.vault.append(d)
      st.stats.ideas += 1
      if st.vault.count > Rules.vaultMax, let i = st.vault.firstIndex(where: { $0.fav != true }) {
        st.vault.remove(at: i)
      }
    case "title": st.cos.titles.append(Cosmetic(text: d.text, rarity: d.rarity))
    case "banner": st.cos.banners.append(Cosmetic(text: d.text, rarity: d.rarity, banner: d.banner))
    default: break
    }
    remember(d)
    return d
  }

  // Gift boxes -------------------------------------------------------------------------

  /// Opens a gift box of a rarity (1 Poor ... 7 Mythic).
  @discardableResult
  public func openCrate(_ r: Int) -> [Drop]? {
    guard (1...7).contains(r), st.inv.crates[r - 1] > 0 else { return nil }
    st.inv.crates[r - 1] -= 1
    var extra = 0
    if hasPower("hoarder") { extra += 1 }
    if ss.rnd.next() * 100 < bonus("crate") { extra += 1 }
    var drops = Loot.crateContents(ss.rnd, r, luck: bonus("luck"), extra: extra,
                                   ilvl: st.level, collector: hasPower("collector"))
    st.stats.crates += 1
    // Announced before it is granted, so the box opens before any level-up
    // its contents cause.
    var n = Notice(.crate); n.rarity = r
    let at = ss.notices.count
    notice(n)
    drops = drops.map { grant($0) }
    ss.notices[at].drops = drops
    progress("crates", 1)
    return drops
  }

  // The season pass ---------------------------------------------------------------------

  /// A new month is a new season: the track starts again, and the minutes
  /// towards the next tier carry over.
  @discardableResult
  public func checkSeason(_ epoch: Int) -> Bool {
    let id = Dates.seasonOf(epoch)
    if st.pass.season == id { return false }
    if st.pass.season != 0 {
      st.seasons[String(st.pass.season)] = st.pass.tier
      var n = Notice(.season, text: Loot.seasonName(id)); n.season = id
      notice(n)
    }
    st.pass.season = id
    st.pass.tier = 0
    return true
  }

  @discardableResult
  public func unlockTier() -> [Drop] {
    st.pass.tier += 1
    st.stats.tiers += 1
    var (drops, kind) = Loot.tierRewards(season: st.pass.season, tier: st.pass.tier, ilvl: st.level,
                                         collector: hasPower("collector"))
    if kind != "small" && hasPower("golden_hour") {
      drops.append(Loot.drop(ss.rnd, Rarity.roll(ss.rnd, Rarity.rare, Rarity.mythic, luck: bonus("luck")),
                             pool: "crate", ilvl: st.level))
    }
    var n = Notice(.tier); n.tier = st.pass.tier; n.tierKind = kind
    let at = ss.notices.count
    notice(n)
    drops = drops.map { grant($0) }
    ss.notices[at].drops = drops
    if st.pass.tier == Loot.seasonTiers { st.stats.seasonsDone += 1 }
    progress("tiers", 1)
    return drops
  }

  // Time: the idle-aware clock ------------------------------------------------------------

  public func tick(_ tp: Double, _ epoch: Int, _ signals: Signals) {
    let dt = max(0, min(1, tp - (ss.now ?? tp)))
    ss.now = tp
    ss.epoch = epoch
    (ss.hour, ss.wday) = Dates.hourAndWeekday(epoch)
    if signals.input { ss.lastInput = tp }
    let idle = (tp - ss.lastInput) > idleLimit()
    if idle != ss.idle {
      ss.idle = idle
      if idle {
        notice(Notice(.idle))
      } else {
        notice(Notice(.active))
        if hasPower("second_wind") && tp - ss.lastWind >= 1800 && ss.active > 0 {
          ss.lastWind = tp
          addXp(Rules.xpWind, "wind")
          notice(Notice(.toast, text: "Second Wind", sub: "+\(Int(Rules.xpWind)) XP for coming back", icon: "bolt.fill", rarity: 6))
        }
      }
    }
    if idle || dt <= 0 { return }

    ss.active += dt
    st.stats.active += dt
    st.stats.longest = max(st.stats.longest, ss.active)
    let day = Dates.dayKey(epoch)
    if st.days[day] == nil {
      st.stats.daysWritten += 1
      st.days[day] = 0
      progress("days", 1)
    }
    st.days[day, default: 0] += dt
    st.stats.maxDay = max(st.stats.maxDay, st.days[day] ?? 0)
    if ss.hour < 5 { st.stats.night += dt } else if ss.hour < 9 { st.stats.dawn += dt }
    if ss.wday == 0 || ss.wday == 6 { st.stats.weekend += dt }
    if st.boost > 0 { st.boost = max(0, st.boost - dt) }

    ss.minuteAcc += dt
    while ss.minuteAcc >= 60 {
      ss.minuteAcc -= 60
      addXp(Rules.xpMinute, "time")
    }
    progress("minutes", dt)
    progress("session", 0)

    st.pass.secs += dt * ss.speed
    while st.pass.secs >= Rules.tierSeconds {
      st.pass.secs -= Rules.tierSeconds
      unlockTier()
    }
  }

  // What she does: events from the watcher ---------------------------------------------------

  /// kind: letters, words, idea. n: how many.
  public func event(_ kind: String, _ n: Double = 1) {
    guard n > 0 else { return }
    switch kind {
    case "letters":
      st.stats.letters += n
      addXp(Rules.xpLetter * n, "letters")
    case "words":
      st.stats.words += n
      ss.words += n
      let day = Dates.dayKey(ss.epoch)
      st.dayWords[day, default: 0] += n
      let today = st.dayWords[day] ?? 0
      st.stats.maxWordsDay = max(st.stats.maxWordsDay, today)
      let minute = Int(((ss.now ?? ss.start) / 60).rounded(.down))
      ss.sprint[minute, default: 0] += n
      for k in ss.sprint.keys where k <= minute - Rules.sprintMinutes { ss.sprint[k] = nil }
      st.stats.sprintBest = max(st.stats.sprintBest, sprintWords())
      progress("words", n)
      progress("sprint", 0)
      // A toast at every 250 words in a day.
      let m = Rules.wordsMilestone
      let reached = (today / m).rounded(.down), had = (ss.wordsToast / m).rounded(.down)
      if today >= m && reached > had {
        var w = Notice(.words, text: "\(Int(reached * m)) words today", sub: "Keep going!", icon: "pencil",
                       rarity: today >= 2000 ? 6 : (today >= 1000 ? 5 : 4))
        w.amount = Int(today)
        notice(w)
      }
      ss.wordsToast = today
    case "idea":
      st.stats.ideasUsed += n
      addXp(Rules.xpIdea, "idea")
      progress("ideas", n)
    default: break
    }
  }

  /// Words written in the last fifteen minutes.
  public func sprintWords() -> Double {
    let minute = Int(((ss.now ?? ss.start) / 60).rounded(.down))
    return ss.sprint.filter { $0.key > minute - Rules.sprintMinutes }.values.reduce(0, +)
  }

  // For the window ----------------------------------------------------------------------------

  public func weekSeconds(_ epoch: Int) -> Double {
    let monday = Dates.weekKey(epoch)
    return st.days.filter { let d = Dates.daysBetween(monday, $0.key); return d >= 0 && d < 7 }.values.reduce(0, +)
  }

  public func activeTitle() -> String {
    st.cos.titles.indices.contains(st.profile.title) ? st.cos.titles[st.profile.title].text : ""
  }

  public func activeBanner() -> BannerData? {
    st.cos.banners.indices.contains(st.profile.banner) ? st.cos.banners[st.profile.banner].banner : nil
  }
}
