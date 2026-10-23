import Foundation

/// Achievements: series of tiers. The last tier of a series also gives its
/// title to wear.
public struct Achievement {
  public let id: String
  public let name: String
  public let fmt: String        // %@ is the goal
  public let title: String
  public let goals: [Double]
  public let value: (GameState) -> Double
}

public enum Achievements {
  static func h(_ s: Double) -> Double { s / 3600 }

  public static let all: [Achievement] = [
    Achievement(id: "hours", name: "Time at the Desk", fmt: "Write for %@ hours", title: "Desk Legend",
                goals: [1, 5, 10, 25, 50, 100, 250, 500, 1000]) { Achievements.h($0.stats.active) },
    Achievement(id: "session", name: "In the Zone", fmt: "Write for %@ hours in one sitting", title: "The Unbreakable",
                goals: [1, 2, 3, 4, 6]) { Achievements.h($0.stats.longest) },
    Achievement(id: "day", name: "Full Shift", fmt: "Write for %@ hours in one day", title: "Overtime Hero",
                goals: [2, 4, 6, 8]) { Achievements.h($0.stats.maxDay) },
    Achievement(id: "words", name: "Word Count", fmt: "Write %@ words", title: "The Prolific",
                goals: [1000, 10000, 50000, 100000, 250000, 500000, 1000000]) { $0.stats.words },
    Achievement(id: "wordday", name: "Big Day", fmt: "Write %@ words in one day", title: "Word Machine",
                goals: [500, 1000, 2000, 3000, 5000]) { $0.stats.maxWordsDay },
    Achievement(id: "sprint", name: "Sprinter", fmt: "Write %@ words in fifteen minutes", title: "Speed Demon",
                goals: [100, 250, 400, 600, 800]) { $0.stats.sprintBest },
    Achievement(id: "letters", name: "Keyboard Warrior", fmt: "Type %@ letters", title: "Keyboard Crusher",
                goals: [10000, 100000, 1000000, 5000000]) { $0.stats.letters },
    Achievement(id: "days", name: "Showing Up", fmt: "Write on %@ different days", title: "Creature of Habit",
                goals: [3, 10, 30, 100, 365]) { $0.stats.daysWritten },
    Achievement(id: "level", name: "Level Up", fmt: "Reach level %@", title: "The Ascended",
                goals: [5, 10, 20, 30, 50, 75, 100]) { Double($0.level) },
    Achievement(id: "tiers", name: "Battle Pass", fmt: "Unlock %@ battle pass tiers", title: "Tier Crusher",
                goals: [1, 10, 50, 100, 250, 500, 1000]) { $0.stats.tiers },
    Achievement(id: "seasons", name: "Season Champion", fmt: "Finish %@ season passes", title: "Champion of Seasons",
                goals: [1, 3, 6, 12]) { $0.stats.seasonsDone },
    Achievement(id: "streak", name: "On a Roll", fmt: "A check-in streak of %@ days", title: "The Devoted",
                goals: [3, 7, 14, 30, 60, 100, 365]) { Double($0.checkin.best) },
    Achievement(id: "loyal", name: "Regular", fmt: "Check in on %@ days in total", title: "Part of the Furniture",
                goals: [7, 30, 100, 365, 1000]) { Double($0.checkin.total) },
    Achievement(id: "quests", name: "Quest Giver's Favourite", fmt: "Complete %@ quests", title: "The Questor",
                goals: [1, 10, 50, 200, 1000]) { $0.stats.dailies + $0.stats.weeklies },
    Achievement(id: "crates", name: "Unwrapped", fmt: "Open %@ gift boxes", title: "Box Goblin",
                goals: [1, 10, 50, 250, 1000]) { $0.stats.crates },
    Achievement(id: "coins", name: "Coin Collector", fmt: "Earn %@ coins", title: "The Tycoon",
                goals: [1000, 10000, 50000, 250000, 1000000]) { $0.stats.coinsEarned },
    Achievement(id: "treats", name: "Treat Yourself", fmt: "Redeem %@ passes", title: "Professional Relaxer",
                goals: [1, 10, 50, 100]) { $0.stats.redeemed },
    Achievement(id: "ideas", name: "Muse Magnet", fmt: "Collect %@ writing prompts", title: "Keeper of Ideas",
                goals: [10, 100, 500, 2000]) { $0.stats.ideas },
    Achievement(id: "used", name: "From Prompt to Page", fmt: "Use %@ prompts in your writing", title: "The Finisher",
                goals: [1, 10, 50, 200]) { $0.stats.ideasUsed },
    Achievement(id: "legend", name: "Legendary Luck", fmt: "Find %@ Legendary or better things", title: "Touched by Fortune",
                goals: [1, 10, 50, 200]) { $0.stats.legendaries },
    Achievement(id: "relics", name: "Literary Relics", fmt: "Find %@ relics from famous books", title: "Keeper of Relics",
                goals: [1, 5, 15, 40]) { $0.stats.relics },
    Achievement(id: "mythic", name: "Myth Maker", fmt: "Find %@ Mythic things", title: "The Mythic",
                goals: [1, 5, 25]) { $0.stats.mythics },
    Achievement(id: "gear", name: "Kitted Out", fmt: "Reach a style score of %@", title: "Style Icon",
                goals: [50, 150, 300, 500, 800]) { Double(Engine.gearScore($0)) },
    Achievement(id: "night", name: "Night Owl", fmt: "Write for %@ hours between midnight and 5am", title: "Creature of the Night",
                goals: [1, 10, 50]) { Achievements.h($0.stats.night) },
    Achievement(id: "dawn", name: "Early Bird", fmt: "Write for %@ hours between 5am and 9am", title: "Dawn Patrol",
                goals: [1, 10, 50]) { Achievements.h($0.stats.dawn) },
    Achievement(id: "weekend", name: "Weekend Writer", fmt: "Write for %@ hours at weekends", title: "Weekend Warrior",
                goals: [5, 25, 100]) { Achievements.h($0.stats.weekend) },
    Achievement(id: "shopper", name: "Big Spender", fmt: "Spend %@ coins", title: "Patron of the Shops",
                goals: [500, 5000, 25000, 100000]) { $0.stats.coinsSpent },
  ]

