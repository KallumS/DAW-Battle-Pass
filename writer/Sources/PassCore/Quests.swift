import Foundation

extension Engine {
  static func setPath(_ scope: String) -> WritableKeyPath<GameState, QuestSet> {
    scope == "daily" ? \GameState.daily : \GameState.weekly
  }

  static func makeQuest(_ d: Dice, _ tpl: Rules.QuestTemplate, _ scope: String) -> Quest {
    let spec = (scope == "daily" ? tpl.daily : tpl.weekly) ?? (1, 1, 1)
    let steps = (spec.1 - spec.0) / spec.2
    let target = spec.0 + Int(d.next() * Double(steps + 1)) * spec.2
    let diff = steps > 0 ? Double(target - spec.0) / Double(spec.1 - spec.0) : 0.5
    var q = Quest(kind: tpl.kind, text: tpl.text.replacingOccurrences(of: "%d", with: String(target)),
                  target: Double(target) * tpl.unit, scope: scope, unit: tpl.unit)
    if scope == "daily" {
      q.coins = roundHalf(40 + diff * 50)
      q.xp = roundHalf(80 + diff * 80)
      q.rarity = diff > 0.66 ? 4 : 3
    } else {
      q.coins = roundHalf(250 + diff * 200)
      q.xp = roundHalf(500 + diff * 400)
      q.crate = 4
      q.rarity = diff > 0.66 ? 6 : 5
    }
    return q
  }

  static func questPool(_ scope: String, _ exclude: Set<String>) -> [(Double, Rules.QuestTemplate)] {
    Rules.quests.filter { tpl in
      (scope == "daily" ? tpl.daily != nil : tpl.weekly != nil) && !exclude.contains(tpl.kind)
    }.map { ($0.weight, $0) }
  }

  /// Three daily quests or four weekly, always one for writing time; the
  /// week's also always one for finishing dailies.
  public static func makeQuests(_ d: Dice, _ scope: String) -> [Quest] {
    var list: [Quest] = [makeQuest(d, Rules.questTemplate("minutes")!, scope)]
    var used: Set<String> = ["minutes"]
    if scope == "weekly" {
      list.append(makeQuest(d, Rules.questTemplate("dailies")!, scope))
      used.insert("dailies")
    }
    let want = scope == "daily" ? 3 : 4
    while list.count < want {
      let pool = questPool(scope, used)
      if pool.isEmpty { break }
      let tpl = d.weighted(pool)
      used.insert(tpl.kind)
      list.append(makeQuest(d, tpl, scope))
    }
    return list
  }

  func claimQuestRewards(_ scope: String, _ i: Int, silent: Bool) {
    let kp = Engine.setPath(scope)
    st[keyPath: kp].quests[i].claimed = true
    let q = st[keyPath: kp].quests[i]
    let pct = bonus("quest")
    let coins = addCoins(Double(q.coins) * (1 + pct / 100), found: true)
    let xp = Double(q.xp) * (1 + pct / 100) * (hasPower("scholar") ? 1.5 : 1)
    addXp(xp, "quest")
    if q.crate > 0 { st.inv.crates[q.crate - 1] += 1 }
    if !silent {
      var n = Notice(.claim, text: q.text); n.coins = coins; n.xp = Int(xp); n.crate = q.crate
      notice(n)
    }
  }

  /// New quests when the day or week turns. Finished but unclaimed quests are
  /// claimed for her first: nothing earned is lost to the clock.
  public func refresh(_ epoch: Int) {
    checkSeason(epoch)
    let day = Dates.dayKey(epoch), week = Dates.weekKey(epoch)
    if st.daily.key != day {
      for i in st.daily.quests.indices where st.daily.quests[i].done && !st.daily.quests[i].claimed {
        claimQuestRewards("daily", i, silent: true)
      }
      let had = st.daily.key != ""
      st.daily = QuestSet(key: day, quests: Engine.makeQuests(Dice(seedOf("daily", day, epoch)), "daily"))
      if had { notice(Notice(.toast, text: "New daily quests", sub: "Three fresh quests are waiting", icon: "scroll", rarity: 3)) }
      for k in st.days.keys where Dates.daysBetween(k, day) > 120 { st.days[k] = nil }
      for k in st.dayWords.keys where Dates.daysBetween(k, day) > 120 { st.dayWords[k] = nil }
    }
    if st.weekly.key != week {
      for i in st.weekly.quests.indices where st.weekly.quests[i].done && !st.weekly.quests[i].claimed {
        claimQuestRewards("weekly", i, silent: true)
      }
      let had = st.weekly.key != ""
      st.weekly = QuestSet(key: week, quests: Engine.makeQuests(Dice(seedOf("weekly", week, epoch)), "weekly"))
      if had { notice(Notice(.toast, text: "New weekly quests", sub: "Four big quests for the week", icon: "scroll", rarity: 5)) }
    }
    if st.shop.day != day { makeDeals(day) }
  }

