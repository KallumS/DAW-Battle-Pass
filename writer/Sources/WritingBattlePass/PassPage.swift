import SwiftUI
import PassCore

/// The season: where she is on the track, today's writing, the week.
struct PassPage: View {
  @ObservedObject var model: Model

  var body: some View {
    let st = model.st
    let ep = Model.epoch()
    let today = Dates.dayKey(ep)
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Season \(st.pass.season)", right: Fmt.dur(Double(Dates.secsToNextSeason(ep))) + " left")
            Text(Loot.seasonName(st.pass.season)).font(Theme.serif(28, .bold))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text("Tier \(st.pass.tier)").font(Theme.ui(18, .bold)).foregroundStyle(Theme.pass)
              Text("of \(Loot.seasonTiers)" + (st.pass.tier >= Loot.seasonTiers ? " - bonus tiers from here" : ""))
                .font(Theme.ui(13)).foregroundStyle(Theme.dim)
            }
            Bar(frac: Double(min(st.pass.tier, Loot.seasonTiers)) / Double(Loot.seasonTiers), colour: Theme.pass, height: 8)
            Text("A tier every fifteen minutes of writing, a big one every hour. The clock only runs while you're writing.")
              .font(Theme.ui(12)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
          }
        }
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Today")
            HStack(spacing: 22) {
              stat(Fmt.dur(st.days[today] ?? 0), "writing")
              stat(Fmt.num(st.dayWords[today] ?? 0), "words")
              stat(Fmt.num(model.engine.sprintWords()), "last 15 min")
            }
            HStack(spacing: 22) {
              stat(Fmt.dur(model.engine.weekSeconds(ep)), "this week")
              stat("\(st.checkin.streak)", "day streak")
              stat(Fmt.num(model.engine.ss.words), "this sitting")
            }
          }
        }
        .frame(width: 330)
      }

      Panel {
        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text: "The track", right: "Next: \(Fmt.clock(model.secsToTier)) of writing")
          ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
              HStack(spacing: 8) {
                ForEach(max(1, st.pass.tier - 4)...(st.pass.tier + 24), id: \.self) { t in
                  TierCell(tier: t, season: st.pass.season, level: st.level, have: st.pass.tier)
                    .id(t)
                }
              }
              .padding(.vertical, 6).padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(max(1, st.pass.tier - 1), anchor: .leading) }
          }
        }
      }

      HStack(alignment: .top, spacing: 16) {
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "This week")
            WeekChart(model: model)
          }
        }
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Lately")
            if st.recent.isEmpty {
              Text("Nothing yet. Write for fifteen minutes and the first tier opens.")
                .font(Theme.ui(12.5)).foregroundStyle(Theme.dim)
            }
            ForEach(Array(st.recent.prefix(6).enumerated()), id: \.offset) { _, d in
              HStack(spacing: 8) {
                Icon(name: d.icon, size: 14, colour: Theme.rarity(d.rarity))
                Text(d.text).font(d.type == "idea" ? Theme.serif(12.5) : Theme.ui(12.5, .medium))
                  .foregroundStyle(d.type == "idea" ? Theme.text : Theme.rarity(d.rarity)).lineLimit(1)
              }
            }
          }
        }
        .frame(width: 330)
      }
    }
  }

  func stat(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(value).font(Theme.ui(20, .bold)).monospacedDigit()
      Text(label).font(Theme.ui(11)).foregroundStyle(Theme.dim)
    }
  }
}

struct TierCell: View {
  let tier: Int, season: Int, level: Int, have: Int
  var body: some View {
    let head = Loot.tierHeadline(season: season, tier: tier, ilvl: level)
    let best = head.0, kind = head.1
    let done = tier <= have
    let next = tier == have + 1
    let big = kind != "small"
    VStack(spacing: 5) {
      Text("\(tier)").font(Theme.ui(12, .heavy)).foregroundStyle(done ? Theme.dim : (big ? Theme.pass : Theme.text))
      ZStack {
        RoundedRectangle(cornerRadius: 9).fill(Theme.deep)
        if best.type == "banner" { BannerView(data: best.banner, size: 30) }
        else { Icon(name: best.icon, size: 22, colour: Theme.rarity(best.rarity)) }
        if done {
          RoundedRectangle(cornerRadius: 9).fill(Theme.deep.opacity(0.55))
          Image(systemName: "checkmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.pass)
        }
      }
      .frame(width: big ? 62 : 52, height: big ? 62 : 52)
      .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(next ? Theme.accent : Theme.rarity(best.rarity).opacity(done ? 0.25 : 0.8), lineWidth: next ? 2.5 : 1.5))
      Text(kind == "small" ? Rarity.name(best.rarity) : kind.capitalized)
        .font(Theme.ui(9.5, .bold)).foregroundStyle(done ? Theme.dim : Theme.rarity(best.rarity)).lineLimit(1)
    }
    .frame(width: 70)
    .help(best.text + (best.sub.isEmpty ? "" : "\n" + best.sub))
  }
}

/// Minutes written each day this week, Monday first.
struct WeekChart: View {
  @ObservedObject var model: Model
  var body: some View {
    let ep = Model.epoch()
    let monday = Dates.weekKey(ep)
    let today = Dates.dayKey(ep)
    let days: [(String, Double, Double)] = (0..<7).map { i in
      let k = Self.add(monday, i)
      return (k, model.st.days[k] ?? 0, model.st.dayWords[k] ?? 0)
    }
    let top = max(3600, days.map { $0.1 }.max() ?? 0)
    HStack(alignment: .bottom, spacing: 10) {
      ForEach(0..<7, id: \.self) { i in
        let d = days[i]
        VStack(spacing: 4) {
          Text(d.1 > 0 ? Fmt.dur(d.1) : "").font(Theme.ui(10)).foregroundStyle(Theme.dim)
          RoundedRectangle(cornerRadius: 4)
            .fill(d.0 == today ? Theme.pass : Theme.pass.opacity(0.55))
            .frame(height: max(3, 110 * d.1 / top))
          Text(Dates.shortDay(d.0)).font(Theme.ui(10.5, d.0 == today ? .bold : .regular))
            .foregroundStyle(d.0 == today ? Theme.text : Theme.dim)
          Text(d.2 > 0 ? Fmt.num(d.2) + "w" : " ").font(Theme.ui(9.5)).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .frame(height: 160)
  }

  static func add(_ key: String, _ days: Int) -> String {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, let d = Dates.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
          let e = Dates.calendar.date(byAdding: .day, value: days, to: d) else { return key }
    let c = Dates.calendar.dateComponents([.year, .month, .day], from: e)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
}
