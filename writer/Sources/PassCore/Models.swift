import Foundation

/// One stat on a piece of gear: what it boosts and by how much.
public struct Stat: Codable, Equatable {
  public var id: String
  public var value: Int
}

/// How a banner is drawn.
public struct BannerData: Codable, Equatable {
  public var shape: String
  public var pattern: String
  public var h1: Double
  public var h2: Double
  public var glyph: String?
  public var glow: Bool
  public var spin: Bool
  public var sat: Double?
  public init(shape: String, pattern: String, h1: Double, h2: Double, glyph: String?, glow: Bool, spin: Bool, sat: Double?) {
    self.shape = shape; self.pattern = pattern; self.h1 = h1; self.h2 = h2
    self.glyph = glyph; self.glow = glow; self.spin = spin; self.sat = sat
  }
}

/// Anything handed out: coins, XP, a token, a gift box, gear, a prompt, a
/// title, a banner. One shape with optional parts, the way the Lua tables
/// were, so a crate can hold a mix and the save file stays readable.
public struct Drop: Codable, Equatable {
  public var type: String        // coins, xp, token, crate, gear, idea, title, banner
  public var rarity: Int
  public var name: String
  public var icon: String
  public var text: String
  public var sub: String = ""
  public var amount: Int? = nil
  public var token: String? = nil
  public var kind: String? = nil       // a prompt's kind
  public var uid: Int? = nil
  public var t: Int? = nil             // when it was found (epoch)
  public var fav: Bool? = nil
  public var used: Bool? = nil
  public var slot: String? = nil       // gear
  public var base: String? = nil
  public var ilvl: Int? = nil
  public var implicit: Stat? = nil
  public var affixes: [Stat]? = nil
  public var power: String? = nil
  public var banner: BannerData? = nil
  public var flavour: String? = nil     // a relic's line (0025)
  public var after: String? = nil       // whose book a relic comes from
}

public struct Profile: Codable, Equatable {
  public var name = "Writer"
  public var title = -1        // index into cos.titles, -1 for none
  public var banner = -1
}

public struct PassState: Codable, Equatable {
  public var season = 0
  public var tier = 0
  public var secs = 0.0
}

public struct Stats: Codable, Equatable {
  public var active = 0.0, longest = 0.0, sessions = 0.0, maxDay = 0.0
  public var letters = 0.0, words = 0.0, maxWordsDay = 0.0, sprintBest = 0.0, daysWritten = 0.0
  public var crates = 0.0, dailies = 0.0, weeklies = 0.0, tiers = 0.0, seasonsDone = 0.0
  public var coinsEarned = 0.0, coinsSpent = 0.0, purchases = 0.0, redeemed = 0.0
  public var ideas = 0.0, ideasUsed = 0.0, legendaries = 0.0, mythics = 0.0, boosts = 0.0
  public var night = 0.0, dawn = 0.0, weekend = 0.0, xpTotal = 0.0, relics = 0.0
}

public struct Quest: Codable, Equatable {
  public var kind: String
  public var text: String
  public var target: Double
  public var progress = 0.0
  public var done = false
  public var claimed = false
  public var scope: String
  public var unit = 1.0         // 60 for quests counted in seconds, shown in minutes
  public var coins = 0
  public var xp = 0
  public var crate = 0          // a gift box's rarity, 0 for none
  public var rarity = 3
}

public struct QuestSet: Codable, Equatable {
  public var key = ""
  public var quests: [Quest] = []
  public var bonus = false
  public var fickle = false
}

public struct Checkin: Codable, Equatable {
  public var last = ""
  public var streak = 0
  public var best = 0
  public var total = 0
}

public struct Inventory: Codable, Equatable {
  public var passes: [String: Int] = [:]
  public var tokens: [String: Int] = ["reroll": 1, "freeze": 0, "boost": 0]
  public var crates: [Int] = [0, 0, 0, 0, 0, 0, 0]   // by rarity, Poor first
}

public struct GearState: Codable, Equatable {
  public var stash: [Drop] = []
  public var equipped: [String: Drop] = [:]
}

public struct Cosmetic: Codable, Equatable {
  public var text: String
  public var rarity: Int
  public var banner: BannerData? = nil
}

public struct Cosmetics: Codable, Equatable {
  public var titles: [Cosmetic] = []
  public var banners: [Cosmetic] = []
}

public struct LogEntry: Codable, Equatable {
  public var id: String
  public var name: String
  public var t: Int
  public init(id: String, name: String, t: Int) { self.id = id; self.name = name; self.t = t }
}

public struct Deal: Codable, Equatable {
  public var drop: Drop
  public var price: Int
  public var bought = false
}

public struct ShopState: Codable, Equatable {
  public var day = ""
  public var deals: [Deal] = []
}

