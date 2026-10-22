import Foundation

extension Engine {
  // Daily check-in -------------------------------------------------------------------

  public func checkinAvailable(_ epoch: Int) -> Bool { st.checkin.last != Dates.dayKey(epoch) }

  /// The day of the cycle the next check-in lands on (1-7), what the streak
  /// would become, and how many freezes it would use.
  public func checkinPreview(_ epoch: Int) -> (day: Int, streak: Int, freezes: Int) {
    let today = Dates.dayKey(epoch)
    let c = st.checkin
    if c.last == today { return ((c.streak - 1) % 7 + 1, c.streak, 0) }
    let gap = Dates.daysBetween(c.last, today)
    var streak = 1, freezes = 0
    if c.last != "" && gap == 1 { streak = c.streak + 1 }
    else if c.last != "" && gap > 1 && gap - 1 <= (st.inv.tokens["freeze"] ?? 0) {
      streak = c.streak + 1; freezes = gap - 1
    }
    return ((streak - 1) % 7 + 1, streak, freezes)
  }

  @discardableResult
  public func checkin(_ epoch: Int) -> CheckinResult? {
    guard checkinAvailable(epoch) else { return nil }
    let (day, streak, freezes) = checkinPreview(epoch)
    let broke = st.checkin.last != "" && streak == 1 && st.checkin.streak > 0
    if freezes > 0 { st.inv.tokens["freeze", default: 0] -= freezes }
    st.checkin.last = Dates.dayKey(epoch)
    st.checkin.streak = streak
    st.checkin.total += 1
    st.checkin.best = max(st.checkin.best, streak)
    let reward = Rules.checkin[day - 1]
    let pct = bonus("checkin")
    var got = CheckinResult(day: day, streak: streak, freezes: freezes, broke: broke)
    if reward.coins > 0 { got.coins = addCoins(Double(reward.coins) * (1 + pct / 100), found: true) }
    if reward.xp > 0 { got.xp = Int(addXp(Double(reward.xp) * (1 + pct / 100), "checkin")) }
    if let t = reward.token { st.inv.tokens[t, default: 0] += 1; got.token = t }
    if reward.crate > 0 {
      let r = (day == 7 && streak % 28 == 0) ? 6 : reward.crate
      st.inv.crates[r - 1] += 1
      got.crate = r
    }
    progress("checkins", 1)
    var n = Notice(.checkin); n.checkin = got
    notice(n)
    return got
  }

  // The shop -------------------------------------------------------------------------

  /// Everything for sale: her passes, then the game's tokens and boxes.
  public var shopItems: [ShopItem] { st.rewards + Rules.fixedShop }

  public func shopItem(_ id: String) -> ShopItem? { shopItems.first { $0.id == id } }

  /// Daily Deals: three things made for the day - gear, cosmetics, a prompt -
  /// Rare to Legendary, at a price by rarity. Made once a day and kept.
  public func makeDeals(_ day: String) {
    let d = Dice(seedOf("deals", day))
    var deals: [Deal] = []
    for _ in 0..<3 {
      let r = Rarity.roll(d, Rarity.rare, Rarity.legendary)
      let drop = Loot.drop(d, r, pool: "deal", ilvl: st.level)
      let price = Double(Rules.dealPrice[r] ?? 500) * (drop.type == "gear" ? 1 : 0.6)
      deals.append(Deal(drop: drop, price: Int((price + 0.5).rounded(.down))))
    }
    st.shop = ShopState(day: day, deals: deals)
  }

  @discardableResult
  public func buy(_ id: String) -> Bool {
    guard let item = shopItem(id), st.coins >= item.price else { return false }
    st.coins -= item.price
    st.stats.coinsSpent += Double(item.price)
    st.stats.purchases += 1
    switch item.kind {
    case "pass": st.inv.passes[id, default: 0] += 1
    case "token": st.inv.tokens[item.token ?? id, default: 0] += 1
    case "crate": st.inv.crates[(item.rarity ?? 4) - 1] += 1
    default: break
    }
    var n = Notice(.purchase, text: item.name, icon: item.icon); n.price = item.price; n.name = item.name
    notice(n)
    return true
  }

  @discardableResult
  public func buyDeal(_ i: Int) -> Bool {
    guard st.shop.deals.indices.contains(i) else { return false }
    let deal = st.shop.deals[i]
    if deal.bought || st.coins < deal.price { return false }
    st.coins -= deal.price
    st.stats.coinsSpent += Double(deal.price)
    st.stats.purchases += 1
    st.shop.deals[i].bought = true
    let d = grant(deal.drop)
    var n = Notice(.purchase, text: d.text, icon: d.icon, rarity: d.rarity); n.price = deal.price; n.name = d.text
    notice(n)
    return true
  }

