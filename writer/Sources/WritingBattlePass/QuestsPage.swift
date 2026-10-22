import SwiftUI
import PassCore

/// The check-in calendar, the daily and weekly quests.
struct QuestsPage: View {
  @ObservedObject var model: Model
  var body: some View {
    let st = model.st
    let ep = Model.epoch()
    VStack(alignment: .leading, spacing: 16) {
      Panel {
        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(text: "Daily check-in", right: "Streak \(st.checkin.streak)  ·  best \(st.checkin.best)  ·  \(st.inv.tokens["freeze"] ?? 0) freezes")
          CheckinCalendar(model: model)
          HStack {
            if model.engine.checkinAvailable(ep) {
              Button("Check in") { model.act { $0.checkin(Model.epoch()) } }.buttonStyle(Pill(on: true, big: true))
            } else {
              Text("Checked in today. Next in \(Fmt.dur(Double(Dates.secsToNextDay(ep)))).")
                .font(Theme.ui(12.5)).foregroundStyle(Theme.dim)
            }
            Spacer()
          }
        }
      }
      questSet("daily", "Daily quests", "New in \(Fmt.dur(Double(Dates.secsToNextDay(ep))))  ·  all three: an Uncommon Gift Box")
      questSet("weekly", "Weekly quests", "New in \(Fmt.dur(Double(Dates.secsToNextWeek(ep))))  ·  all four: an Epic Gift Box")
      Text("Rerolls left: \(st.inv.tokens["reroll"] ?? 0). Finished quests you forget to claim are claimed for you when they reset.")
        .font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
    }
  }

  func questSet(_ scope: String, _ title: String, _ right: String) -> some View {
    let set = scope == "daily" ? model.st.daily : model.st.weekly
    return VStack(alignment: .leading, spacing: 8) {
      SectionTitle(text: title, right: right)
      ForEach(Array(set.quests.enumerated()), id: \.offset) { i, q in
        QuestCard(model: model, scope: scope, index: i, q: q)
      }
    }
  }
}

struct QuestCard: View {
  @ObservedObject var model: Model
  let scope: String, index: Int, q: Quest
  var body: some View {
    let col = Theme.rarity(q.rarity)
    let ready = q.done && !q.claimed
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(q.text).font(Theme.ui(14.5, .semibold)).foregroundStyle(q.claimed ? Theme.dim : Theme.text)
        HStack(spacing: 10) {
          Bar(frac: q.progress / q.target, colour: q.done ? Theme.accent : col, height: 7).frame(maxWidth: 260)
          Text(q.unit > 1 ? "\(Int(q.progress / 60)) / \(Int(q.target / 60)) min" : "\(Fmt.num(q.progress)) / \(Fmt.num(q.target))")
            .font(Theme.ui(11.5)).foregroundStyle(Theme.dim).monospacedDigit()
        }
        HStack(spacing: 10) {
          HStack(spacing: 3) { CoinView(size: 11); Text("\(q.coins)").foregroundStyle(Theme.coin) }
          Text("\(q.xp) XP").foregroundStyle(Theme.xp)
          if q.crate > 0 {
            HStack(spacing: 3) { Image(systemName: "gift.fill").foregroundStyle(Theme.rarity(q.crate)); Text(Rarity.name(q.crate) + " Gift Box").foregroundStyle(Theme.rarity(q.crate)) }
          }
        }
        .font(Theme.ui(11.5, .semibold))
      }
      Spacer()
      if q.claimed {
        Label("Claimed", systemImage: "checkmark").font(Theme.ui(12, .semibold)).foregroundStyle(Theme.dim)
      } else if ready {
        Button("Claim") { model.act { $0.claimQuest(scope, index) } }.buttonStyle(Pill(on: true, big: true))
      } else if model.engine.canReroll(scope) {
        Button { model.act { $0.reroll(scope, index) } } label: { Label("Reroll", systemImage: "dice") }
          .buttonStyle(Pill())
          .help("Swap this quest for a different one")
      }
    }
    .padding(.vertical, 12).padding(.leading, 20).padding(.trailing, 12)
    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sunken))
    .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(col).frame(width: 4).padding(.vertical, 12).padding(.leading, 8) }
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ready ? Theme.accent : Theme.rule.opacity(0.6), lineWidth: ready ? 2 : 1))
  }
}

/// Seven days of check-in rewards; the one she's on is marked.
struct CheckinCalendar: View {
  @ObservedObject var model: Model
  var body: some View {
    let ep = Model.epoch()
    let preview = model.engine.checkinPreview(ep)
    let day = preview.day, streak = preview.streak
    let available = model.engine.checkinAvailable(ep)
    HStack(spacing: 8) {
      ForEach(1...7, id: \.self) { d in
        let r = Rules.checkin[d - 1]
        let done = d < day || (d == day && !available)
        let now = d == day && available
        VStack(spacing: 5) {
          Text("Day \(d)").font(Theme.ui(10.5, .bold)).foregroundStyle(now ? Theme.accent : Theme.dim)
          ZStack {
            if r.crate > 0 {
              let cr = (d == 7 && (streak - day + 7) % 28 == 0) ? 6 : r.crate
              Image(systemName: "gift.fill").font(.system(size: 22)).foregroundStyle(Theme.rarity(cr))
            } else if let t = r.token {
              Icon(name: Loot.tokens[t]?.icon ?? "dice", size: 20, colour: Theme.rarity(3))
            } else {
              CoinView(size: 22)
            }
            if done { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(Theme.pass).offset(x: 16, y: 14) }
          }
          .frame(height: 30)
          Text(label(r)).font(Theme.ui(10.5)).foregroundStyle(Theme.text).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.deep))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(now ? Theme.accent : Theme.rule.opacity(0.5), lineWidth: now ? 2 : 1))
        .opacity(done ? 0.6 : 1)
      }
    }
  }

  func label(_ r: Rules.CheckinDay) -> String {
    if r.crate > 0 { return (r.coins > 0 ? "\(r.coins) + " : "") + "Gift Box" }
    if let t = r.token { return Loot.tokens[t]?.name ?? t }
    return "\(r.coins)" + (r.xp > 0 ? " + \(r.xp) XP" : "")
  }
}
