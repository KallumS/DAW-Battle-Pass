import Foundation

/// The wardrobe, in Diablo's manner: a base for its slot; an implicit stat
/// every item of that slot carries; affixes, more the rarer it is, each
/// rolled within a range and naming the item; and on Legendary and Mythic
/// pieces a power that changes a rule rather than a number. Stats only ever
/// reward writing - none of them shortens the fifteen minutes a tier takes.
public struct Slot {
  public let id: String
  public let name: String
  public let icon: String
  public let implicit: String
  public let bases: [String]
}

public struct Affix {
  public let id: String
  public let lo: Double
  public let hi: Double
  public let fmt: String     // %d is the value
  public let prefix: String
  public let suffix: String
}

public struct Power {
  public let id: String
  public let name: String
  public let text: String
}

public enum Gear {
  public static let slots: [Slot] = [
    Slot(id: "pen", name: "Pen", icon: "pencil", implicit: "typing",
         bases: ["Chewed Biro", "Gel Pen", "Rollerball", "Fountain Pen", "Gold-Nib Fountain Pen", "Antique Quill"]),
    Slot(id: "phones", name: "Headphones", icon: "headphones", implicit: "coins",
         bases: ["Tangled Earbuds", "Wired Earphones", "Wireless Earbuds", "Over-Ears", "Noise-Cancelling Headphones", "Studio Headphones"]),
    Slot(id: "hat", name: "Hat", icon: "graduationcap", implicit: "luck",
         bases: ["Bobble Hat", "Beanie", "Baseball Cap", "Bucket Hat", "Flat Cap", "Vintage Fedora"]),
    Slot(id: "jewel", name: "Accessory", icon: "watch.analog", implicit: "quest",
         bases: ["Hair Tie", "Friendship Bracelet", "Silver Ring", "Leather Watch", "Signet Ring", "Vintage Watch"]),
    Slot(id: "outfit", name: "Outfit", icon: "tshirt", implicit: "xp",
         bases: ["Old Band T-Shirt", "Comfy Hoodie", "Flannel Shirt", "Denim Jacket", "Leather Jacket", "Shearling Coat"]),
    Slot(id: "shoes", name: "Shoes", icon: "figure.walk", implicit: "endure",
         bases: ["Slippers", "Canvas Sneakers", "Trainers", "Chelsea Boots", "Combat Boots", "Limited-Edition Trainers"]),
    Slot(id: "bag", name: "Bag", icon: "backpack", implicit: "crate",
         bases: ["Tote Bag", "Drawstring Bag", "Backpack", "Messenger Bag", "Leather Satchel", "Waxed Canvas Rucksack"]),
    Slot(id: "charm", name: "Desk Charm", icon: "cup.and.saucer", implicit: "checkin",
         bases: ["Mug of Tea", "Scented Candle", "Succulent", "Cat Figurine", "Snow Globe", "Lucky Crystal"]),
  ]

  public static func slot(_ id: String) -> Slot? { slots.first { $0.id == id } }

  public static let affixes: [Affix] = [
    Affix(id: "xp",      lo: 2,  hi: 6,  fmt: "+%d%% XP from everything",             prefix: "Studious",  suffix: "of Learning"),
    Affix(id: "coins",   lo: 3,  hi: 8,  fmt: "+%d%% coins found",                    prefix: "Gilded",    suffix: "of Riches"),
    Affix(id: "luck",    lo: 3,  hi: 10, fmt: "+%d%% better loot (magic find)",        prefix: "Lucky",     suffix: "of Fortune"),
    Affix(id: "quest",   lo: 4,  hi: 10, fmt: "+%d%% quest rewards",                  prefix: "Questing",  suffix: "of the Seeker"),
    Affix(id: "typing",  lo: 8,  hi: 20, fmt: "+%d%% XP from typing",                 prefix: "Eloquent",  suffix: "of the Wordsmith"),
    Affix(id: "ideas",   lo: 10, hi: 25, fmt: "+%d%% XP from using prompts",          prefix: "Inspired",  suffix: "of the Muse"),
    Affix(id: "endure",  lo: 5,  hi: 15, fmt: "+%d%% XP after an hour of writing",    prefix: "Tireless",  suffix: "of Endurance"),
    Affix(id: "night",   lo: 8,  hi: 25, fmt: "+%d%% XP between midnight and 5am",    prefix: "Moonlit",   suffix: "of the Night Owl"),
    Affix(id: "dawn",    lo: 8,  hi: 25, fmt: "+%d%% XP between 5am and 9am",         prefix: "Dawnlit",   suffix: "of the Early Bird"),
    Affix(id: "weekend", lo: 8,  hi: 20, fmt: "+%d%% XP at weekends",                 prefix: "Lazy-Sunday", suffix: "of the Weekend"),
    Affix(id: "grace",   lo: 15, hi: 45, fmt: "+%d seconds before you count as idle", prefix: "Patient",   suffix: "of Focus"),
    Affix(id: "checkin", lo: 10, hi: 30, fmt: "+%d%% check-in rewards",               prefix: "Loyal",     suffix: "of Devotion"),
    Affix(id: "crate",   lo: 5,  hi: 15, fmt: "+%d%% chance of an extra gift in boxes", prefix: "Generous", suffix: "of Plenty"),
  ]