  /// Moves every quest a thing counts towards.
  public func progress(_ kind: String, _ n: Double) {
    for scope in ["daily", "weekly"] {
      let kp = Engine.setPath(scope)
      for i in st[keyPath: kp].quests.indices {
        var q = st[keyPath: kp].quests[i]
        if q.done { continue }
        if q.kind == "session" && kind == "session" {
          q.progress = min(q.target, max(q.progress, ss.active))
        } else if q.kind == "sprint" && kind == "sprint" {
          q.progress = min(q.target, max(q.progress, sprintWords()))
        } else if q.kind == kind && kind != "session" && kind != "sprint" {
          q.progress = min(q.target, q.progress + n)
        } else {
          continue
        }
        let finished = q.progress >= q.target
        if finished {
          q.done = true
          if scope == "daily" { st.stats.dailies += 1 } else { st.stats.weeklies += 1 }
          notice(Notice(.quest, text: q.text, sub: scope, rarity: q.rarity))
        }
        st[keyPath: kp].quests[i] = q
        if finished && scope == "daily" { progress("dailies", 1) }
      }
    }
  }

  /// Claim a finished quest. Claiming the last of a set opens its bonus box.
  @discardableResult
  public func claimQuest(_ scope: String, _ i: Int) -> Bool {
    let kp = Engine.setPath(scope)
    guard st[keyPath: kp].quests.indices.contains(i) else { return false }
    let q = st[keyPath: kp].quests[i]
    if !q.done || q.claimed { return false }
    claimQuestRewards(scope, i, silent: false)
    let all = st[keyPath: kp].quests.allSatisfy { $0.claimed }
    if all && !st[keyPath: kp].bonus {
      st[keyPath: kp].bonus = true
      let r = scope == "daily" ? 3 : 5
      st.inv.crates[r - 1] += 1
      notice(Notice(.toast, text: "All \(scope) quests done!", sub: "\(Rarity.name(r)) Gift Box added to Loot", icon: "gift.fill", rarity: r))
    }
    return true
  }

  public func canReroll(_ scope: String) -> Bool {
    if scope == "daily" && hasPower("fickle") && !st.daily.fickle { return true }
    return (st.inv.tokens["reroll"] ?? 0) > 0
  }

  @discardableResult
  public func reroll(_ scope: String, _ i: Int) -> Bool {
    let kp = Engine.setPath(scope)
    guard st[keyPath: kp].quests.indices.contains(i), !st[keyPath: kp].quests[i].done, canReroll(scope) else { return false }
    if scope == "daily" && hasPower("fickle") && !st.daily.fickle { st.daily.fickle = true }
    else { st.inv.tokens["reroll", default: 0] -= 1 }
    var used = Set(st[keyPath: kp].quests.map { $0.kind })
    var pool = Engine.questPool(scope, used)
    if pool.isEmpty {
      used = ["minutes", "dailies", st[keyPath: kp].quests[i].kind]
      pool = Engine.questPool(scope, used)
    }
    if pool.isEmpty { pool = Engine.questPool(scope, ["minutes", "dailies"]) }
    let q = Engine.makeQuest(ss.rnd, ss.rnd.weighted(pool), scope)
    st[keyPath: kp].quests[i] = q
    notice(Notice(.toast, text: "Quest rerolled", sub: q.text, icon: "dice", rarity: 3))
    return true
  }
}