/// Something in the shop. Passes are permission slips - hers to rename,
/// reprice, add and remove in Settings; tokens and gift boxes are the game's.
public struct ShopItem: Codable, Equatable, Identifiable {
  public var id: String
  public var kind: String        // pass, token, crate
  public var name: String
  public var price: Int
  public var icon: String
  public var desc: String
  public var token: String? = nil
  public var rarity: Int? = nil
  public init(id: String, kind: String, name: String, price: Int, icon: String, desc: String,
              token: String? = nil, rarity: Int? = nil) {
    self.id = id; self.kind = kind; self.name = name; self.price = price; self.icon = icon
    self.desc = desc; self.token = token; self.rarity = rarity
  }
}

/// An app she has typed in lately, so Settings can offer to count it.
public struct SeenApp: Codable, Equatable {
  public var name: String
  public var letters = 0.0
  public var last = 0
  public init(name: String, letters: Double = 0, last: Int = 0) { self.name = name; self.letters = letters; self.last = last }
}

public struct Settings: Codable, Equatable {
  public var idle = Rules.idleSeconds
  public var welcome = false
  public var autostart = false
  public var sound = true
  public var everywhere = false              // count typing in every app
  public var apps: [String] = Rules.writingApps
  public var seen: [String: SeenApp] = [:]
}

/// Everything saved: all she owns and has done.
public struct GameState: Codable, Equatable {
  public var version = Rules.version
  public var created = 0
  public var profile = Profile()
  public var coins = 0
  public var level = 1
  public var xp = 0.0
  public var boost = 0.0
  public var nextId = 1
  public var pass = PassState()
  public var seasons: [String: Int] = [:]
  public var stats = Stats()
  public var days: [String: Double] = [:]        // active seconds by day
  public var dayWords: [String: Double] = [:]    // words by day
  public var daily = QuestSet()
  public var weekly = QuestSet()
  public var checkin = Checkin()
  public var inv = Inventory()
  public var gear = GearState()
  public var vault: [Drop] = []
  public var cos = Cosmetics()
  public var ach: [String: Int] = [:]
  public var log: [LogEntry] = []
  public var recent: [Drop] = []
  public var shop = ShopState()
  public var rewards: [ShopItem] = Rules.defaultRewards
  public var settings = Settings()

  public init(epoch: Int = 0) { created = epoch }
}

/// What a check-in gave.
public struct CheckinResult: Equatable {
  public var day = 1
  public var streak = 1
  public var freezes = 0
  public var broke = false
  public var coins = 0
  public var xp = 0
  public var token: String? = nil
  public var crate = 0
  public init(day: Int = 1, streak: Int = 1, freezes: Int = 0, broke: Bool = false) {
    self.day = day; self.streak = streak; self.freezes = freezes; self.broke = broke
  }
}

/// What just happened, for the window to celebrate. The window is the only
/// reader (Model.handleNotices).
public struct Notice {
  public enum Kind: String {
    case tier, crate, level, checkin, redeem, season                // the stage
    case quest, ach, toast, purchase, idle, active, equip, words    // toasts
    case claim, coins                                               // flying coins
  }
  public var kind: Kind
  public var drops: [Drop] = []
  public var rarity = 0
  public var level = 0
  public var crate = 0
  public var tier = 0
  public var tierKind = ""
  public var season = 0
  public var text = ""
  public var sub = ""
  public var icon = ""
  public var name = ""
  public var id = ""
  public var coins = 0
  public var xp = 0
  public var amount = 0
  public var price = 0
  public var final = false
  public var title: String? = nil
  public var checkin: CheckinResult? = nil

  public init(_ kind: Kind, text: String = "", sub: String = "", icon: String = "", rarity: Int = 0) {
    self.kind = kind; self.text = text; self.sub = sub; self.icon = icon; self.rarity = rarity
  }
}

/// Signals from the watcher, each tick.
public struct Signals {
  public var input: Bool          // she did something in a writing app
  public init(input: Bool) { self.input = input }
}

/// What lives only while the app runs.
public struct Session {
  public var start: Double
  public var active = 0.0
  public var idle = false
  public var lastInput: Double
  public var lastWind = -1e9
  public var minuteAcc = 0.0
  public var xpWinStart: Double
  public var xpWinAmount = 0.0
  public var hour: Int
  public var wday: Int            // 0 is Sunday
  public var notices: [Notice] = []
  public var rnd: Dice
  public var now: Double? = nil
  public var epoch = 0
  public var xpGained = 0.0
  public var words = 0.0
  public var sprint: [Int: Double] = [:]    // words by wall-clock minute, the last fifteen
  public var wordsToast = 0.0               // words today at the last milestone
  public var speed = 1.0                    // tests only
}
