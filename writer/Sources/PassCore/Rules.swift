import Foundation

/// Every number the game runs on, in one place.
public enum Rules {
  public static let version = 1
  public static let tierSeconds = 15.0 * 60     // writing time per pass tier
  public static let idleSeconds = 180.0         // no writing for this long and the clock stops
  public static let dayStartHour = 4            // a day (quests, check-in) starts at 4am
  public static let letterXpCap = 30.0          // base XP a minute from typing: 300 letters
  public static let stashMax = 60
  public static let vaultMax = 400
  public static let boostSeconds = 30.0 * 60
  public static let sprintMinutes = 15
  public static let wordsMilestone = 250.0      // a toast every this many words in a day

  /// Base XP, before gear and boosts. A letter is a tenth of an XP: a
  /// thousand words (about 5,500 letters) is about 550 XP, roughly what two
  /// hours at the desk gives on its own.
  public static let xpMinute = 4.0
  public static let xpLetter = 0.1
  public static let xpIdea = 25.0
  public static let xpWind = 30.0

  public static func levelNeed(_ level: Int) -> Double { 200 + 50 * Double(level - 1) }

  /// Apps whose typing counts, out of the box. She can add any app she has
  /// typed in from Settings, or count everywhere.
  public static let writingApps = [
    "com.microsoft.Word", "com.apple.iWork.Pages", "com.literatureandlatte.scrivener3",
    "com.literatureandlatte.Scrivener", "com.ulyssesapp.mac", "pro.writer.mac",
    "net.shinyfrog.bear", "com.apple.Notes", "com.apple.TextEdit", "md.obsidian",
    "com.google.Chrome.app.docs", "abnerworks.Typora", "com.reedsy.studio",
  ]

  // The shop ------------------------------------------------------------------
  //
  // Prices in coins. A focused hour earns roughly 600 coins all told (the Economy test), so a
  // new top is about four or five hours of writing. Passes are permission
  // slips: hers to rename, reprice, add and remove in Settings.

  public static let defaultRewards: [ShopItem] = [
    ShopItem(id: "coffee", kind: "pass", name: "Fancy Coffee Pass", price: 300, icon: "cup.and.saucer.fill",
             desc: "Go and get the fancy coffee. Oat milk, extra shot, whatever you like."),
    ShopItem(id: "treat", kind: "pass", name: "Sweet Treat Pass", price: 450, icon: "birthday.cake",
             desc: "A cake, a pastry or a bar of the good chocolate."),
    ShopItem(id: "pamper", kind: "pass", name: "Pamper Night Pass", price: 700, icon: "bathtub",
             desc: "Face mask, bubble bath, candles, phone in another room."),
    ShopItem(id: "binge", kind: "pass", name: "Binge Pass", price: 900, icon: "tv",
             desc: "Three episodes of something gloriously trashy."),
    ShopItem(id: "book", kind: "pass", name: "New Book Pass", price: 1200, icon: "books.vertical.fill",
             desc: "Buy a book. Writers have to read."),
    ShopItem(id: "lipstick", kind: "pass", name: "New Lipstick Pass", price: 1500, icon: "mouth.fill",
             desc: "One new lipstick, any shade you like."),
    ShopItem(id: "brunch", kind: "pass", name: "Brunch Pass", price: 1800, icon: "fork.knife",
             desc: "Brunch with friends. Bottomless optional."),
    ShopItem(id: "nails", kind: "pass", name: "Nail Appointment Pass", price: 2200, icon: "hand.raised.fill",
             desc: "Book the nails. Pick the colour that matches your best chapter."),
    ShopItem(id: "top", kind: "pass", name: "New Top Pass", price: 2500, icon: "tshirt.fill",
             desc: "A new top, from the shop you've been eyeing."),
    ShopItem(id: "makeup", kind: "pass", name: "Makeup Haul Pass", price: 4000, icon: "paintpalette.fill",
             desc: "A proper makeup haul: three things off the wishlist."),
    ShopItem(id: "dayoff", kind: "pass", name: "Day Off Pass", price: 5000, icon: "sun.max.fill",
             desc: "A whole day off writing, with zero guilt."),
    ShopItem(id: "shoes", kind: "pass", name: "New Shoes Pass", price: 6000, icon: "shoeprints.fill",
             desc: "New shoes. You've walked a long way to get here."),
    ShopItem(id: "dress", kind: "pass", name: "Dream Dress Pass", price: 8000, icon: "sparkles",
             desc: "The dress. You know the one."),
    ShopItem(id: "spree", kind: "pass", name: "Shopping Spree Pass", price: 15000, icon: "bag.fill",
             desc: "A proper shopping trip. You wrote the words; go and buy the outfit."),
  ]