  /// Spends a pass: the permission slip is signed.
  @discardableResult
  public func redeem(_ id: String, _ epoch: Int) -> Bool {
    guard (st.inv.passes[id] ?? 0) > 0 else { return false }
    let name = shopItem(id)?.name ?? "Pass"
    st.inv.passes[id, default: 0] -= 1
    if st.inv.passes[id] == 0 { st.inv.passes[id] = nil }
    st.stats.redeemed += 1
    st.log.insert(LogEntry(id: id, name: name, t: epoch), at: 0)
    if st.log.count > 50 { st.log.removeLast(st.log.count - 50) }
    var n = Notice(.redeem, text: name, icon: shopItem(id)?.icon ?? "ticket"); n.id = id; n.name = name
    notice(n)
    return true
  }

  @discardableResult
  public func useBoost() -> Bool {
    guard (st.inv.tokens["boost"] ?? 0) > 0 else { return false }
    st.inv.tokens["boost", default: 0] -= 1
    let secs = Rules.boostSeconds * (hasPower("overclock") ? 2 : 1)
    st.boost += secs
    st.stats.boosts += 1
    notice(Notice(.toast, text: "XP Boost on", sub: "Double XP for \(Int(secs / 60)) minutes of writing", icon: "bolt.fill", rarity: 5))
    return true
  }

  // Her own rewards ------------------------------------------------------------------

  /// Adds a pass of her own to the shop and returns its id.
  @discardableResult
  public func addReward(name: String, price: Int, icon: String = "gift", desc: String = "") -> String {
    let id = "own-\(newId())"
    st.rewards.append(ShopItem(id: id, kind: "pass", name: name, price: max(1, price), icon: icon, desc: desc))
    return id
  }

  public func updateReward(_ item: ShopItem) {
    guard let i = st.rewards.firstIndex(where: { $0.id == item.id }) else { return }
    var it = item
    it.price = max(1, it.price)
    if it.name.trimmingCharacters(in: .whitespaces).isEmpty { it.name = st.rewards[i].name }
    st.rewards[i] = it
  }

  /// A pass she owns stays redeemable, so one can't be removed while owned.
  @discardableResult
  public func removeReward(_ id: String) -> Bool {
    if (st.inv.passes[id] ?? 0) > 0 { return false }
    st.rewards.removeAll { $0.id == id }
    return true
  }

  public func resetRewards() {
    let owned = st.rewards.filter { (st.inv.passes[$0.id] ?? 0) > 0 && !Rules.defaultRewards.map(\.id).contains($0.id) }
    st.rewards = Rules.defaultRewards + owned
  }

  // The wardrobe ---------------------------------------------------------------------

  func findStash(_ uid: Int) -> Int? { st.gear.stash.firstIndex { $0.uid == uid } }

  @discardableResult
  public func equip(_ uid: Int) -> Bool {
    guard let i = findStash(uid) else { return false }
    let item = st.gear.stash.remove(at: i)
    let slot = item.slot ?? "charm"
    if let old = st.gear.equipped[slot] { st.gear.stash.insert(old, at: 0) }
    st.gear.equipped[slot] = item
    notice(Notice(.equip, text: item.name, rarity: item.rarity))
    return true
  }

  @discardableResult
  public func unequip(_ slot: String) -> Bool {
    guard let item = st.gear.equipped[slot], st.gear.stash.count < Rules.stashMax else { return false }
    st.gear.equipped[slot] = nil
    st.gear.stash.insert(item, at: 0)
    return true
  }

  @discardableResult
  public func salvage(_ uid: Int) -> Int {
    guard let i = findStash(uid) else { return 0 }
    let item = st.gear.stash.remove(at: i)
    let v = Gear.sellValue(item)
    st.coins += v
    var n = Notice(.coins); n.amount = v
    notice(n)
    return v
  }

  /// Sells everything in the wardrobe at or under a rarity.
  @discardableResult
  public func salvageUpTo(_ maxRarity: Int) -> (Int, Int) {
    var total = 0, n = 0
    st.gear.stash.removeAll { it in
      if it.rarity <= maxRarity { total += Gear.sellValue(it); n += 1; return true }
      return false
    }
    st.coins += total
    if n > 0 { var c = Notice(.coins); c.amount = total; notice(c) }
    return (n, total)
  }

  // The vault of prompts -----------------------------------------------------------------

  public func findIdea(_ uid: Int) -> Int? { st.vault.firstIndex { $0.uid == uid } }

  @discardableResult
  public func removeIdea(_ uid: Int) -> Bool {
    guard let i = findIdea(uid) else { return false }
    st.vault.remove(at: i)
    return true
  }

  public func toggleFav(_ uid: Int) {
    guard let i = findIdea(uid) else { return }
    st.vault[i].fav = !(st.vault[i].fav ?? false)
  }

  /// She used a prompt in her writing: XP, and it counts for quests.
  public func ideaUsed(_ uid: Int) {
    guard let i = findIdea(uid), st.vault[i].used != true else { return }
    st.vault[i].used = true
    event("idea", 1)
  }
}