  public static func affix(_ id: String) -> Affix? { affixes.first { $0.id == id } }

  public static let powers: [Power] = [
    Power(id: "golden_hour", name: "Golden Hour",      text: "Hour rewards hold one extra gift."),
    Power(id: "hoarder",     name: "Bottomless Bag",   text: "Every gift box holds one extra gift."),
    Power(id: "midas",       name: "Midas Touch",      text: "A 10% chance to double any coins you find."),
    Power(id: "collector",   name: "The Collector",    text: "Prompts you find have a 25% chance to be one rarity higher."),
    Power(id: "second_wind", name: "Second Wind",      text: "Coming back from a break gives 30 XP (once every 30 minutes)."),
    Power(id: "fickle",      name: "Fickle Muse",      text: "A free quest reroll every day."),
    Power(id: "deep_focus",  name: "Deep Focus",       text: "Three extra minutes before you count as idle."),
    Power(id: "overclock",   name: "Double Espresso",  text: "XP Boosts last twice as long."),
    Power(id: "marathon",    name: "Marathon",         text: "+50% XP after two hours of writing."),
    Power(id: "scholar",     name: "Teacher's Pet",    text: "Quests give 50% more XP."),
  ]

  public static func power(_ id: String) -> Power? { powers.first { $0.id == id } }

  static let junk = ["Smudged", "Chipped", "Faded", "Bobbly", "Scuffed", "Snagged", "Leaky", "Hand-me-down"]
  static let affixCount = [0, 0, 1, 2, 3, 3, 4]
  static let epicA = ["Storm", "Iron", "Moon", "Rust", "Star", "Thunder", "Midnight", "Ghost", "Ember",
                      "Neon", "Copper", "Wild", "Shadow", "Rebel", "Stone"]
  static let epicB = ["Whisper", "Muse", "Anthem", "Ballad", "Riot", "Secret", "Howl", "Spell",
                      "Echo", "Riddle", "Engine", "Verse", "Signal", "Outlaw"]

  static func value(_ d: Dice, _ a: Affix, _ r: Int, _ ilvl: Int, _ top: Bool) -> Int {
    let roll = top ? 0.5 + 0.5 * d.next() : d.next()
    let base: Double = a.lo + (a.hi - a.lo) * roll
    let levelMult: Double = 1 + Double(min(ilvl, 100)) / 200
    let v: Double = base * Rarity.info(r).mult * levelMult
    return max(1, roundHalf(v))
  }