  public static func totals(_ st: GameState) -> (have: Int, all: Int) {
    var have = 0, total = 0
    for a in all { total += a.goals.count; have += st.ach[a.id] ?? 0 }
    return (have, total)
  }

  public static func roman(_ n: Int) -> String {
    let r = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
    return (1...r.count).contains(n) ? r[n - 1] : String(n)
  }

  /// 1000000 as "1,000,000".
  public static func fmtGoal(_ g: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_GB")
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: g)) ?? String(Int(g))
  }

  public static func text(_ a: Achievement, _ tier: Int) -> String {
    let goal = a.goals[max(0, min(a.goals.count - 1, tier - 1))]
    return agree(a.fmt.replacingOccurrences(of: "%@", with: fmtGoal(goal)), goal)
  }
}

extension Engine {
  public func checkAchievements() {
    for a in Achievements.all {
      var have = st.ach[a.id] ?? 0
      let v = a.value(st)
      while have < a.goals.count && v >= a.goals[have] {
        have += 1
        st.ach[a.id] = have
        let coins = 40 * have, xp = 80 * have
        addCoins(Double(coins), found: false)
        addXp(Double(xp), "ach")
        let final = have == a.goals.count
        if final { st.cos.titles.append(Cosmetic(text: a.title, rarity: 6)) }
        var n = Notice(.ach, text: Achievements.text(a, have), rarity: final ? 6 : 5)
        n.name = a.name + " " + Achievements.roman(have)
        n.coins = coins; n.xp = xp; n.tier = have; n.final = final
        n.title = final ? a.title : nil
        notice(n)
      }
    }
  }
}
