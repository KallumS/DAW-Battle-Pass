import Foundation

/// The ladder of loot games: Diablo's grey Poor at the bottom, WoW's and
/// Fortnite's Common to Legendary, and Mythic on top. See COLOUR.md.
public struct RarityInfo {
  public let name: String
  public let colour: UInt32       // 0xRRGGBB
  public let weight: Double
  public let coins: ClosedRange<Int>
  public let xp: Int
  public let sell: Int
  public let mult: Double
}

public enum Rarity {
  public static let poor = 1, common = 2, uncommon = 3, rare = 4, epic = 5, legendary = 6, mythic = 7

  public static let all: [RarityInfo] = [
    RarityInfo(name: "Poor",      colour: 0xB3AABB, weight: 12,  coins: 4...9,     xp: 15,   sell: 1,   mult: 0.6),
    RarityInfo(name: "Common",    colour: 0xE6E1EA, weight: 40,  coins: 10...20,   xp: 30,   sell: 3,   mult: 0.8),
    RarityInfo(name: "Uncommon",  colour: 0x3FCF6E, weight: 26,  coins: 20...40,   xp: 60,   sell: 8,   mult: 1.0),
    RarityInfo(name: "Rare",      colour: 0x3D8EFF, weight: 14,  coins: 40...80,   xp: 120,  sell: 20,  mult: 1.15),
    RarityInfo(name: "Epic",      colour: 0xA45CFF, weight: 5.5, coins: 90...150,  xp: 250,  sell: 50,  mult: 1.3),
    RarityInfo(name: "Legendary", colour: 0xFF8A1C, weight: 2,   coins: 200...300, xp: 500,  sell: 120, mult: 1.5),
    RarityInfo(name: "Mythic",    colour: 0xFF3FA4, weight: 0.5, coins: 500...750, xp: 1000, sell: 300, mult: 1.75),
  ]

  public static func info(_ r: Int) -> RarityInfo { all[max(1, min(7, r)) - 1] }
  public static func name(_ r: Int) -> String { info(r).name }

  /// Luck (magic find, in percent) makes each step up the ladder that much
  /// likelier, compounding: at +50% luck an Epic is 1.5^3 times as likely.
  public static func roll(_ d: Dice, _ minR: Int = 1, _ maxR: Int = 7, luck: Double = 0) -> Int {
    let f = 1 + max(0, luck) / 100
    var list: [(Double, Int)] = []
    for i in minR...maxR {
      var w = all[i - 1].weight
      if i >= uncommon { w *= pow(f, Double(i - common)) }
      if i == poor { w /= f }
      list.append((w, i))
    }
    return d.weighted(list)
  }

  public static func coins(_ d: Dice, _ r: Int) -> Int {
    let c = info(r).coins
    return d.between(c.lowerBound, c.upperBound)
  }
}