  public static func make(_ d: Dice, _ r: Int, ilvl: Int, slot slotId: String? = nil) -> Drop {
    let ilvl = max(1, ilvl)
    let slot = slotId.flatMap { Gear.slot($0) } ?? d.pick(slots)
    let n = Double(slot.bases.count)
    let pos: Double = Double(r - 1) * n / 7 + d.next() * 1.5
    let bi = min(slot.bases.count, 1 + Int(pos))
    let base = slot.bases[bi - 1]
    let imp = affix(slot.implicit)!
    let rolled: Int = value(d, imp, r, ilvl, r == Rarity.mythic)
    var implicitValue = max(1, roundHalf(Double(rolled) * 0.5))
    if r == Rarity.poor { implicitValue = 1 }
    let pool = d.shuffled(affixes.filter { $0.id != slot.implicit })
    var stats: [Stat] = []
    for i in 0..<affixCount[r - 1] {
      stats.append(Stat(id: pool[i].id, value: value(d, pool[i], r, ilvl, r == Rarity.mythic)))
    }
    var item = Drop(type: "gear", rarity: r, name: "", icon: slot.icon, text: "")
    item.slot = slot.id; item.base = base; item.ilvl = ilvl
    item.implicit = Stat(id: imp.id, value: implicitValue)
    item.affixes = stats
    if r >= Rarity.legendary { item.power = d.pick(powers).id }
    // The name, the way Diablo builds one.
    var name: String
    switch r {
    case Rarity.poor: name = d.word(junk) + " " + base
    case Rarity.common: name = base
    case Rarity.uncommon:
      let a = affix(stats[0].id)!
      name = d.chance(0.5) ? a.prefix + " " + base : base + " " + a.suffix
    case Rarity.rare: name = affix(stats[0].id)!.prefix + " " + base + " " + affix(stats[1].id)!.suffix
    case Rarity.epic: name = d.word(epicA) + " " + d.word(epicB)
    case Rarity.legendary: name = d.word(W.heroines) + "'s " + base
    default: name = d.word(W.heroines) + ", " + d.word(W.epithets)
    }
    item.name = name
    item.text = name
    let baseNote = r >= Rarity.epic ? " (\(base))" : ""
    item.sub = "\(Rarity.name(r)) \(slot.name)\(baseNote)  /  item level \(ilvl)"
    return item
  }

  /// Every stat an item gives, implicit included.
  public static func stats(_ item: Drop) -> [String: Int] {
    var s: [String: Int] = [:]
    if let i = item.implicit { s[i.id, default: 0] += i.value }
    for a in item.affixes ?? [] { s[a.id, default: 0] += a.value }
    return s
  }

  public static func statLine(_ id: String, _ value: Int) -> String {
    guard let a = affix(id) else { return "\(id) \(value)" }
    return a.fmt.replacingOccurrences(of: "%d", with: String(value)).replacingOccurrences(of: "%%", with: "%")
  }

  /// A single number to compare gear by: each stat against its own range.
  public static func score(_ item: Drop) -> Int {
    var score = 0.0
    for (id, v) in stats(item) {
      guard let a = affix(id) else { continue }
      score += Double(v) / ((a.lo + a.hi) / 2) * 10
    }
    if item.power != nil { score += 25 }
    return roundHalf(score)
  }

  public static func sellValue(_ item: Drop) -> Int {
    let sell = Double(Rarity.info(item.rarity).sell)
    let level = Double(item.ilvl ?? 1)
    return roundHalf(sell * (1 + level / 50))
  }
}

// Cosmetics ---------------------------------------------------------------------

public enum Looks {
  public static let shapes = ["circle", "shield", "diamond", "hexagon", "star"]
  public static let patterns = ["plain", "split", "stripes", "chevron", "rings", "rays", "dots"]
  public static let glyphs = ["pencil", "heart.fill", "star.fill", "crown.fill", "flame.fill",
                              "moon.fill", "sparkles", "book.fill"]

  public static func title(_ d: Dice, _ r: Int) -> Drop {
    let t: String
    if r <= Rarity.common { t = d.word(W.titleRoles) }
    else if r <= Rarity.rare { t = d.word(W.titleAdjs) + " " + d.word(W.titleRoles) }
    else if r <= Rarity.legendary { t = d.word(W.titleAdjs) + " " + d.word(W.titleRoles) + " of " + d.word(W.titleOf) }
    else { t = "\(d.word(W.heroines)) the \(d.word(W.titleAdjs)), \(d.word(W.titleRoles)) of \(d.word(W.titleOf))" }
    return Drop(type: "title", rarity: r, name: "Title", icon: "crown", text: t, sub: "Wear it under your name")
  }

  public static func banner(_ d: Dice, _ r: Int) -> Drop {
    let maxPattern = min(patterns.count, 1 + r)
    var b = BannerData(shape: d.pick(shapes), pattern: patterns[d.between(1, maxPattern) - 1],
                       h1: d.next(), h2: d.next(), glyph: r >= Rarity.rare ? d.pick(glyphs) : nil,
                       glow: r >= Rarity.legendary, spin: r >= Rarity.mythic, sat: nil)
    if r == Rarity.poor { b.pattern = "plain"; b.sat = 0.1 }
    var drop = Drop(type: "banner", rarity: r, name: "Banner", icon: "flag",
                    text: d.word(W.colourWords) + " " + d.word(W.bannerThings), sub: "A banner for your profile")
    drop.banner = b
    return drop
  }
}
