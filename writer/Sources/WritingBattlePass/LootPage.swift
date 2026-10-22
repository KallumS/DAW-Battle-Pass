import SwiftUI
import PassCore

/// Gift boxes to open, passes to spend, tokens, and the slips already signed.
struct LootPage: View {
  @ObservedObject var model: Model
  var body: some View {
    let st = model.st
    VStack(alignment: .leading, spacing: 16) {
      Panel {
        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(text: "Gift boxes", right: "\(st.inv.crates.reduce(0, +)) to open")
          HStack(spacing: 10) {
            ForEach(2...7, id: \.self) { r in
              let n = st.inv.crates[r - 1]
              VStack(spacing: 8) {
                Image(systemName: "gift.fill").font(.system(size: 34)).foregroundStyle(Theme.rarity(r))
                  .shadow(color: n > 0 && r >= Rarity.epic ? Theme.rarity(r).opacity(0.7) : .clear, radius: 10)
                  .opacity(n > 0 ? 1 : 0.3)
                Text(Rarity.name(r)).font(Theme.ui(11.5, .bold)).foregroundStyle(Theme.rarity(r))
                Text("x \(n)").font(Theme.ui(12)).foregroundStyle(Theme.dim)
                Button("Open") { model.openCrate(r) }.buttonStyle(Pill(on: n > 0)).disabled(n == 0).opacity(n > 0 ? 1 : 0.4)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(RoundedRectangle(cornerRadius: 10).fill(Theme.deep))
            }
          }
        }
      }

      HStack(alignment: .top, spacing: 16) {
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your passes", right: "Buy them in the Shop")
            let owned = st.inv.passes.filter { $0.value > 0 }.sorted { $0.key < $1.key }
            if owned.isEmpty {
              Text("No passes yet. Save up coins and treat yourself in the Shop.").font(Theme.ui(12.5)).foregroundStyle(Theme.dim)
            }
            ForEach(owned, id: \.key) { id, n in
              let item = model.engine.shopItem(id)
              HStack(spacing: 10) {
                Icon(name: item?.icon ?? "ticket", size: 20, colour: Theme.coin)
                VStack(alignment: .leading, spacing: 1) {
                  Text(item?.name ?? "Pass").font(Theme.ui(14, .semibold))
                  Text("x \(n)").font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
                }
                Spacer()
                SureButton(label: "Redeem") { model.act { $0.redeem(id, Model.epoch()) } }
              }
              .padding(10)
              .background(RoundedRectangle(cornerRadius: 10).fill(Theme.deep))
            }
          }
        }
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Tokens")
            ForEach(["boost", "reroll", "freeze"], id: \.self) { t in
              let info = Loot.tokens[t]!
              HStack(spacing: 10) {
                Icon(name: info.icon, size: 18, colour: Theme.rarity(4))
                VStack(alignment: .leading, spacing: 1) {
                  Text("\(info.name)  x \(st.inv.tokens[t] ?? 0)").font(Theme.ui(13.5, .semibold))
                  Text(info.text).font(Theme.ui(11)).foregroundStyle(Theme.dim)
                }
                Spacer()
                if t == "boost" {
                  Button("Use") { model.act { $0.useBoost() } }
                    .buttonStyle(Pill(on: st.boost > 0)).disabled((st.inv.tokens["boost"] ?? 0) == 0)
                    .opacity((st.inv.tokens["boost"] ?? 0) == 0 ? 0.4 : 1)
                }
              }
            }
          }
        }
        .frame(width: 330)
      }

      Panel {
        VStack(alignment: .leading, spacing: 8) {
          SectionTitle(text: "Signed slips", right: "\(Int(st.stats.redeemed)) redeemed")
          if st.log.isEmpty { Text("Passes you redeem are kept here.").font(Theme.ui(12.5)).foregroundStyle(Theme.dim) }
          ForEach(Array(st.log.prefix(12).enumerated()), id: \.offset) { _, e in
            HStack {
              Text(e.name).font(Theme.serif(13.5))
              Spacer()
              Text(Fmt.date(e.t)).font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
            }
          }
        }
      }
    }
  }
}

/// Her passes, the game's tokens and boxes, and three Daily Deals.
struct ShopPage: View {
  @ObservedObject var model: Model
  let cols = [GridItem(.adaptive(minimum: 220), spacing: 12)]
  var body: some View {
    let st = model.st
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        CoinView(size: 22)
        Text(Fmt.num(st.coins) + " coins").font(Theme.ui(20, .heavy)).foregroundStyle(Theme.coin)
        Spacer()
        Text("Treats are yours to change in Settings").font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
      }
      SectionTitle(text: "Treats", right: "Permission slips: buy one, then redeem it in Loot when you take the treat")
      LazyVGrid(columns: cols, spacing: 12) {
        ForEach(st.rewards) { item in ShopCard(model: model, item: item) }
      }
      SectionTitle(text: "Tokens and gift boxes")
      LazyVGrid(columns: cols, spacing: 12) {
        ForEach(Rules.fixedShop) { item in ShopCard(model: model, item: item) }
      }
      SectionTitle(text: "Daily deals", right: "New in \(Fmt.dur(Double(Dates.secsToNextDay(Model.epoch()))))")
      HStack(alignment: .top, spacing: 12) {
        ForEach(Array(st.shop.deals.enumerated()), id: \.offset) { i, deal in
          VStack(spacing: 8) {
            DropCard(drop: deal.drop)
            HStack {
              HStack(spacing: 4) { CoinView(size: 14); Text(Fmt.num(deal.price)).font(Theme.ui(14, .bold)).foregroundStyle(Theme.coin) }
              Spacer()
              if deal.bought { Text("Bought").font(Theme.ui(12, .semibold)).foregroundStyle(Theme.dim) }
              else { SureButton(label: "Buy", disabled: st.coins < deal.price) { model.act { $0.buyDeal(i) } } }
            }
          }
          .frame(maxWidth: .infinity)
          .opacity(deal.bought ? 0.5 : 1)
        }
      }
    }
  }
}

