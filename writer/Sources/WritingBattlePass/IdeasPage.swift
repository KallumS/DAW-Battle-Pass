import SwiftUI
import AppKit
import PassCore

/// The vault of prompts she's found: filter, copy, favourite, mark as used.
struct IdeasPage: View {
  @ObservedObject var model: Model
  var body: some View {
    let st = model.st
    let f = model.ideaFilter
    let list = st.vault.reversed().filter { v in
      f == "all" || (f == "fav" && v.fav == true) || (f == "new" && v.used != true) || v.kind == f
    }
    VStack(alignment: .leading, spacing: 14) {
      HScroll(snapshot: model.snapshot) {
        HStack(spacing: 6) {
          chip("all", "All \(st.vault.count)")
          chip("new", "Not used yet")
          chip("fav", "Favourites")
          ForEach(Ideas.all, id: \.id) { k in
            let n = st.vault.filter { $0.kind == k.id }.count
            if n > 0 { chip(k.id, "\(k.label) \(n)") }
          }
        }
      }
      if list.isEmpty {
        Panel {
          Text(st.vault.isEmpty ? "Writing prompts you find - characters, first lines, plot twists, titles - are kept here. The first tier is fifteen minutes away."
                                : "Nothing here with that filter.")
            .font(Theme.ui(12.5)).foregroundStyle(Theme.dim)
        }
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
        ForEach(list, id: \.uid) { v in IdeaCard(model: model, v: v) }
      }
      Text("\"I used this\" gives \(Int(Rules.xpIdea)) XP and counts for prompt quests. The vault keeps your last \(Rules.vaultMax); favourites are never dropped.")
        .font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
    }
  }

  func chip(_ id: String, _ label: String) -> some View {
    Button(label) { model.ideaFilter = id }.buttonStyle(Pill(on: model.ideaFilter == id)).fixedSize()
  }
}

struct IdeaCard: View {
  @ObservedObject var model: Model
  let v: Drop
  var body: some View {
    let col = Theme.rarity(v.rarity)
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Icon(name: v.icon, size: 16, colour: col)
        Text(v.name.uppercased()).font(Theme.ui(10, .heavy)).kerning(1).foregroundStyle(Theme.dim)
        Spacer()
        RarityTag(r: v.rarity)
      }
      Text(v.text).font(Theme.serif(15.5, .medium)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
      if !v.sub.isEmpty {
        Text(v.sub).font(Theme.serif(12.5).italic()).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
      }
      Spacer(minLength: 0)
      HStack(spacing: 6) {
        Button { copy() } label: { Image(systemName: "doc.on.doc") }.buttonStyle(Pill()).help("Copy")
        Button { model.act { $0.toggleFav(v.uid ?? -1) } } label: { Image(systemName: v.fav == true ? "star.fill" : "star") }
          .buttonStyle(Pill(on: v.fav == true)).help("Favourite: never dropped from the vault")
        Spacer()
        if v.used == true {
          Label("Used", systemImage: "checkmark").font(Theme.ui(11.5, .semibold)).foregroundStyle(Theme.dim)
        } else {
          Button("I used this") { model.act { $0.ideaUsed(v.uid ?? -1) } }.buttonStyle(Pill())
        }
        SureButton(label: "Bin") { model.act { $0.removeIdea(v.uid ?? -1) } }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sunken))
    .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(col).frame(width: 4).padding(.vertical, 12) }
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(col.opacity(v.rarity <= 2 ? 0.25 : 0.55)))
  }

  func copy() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(v.text + (v.sub.isEmpty ? "" : "\n" + v.sub), forType: .string)
    model.toast("Copied", "Paste it into your draft", "doc.on.doc", 3, life: 2)
  }
}

/// Achievements, and choosing a title and banner.
struct TrophiesPage: View {
  @ObservedObject var model: Model
  var body: some View {
    let st = model.st
    let totals = Achievements.totals(st)
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your title", right: "\(st.cos.titles.count) earned")
            if st.cos.titles.isEmpty { Text("Titles drop from the pass and finishing a series of trophies.").font(Theme.ui(12.5)).foregroundStyle(Theme.dim) }
            FlowLayoutCompat(items: Array(st.cos.titles.enumerated()).map { ($0.offset, $0.element) }) { i, t in
              Button(t.text) { model.act { $0.st.profile.title = ($0.st.profile.title == i ? -1 : i) } }
                .buttonStyle(Pill(on: st.profile.title == i, colour: st.profile.title == i ? nil : Theme.control))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.rarity(t.rarity), lineWidth: 1.5))
            }
          }
        }
        Panel {
          VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your banner", right: "\(st.cos.banners.count) earned")
            if st.cos.banners.isEmpty { Text("Banners drop from the pass and gift boxes.").font(Theme.ui(12.5)).foregroundStyle(Theme.dim) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
              ForEach(Array(st.cos.banners.enumerated()), id: \.offset) { i, b in
                Button { model.act { $0.st.profile.banner = ($0.st.profile.banner == i ? -1 : i) } } label: {
                  BannerView(data: b.banner, size: 46).padding(5)
                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(st.profile.banner == i ? Theme.accent : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain).help(b.text)
              }
            }
          }
        }
        .frame(width: 330)
      }
      SectionTitle(text: "Trophies", right: "\(totals.have) of \(totals.all)")
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
        ForEach(Achievements.all, id: \.id) { a in
          let have = st.ach[a.id] ?? 0
          let done = have >= a.goals.count
          let v = a.value(st)
          let goal = a.goals[min(have, a.goals.count - 1)]
          let prev = have > 0 ? a.goals[have - 1] : 0
          HStack(spacing: 12) {
            Image(systemName: done ? "trophy.fill" : "trophy")
              .font(.system(size: 22)).foregroundStyle(done ? Theme.rarity(6) : (have > 0 ? Theme.rarity(5) : Theme.rule))
              .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
              Text(a.name + (have > 0 ? " " + Achievements.roman(have) : "")).font(Theme.ui(13.5, .bold))
              Text(done ? "Done! Title: \(a.title)" : Achievements.text(a, have + 1)).font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
              if !done { Bar(frac: (v - prev) / max(1, goal - prev), colour: Theme.rarity(5), height: 5) }
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(RoundedRectangle(cornerRadius: 10).fill(Theme.sunken))
        }
      }
    }
  }
}

/// A simple wrapping row (macOS 13 has no Layout-free flow).
struct FlowLayoutCompat<Item, Content: View>: View {
  let items: [Item]
  let content: (Int, Item) -> Content
  init(items: [(Int, Item)], @ViewBuilder content: @escaping (Int, Item) -> Content) {
    self.items = items.map { $0.1 }
    self.indices = items.map { $0.0 }
    self.content = content
  }
  let indices: [Int]
  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
      ForEach(0..<items.count, id: \.self) { k in content(indices[k], items[k]) }
    }
  }
}