  public static let fixedShop: [ShopItem] = [
    ShopItem(id: "reroll", kind: "token", name: "Quest Reroll", price: 120, icon: "dice",
             desc: "Swap a quest you don't fancy for a new one.", token: "reroll"),
    ShopItem(id: "freeze", kind: "token", name: "Streak Freeze", price: 300, icon: "snowflake",
             desc: "Keeps your check-in streak if you miss a day.", token: "freeze"),
    ShopItem(id: "boost", kind: "token", name: "XP Boost", price: 250, icon: "bolt.fill",
             desc: "Double XP for thirty minutes of writing.", token: "boost"),
    ShopItem(id: "crate4", kind: "crate", name: "Rare Gift Box", price: 450, icon: "gift.fill",
             desc: "Three gifts, one Rare or better.", rarity: 4),
    ShopItem(id: "crate5", kind: "crate", name: "Epic Gift Box", price: 1100, icon: "gift.fill",
             desc: "Three gifts, one Epic or better.", rarity: 5),
  ]

  public static let dealPrice: [Int: Int] = [4: 350, 5: 800, 6: 1800, 7: 4000]

  // Quests --------------------------------------------------------------------

  public struct QuestTemplate {
    public let kind: String
    public let text: String
    public let unit: Double
    public let daily: (Int, Int, Int)?
    public let weekly: (Int, Int, Int)?
    public let weight: Double
  }

  /// daily/weekly: (lowest, highest, step) targets. unit: what one counts in
  /// seconds (minutes quests count seconds and show minutes).
  public static let quests: [QuestTemplate] = [
    QuestTemplate(kind: "minutes", text: "Write for %d minutes", unit: 60, daily: (20, 60, 5), weekly: (180, 420, 30), weight: 1),
    QuestTemplate(kind: "session", text: "Write for %d minutes in one sitting", unit: 60, daily: (30, 60, 15), weekly: (90, 180, 30), weight: 1),
    QuestTemplate(kind: "words", text: "Write %d words", unit: 1, daily: (250, 1000, 50), weekly: (2000, 7000, 500), weight: 3),
    QuestTemplate(kind: "sprint", text: "Write %d words in fifteen minutes", unit: 1, daily: (150, 350, 50), weekly: (300, 600, 50), weight: 2),
    QuestTemplate(kind: "tiers", text: "Unlock %d battle pass tiers", unit: 1, daily: (2, 4, 1), weekly: (12, 24, 4), weight: 1),
    QuestTemplate(kind: "crates", text: "Open %d gift boxes", unit: 1, daily: (1, 2, 1), weekly: (4, 8, 1), weight: 1),
    QuestTemplate(kind: "ideas", text: "Use %d writing prompts", unit: 1, daily: (1, 2, 1), weekly: (3, 6, 1), weight: 1),
    QuestTemplate(kind: "days", text: "Write on %d different days", unit: 1, daily: nil, weekly: (4, 6, 1), weight: 1),
    QuestTemplate(kind: "dailies", text: "Complete %d daily quests", unit: 1, daily: nil, weekly: (8, 15, 1), weight: 1),
    QuestTemplate(kind: "checkins", text: "Check in on %d days", unit: 1, daily: nil, weekly: (4, 6, 1), weight: 1),
  ]

  public static func questTemplate(_ kind: String) -> QuestTemplate? { quests.first { $0.kind == kind } }

  // Check-in: a seven-day calendar; every fourth week's seventh day is Legendary.

  public struct CheckinDay { public let coins: Int; public let xp: Int; public let token: String?; public let crate: Int }
  public static let checkin: [CheckinDay] = [
    CheckinDay(coins: 25, xp: 0, token: nil, crate: 0),
    CheckinDay(coins: 35, xp: 50, token: nil, crate: 0),
    CheckinDay(coins: 0, xp: 0, token: nil, crate: 3),
    CheckinDay(coins: 60, xp: 0, token: nil, crate: 0),
    CheckinDay(coins: 0, xp: 0, token: "reroll", crate: 0),
    CheckinDay(coins: 90, xp: 100, token: nil, crate: 0),
    CheckinDay(coins: 120, xp: 0, token: nil, crate: 5),
  ]
}
