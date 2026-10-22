import Foundation

/// Coins, XP, tokens, gift boxes, what a box holds, and the season.
public enum Loot {
  public struct TokenInfo { public let name, icon, text: String }

  public static let tokens: [String: TokenInfo] = [
    "reroll": TokenInfo(name: "Quest Reroll", icon: "dice", text: "Swap a quest for a new one"),
    "freeze": TokenInfo(name: "Streak Freeze", icon: "snowflake", text: "Saves your check-in streak for a missed day"),
    "boost": TokenInfo(name: "XP Boost", icon: "bolt.fill", text: "Double XP for 30 minutes of writing"),
  ]

  public static func coins(_ d: Dice, _ r: Int) -> Drop {
    let n = Rarity.coins(d, r)
    var x = Drop(type: "coins", rarity: r, name: "Coins", icon: "coin", text: "\(n) coins", sub: "Spend them in the shop")
    x.amount = n
    return x
  }

  public static func xp(_ r: Int) -> Drop {
    let n = Rarity.info(r).xp
    var x = Drop(type: "xp", rarity: r, name: "XP", icon: "star.fill", text: "\(n) XP", sub: "Straight onto your level")
    x.amount = n
    return x
  }

  public static func token(_ d: Dice, _ r: Int, _ id: String? = nil) -> Drop {
    let id = id ?? d.weighted([(5, "reroll"), (2, "freeze"), (3, "boost")])
    let tk = tokens[id]!
    let n = r >= Rarity.mythic ? 3 : (r >= Rarity.legendary ? 2 : 1)
    var x = Drop(type: "token", rarity: max(r, Rarity.uncommon), name: tk.name, icon: tk.icon,
                 text: (n > 1 ? "\(n) x " : "") + tk.name, sub: tk.text)
    x.token = id; x.amount = n
    return x
  }

  public static func crate(_ r: Int) -> Drop {
    let r = max(Rarity.common, r)
    return Drop(type: "crate", rarity: r, name: "Gift Box", icon: "gift.fill",
                text: Rarity.name(r) + " Gift Box", sub: "Open it in Loot")
  }

  static let pools: [String: [(Double, String)]] = [
    "tier":  [(24, "coins"), (34, "idea"), (18, "gear"), (8, "cosmetic"), (9, "token"), (7, "xp")],
    "crate": [(32, "gear"), (30, "idea"), (14, "coins"), (12, "cosmetic"), (8, "token"), (4, "xp")],
    "deal":  [(50, "gear"), (35, "cosmetic"), (15, "idea")],
  ]

  /// A random drop of a rarity, from a pool's weights.
  public static func drop(_ d: Dice, _ r: Int, pool: String = "tier", ilvl: Int = 1, collector: Bool = false) -> Drop {
    let what = d.weighted(pools[pool] ?? pools["tier"]!)
    switch what {
    case "coins": return coins(d, r)
    case "xp": return xp(r)
    case "token": return token(d, r)
    case "gear": return Gear.make(d, r, ilvl: ilvl)
    case "cosmetic": return d.chance(0.5) ? Looks.title(d, r) : Looks.banner(d, r)
    default:
      let kind = Ideas.randomKind(d)
      var rr = r
      if collector && r < Rarity.mythic && d.chance(0.25) { rr = r + 1 }
      return Ideas.make(d, kind, rr)
    }
  }

  /// What a gift box holds: three things, one at least the box's rarity, the
  /// rest at most two steps under it. `extra` items on top.
  public static func crateContents(_ d: Dice, _ r: Int, luck: Double = 0, extra: Int = 0,
                                   ilvl: Int = 1, collector: Bool = false) -> [Drop] {
    var out: [Drop] = []
    for i in 0..<(3 + extra) {
      let rr = i == 0 ? Rarity.roll(d, r, Rarity.mythic, luck: luck)
                      : Rarity.roll(d, max(Rarity.poor, r - 2), Rarity.mythic, luck: luck)
      out.append(drop(d, rr, pool: "crate", ilvl: ilvl, collector: collector))
    }
    return out
  }

  // The season -----------------------------------------------------------------
  //
  // A season is a calendar month, numbered from January 2026, with a name
  // made from its number. Its track has 100 tiers, one every fifteen minutes
  // of writing, every fourth (each hour) a big one; past 100 the bonus tiers
  // go on for ever. A tier's reward is made from the season and the tier
  // alone, so the track can be shown ahead of time.

  public static let seasonTiers = 100

  public static func seasonId(year: Int, month: Int) -> Int { (year - 2026) * 12 + month }

  public static func seasonName(_ id: Int) -> String {
    let d = Dice(seedOf("season", id))
    return d.word(W.seasonAdj) + " " + d.word(W.seasonNoun)
  }

  /// "big" tiers are each hour's; "milestone" every tenth; "legendary" every
  /// twenty-fifth; the hundredth the finale.
  public static func tierKind(_ tier: Int) -> String {
    if tier == seasonTiers { return "finale" }
    if tier % 25 == 0 && tier <= seasonTiers { return "legendary" }
    if tier % 10 == 0 && tier <= seasonTiers { return "milestone" }
    if tier % 4 == 0 { return "big" }
    return "small"
  }

  public static func tierRewards(season: Int, tier: Int, ilvl: Int, collector: Bool = false) -> ([Drop], String) {
    let d = Dice(seedOf("tier", season, tier))
    let kind = tierKind(tier)
    var out: [Drop] = []
    switch kind {
    case "small":
      out.append(coins(d, Rarity.roll(d, Rarity.poor, Rarity.uncommon)))
      out.append(drop(d, Rarity.roll(d, Rarity.poor, Rarity.mythic), pool: "tier", ilvl: ilvl, collector: collector))
    case "big":
      out.append(coins(d, Rarity.rare))
      out.append(crate(Rarity.roll(d, Rarity.rare, Rarity.mythic)))
      out.append(drop(d, Rarity.roll(d, Rarity.uncommon, Rarity.mythic), pool: "crate", ilvl: ilvl, collector: collector))
    case "milestone":
      out.append(coins(d, Rarity.epic))
      out.append(Gear.make(d, Rarity.roll(d, Rarity.epic, Rarity.mythic), ilvl: ilvl))
      out.append(drop(d, Rarity.roll(d, Rarity.rare, Rarity.mythic), pool: "crate", ilvl: ilvl, collector: collector))
    case "legendary":
      out.append(coins(d, Rarity.legendary))
      out.append(Gear.make(d, Rarity.legendary, ilvl: ilvl))
      out.append(crate(Rarity.epic))
    default:
      out.append(coins(d, Rarity.mythic))
      out.append(Gear.make(d, Rarity.mythic, ilvl: ilvl))
      var t = Looks.title(d, Rarity.mythic)
      t.text = "Champion of " + seasonName(season)
      out.append(t)
      out.append(Looks.banner(d, Rarity.mythic))
    }
    return (out, kind)
  }

  /// What the track shows for a tier before it is reached: its best reward.
  public static func tierHeadline(season: Int, tier: Int, ilvl: Int) -> (Drop, String) {
    let (list, kind) = tierRewards(season: season, tier: tier, ilvl: ilvl)
    var best = list[0]
    for d in list where d.rarity > best.rarity || (d.rarity == best.rarity && best.type == "coins") { best = d }
    return (best, kind)
  }
}