struct ShopCard: View {
  @ObservedObject var model: Model
  let item: ShopItem
  var body: some View {
    let st = model.st
    let owned = item.kind == "pass" ? (st.inv.passes[item.id] ?? 0) : (item.kind == "token" ? (st.inv.tokens[item.token ?? ""] ?? 0) : st.inv.crates[(item.rarity ?? 4) - 1])
    let afford = st.coins >= item.price
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Icon(name: item.icon, size: 24, colour: item.kind == "crate" ? Theme.rarity(item.rarity ?? 4) : Theme.coin)
        Text(item.name).font(Theme.ui(14.5, .bold)).lineLimit(2)
        Spacer(minLength: 0)
      }
      Text(item.desc).font(Theme.ui(11.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true).lineLimit(3)
      Spacer(minLength: 0)
      HStack {
        HStack(spacing: 4) { CoinView(size: 14); Text(Fmt.num(item.price)).font(Theme.ui(14, .bold)).foregroundStyle(Theme.coin) }
        if owned > 0 { Text("have \(owned)").font(Theme.ui(11)).foregroundStyle(Theme.dim) }
        Spacer()
        SureButton(label: "Buy", disabled: !afford) { model.act { $0.buy(item.id) } }
      }
      if !afford {
        Bar(frac: Double(st.coins) / Double(item.price), colour: Theme.coin.opacity(0.7), height: 4)
      }
    }
    .padding(12)
    .frame(minHeight: 132)
    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sunken))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rule.opacity(0.6)))
  }
}

/// Eight slots worn, the wardrobe of everything else, and a closer look.
struct WardrobePage: View {
  @ObservedObject var model: Model
  let cols = [GridItem(.adaptive(minimum: 150), spacing: 10)]
  var body: some View {
    let st = model.st
    let selected = model.selectedGear.flatMap { uid in st.gear.stash.first { $0.uid == uid } }
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(text: "Wearing", right: "Style score \(model.engine.gearScore())")
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
        ForEach(Gear.slots, id: \.id) { slot in
          let item = st.gear.equipped[slot.id]
          HStack(spacing: 10) {
            Icon(name: slot.icon, size: 22, colour: item.map { Theme.rarity($0.rarity) } ?? Theme.rule)
            VStack(alignment: .leading, spacing: 2) {
              Text(slot.name.uppercased()).font(Theme.ui(9.5, .heavy)).kerning(1).foregroundStyle(Theme.dim)
              Text(item?.name ?? "Nothing yet").font(Theme.ui(12.5, .semibold))
                .foregroundStyle(item.map { Theme.rarity($0.rarity) } ?? Theme.dim).lineLimit(2)
            }
            Spacer(minLength: 0)
          }
          .padding(10)
          .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
          .background(RoundedRectangle(cornerRadius: 10).fill(Theme.sunken))
          .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(item.map { Theme.rarity($0.rarity).opacity(0.6) } ?? Theme.rule.opacity(0.5)))
          .help(item.map { i in Gear.stats(i).map { Gear.statLine($0.key, $0.value) }.sorted().joined(separator: "\n") } ?? "")
          .contextMenu {
            if item != nil { Button("Take off") { model.act { $0.unequip(slot.id) } } }
          }
        }
      }

      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            SectionTitle(text: "Wardrobe", right: "\(st.gear.stash.count) / \(Rules.stashMax)")
            SureButton(label: "Sell all Poor and Common") { model.act { $0.salvageUpTo(Rarity.common) } }
          }
          if st.gear.stash.isEmpty {
            Text("Clothes, make-up and pens you find land here. Wear the best; sell the rest for coins.")
              .font(Theme.ui(12.5)).foregroundStyle(Theme.dim)
          }
          LazyVGrid(columns: cols, spacing: 10) {
            ForEach(st.gear.stash, id: \.uid) { item in
              Button { model.selectedGear = item.uid } label: {
                HStack(spacing: 8) {
                  Icon(name: item.icon, size: 18, colour: Theme.rarity(item.rarity))
                  Text(item.name).font(Theme.ui(12, .semibold)).foregroundStyle(Theme.rarity(item.rarity))
                    .lineLimit(2).multilineTextAlignment(.leading)
                  Spacer(minLength: 0)
                }
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.sunken))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(model.selectedGear == item.uid ? Theme.accent : Theme.rarity(item.rarity).opacity(0.4), lineWidth: model.selectedGear == item.uid ? 2 : 1))
              }
              .buttonStyle(.plain)
            }
          }
        }
        VStack(alignment: .leading, spacing: 10) {
          if let item = selected {
            let worn = st.gear.equipped[item.slot ?? ""]
            DropCard(drop: item, glow: false)
            Panel {
              VStack(alignment: .leading, spacing: 6) {
                Text(worn == nil ? "Nothing worn in this slot" : "Against what you wear:").font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
                GearLines(item: item, against: worn)
              }
            }
            HStack {
              Button("Wear it") { model.act { $0.equip(item.uid ?? -1) }; model.selectedGear = nil }.buttonStyle(Pill(on: true))
              SureButton(label: "Sell for \(Gear.sellValue(item))") { model.act { $0.salvage(item.uid ?? -1) }; model.selectedGear = nil }
            }
          } else {
            Panel {
              Text("Choose something in the wardrobe to see it up close and compare it with what you're wearing.")
                .font(Theme.ui(12.5)).foregroundStyle(Theme.dim)
            }
          }
        }
        .frame(width: 330)
      }
    }
  }
}
