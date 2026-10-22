import SwiftUI
import AppKit
import PassCore

/// The stage: a celebration drawn in place of the page. Escape or the
/// button closes it; the next one waiting comes on after.
struct StageView: View {
  @ObservedObject var model: Model
  let item: StageItem
  @State private var shown = false

  var body: some View {
    VStack(spacing: 18) {
      Spacer(minLength: 10)
      content
      Spacer(minLength: 10)
      if model.stage.count > 1 {
        Text("\(model.stage.count - 1) more to celebrate").font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      RadialGradient(colors: [glow.opacity(0.22), Theme.ground.opacity(0)], center: .center, startRadius: 10, endRadius: 520)
    )
    .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { shown = true } }
  }

  var glow: Color {
    switch item.kind {
    case .reward: return item.crate > 0 ? Theme.rarity(item.crate) : (item.tierKind == "small" ? Theme.pass.opacity(0.6) : Theme.pass)
    case .level: return Theme.xp
    case .checkin: return Theme.accent.opacity(0.5)
    case .redeem: return Theme.coin
    case .season: return Theme.rarity(7)
    case .welcome: return Theme.rarity(5)
    }
  }

  @ViewBuilder var content: some View {
    switch item.kind {
    case .reward: reward
    case .level: level
    case .checkin: checkin
    case .redeem: redeem
    case .season: season
    case .welcome: WelcomeView(model: model)
    }
  }

  func closeButton(_ label: String) -> some View {
    Button(label) { model.closeStage() }
      .buttonStyle(Pill(on: true, big: true))
      .keyboardShortcut(.cancelAction)
  }

  func bigTitle(_ s: String, _ col: Color) -> some View {
    Text(s).font(Theme.ui(30, .heavy)).foregroundStyle(col).multilineTextAlignment(.center)
      .scaleEffect(shown ? 1 : 0.6).opacity(shown ? 1 : 0)
  }

  // A tier or a gift box -------------------------------------------------------

  @ViewBuilder var reward: some View {
    let closed = item.crate > 0 && !item.opened
    bigTitle(item.title, item.crate > 0 ? Theme.rarity(item.crate) : Theme.pass)
    Text(item.sub).font(Theme.ui(14)).foregroundStyle(Theme.dim)
    if closed {
      Button { model.openStageCrate() } label: {
        Image(systemName: "gift.fill").font(.system(size: 120)).foregroundStyle(Theme.rarity(item.crate))
          .shadow(color: Theme.rarity(item.crate).opacity(0.8), radius: 30)
          .rotationEffect(.degrees(shown ? -4 : 4))
          .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: shown)
      }
      .buttonStyle(.plain)
      .padding(20)
      Button("Open it") { model.openStageCrate() }
        .buttonStyle(Pill(on: true, big: true))
        .keyboardShortcut(.defaultAction)
    } else {
      let cols = min(4, max(1, item.drops.count))
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: cols), spacing: 14) {
        ForEach(Array(item.drops.enumerated()), id: \.offset) { i, d in
          DropCard(drop: d)
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.12 * Double(i)), value: shown)
        }
      }
      .frame(maxWidth: CGFloat(cols) * 250)
      closeButton("Collect")
    }
  }

  // Level up --------------------------------------------------------------------

  @ViewBuilder var level: some View {
    ZStack {
      Circle().fill(Theme.deep).frame(width: 150, height: 150)
      Circle().strokeBorder(Theme.xp, lineWidth: 6).frame(width: 150, height: 150)
        .shadow(color: Theme.xp, radius: 20)
      Text("\(item.level)").font(Theme.ui(64, .heavy)).foregroundStyle(Theme.bright)
    }
    .scaleEffect(shown ? 1 : 0.3)
    bigTitle("Level \(item.level)!", Theme.xp)
    HStack(spacing: 8) {
      Image(systemName: "gift.fill").foregroundStyle(Theme.rarity(item.crate))
      Text("A \(Rarity.name(item.crate)) Gift Box is waiting in Loot").foregroundStyle(Theme.text)
    }
    .font(Theme.ui(15, .semibold))
    HStack(spacing: 12) {
      Button("Open it now") {
        let r = item.crate
        model.closeStage()
        model.openCrate(r)
      }
      .buttonStyle(Pill(on: true, big: true))
      .keyboardShortcut(.defaultAction)
      Button("Later") { model.closeStage() }.buttonStyle(Pill(big: true)).keyboardShortcut(.cancelAction)
    }
  }

  // Check-in --------------------------------------------------------------------

  @ViewBuilder var checkin: some View {
    if let got = item.checkin {
      bigTitle(got.streak > 1 ? "Day \(got.streak) in a row!" : "Checked in!", Theme.accent)
      if got.broke { Text("Your streak started again - that's fine. Today counts.").font(Theme.ui(13)).foregroundStyle(Theme.dim) }
      if got.freezes > 0 { Text("A Streak Freeze kept your streak safe.").font(Theme.ui(13)).foregroundStyle(Theme.rarity(4)) }
      HStack(spacing: 22) {
        if got.coins > 0 { HStack(spacing: 6) { CoinView(size: 26); Text("+\(got.coins)").font(Theme.ui(24, .heavy)).foregroundStyle(Theme.coin) } }
        if got.xp > 0 { Text("+\(got.xp) XP").font(Theme.ui(24, .heavy)).foregroundStyle(Theme.xp) }
        if let t = got.token { Label(Loot.tokens[t]?.name ?? t, systemImage: Loot.tokens[t]?.icon ?? "dice").font(Theme.ui(18, .bold)).foregroundStyle(Theme.rarity(4)) }
        if got.crate > 0 { Label(Rarity.name(got.crate) + " Gift Box", systemImage: "gift.fill").font(Theme.ui(18, .bold)).foregroundStyle(Theme.rarity(got.crate)) }
      }
      CheckinCalendar(model: model).frame(maxWidth: 640)
      closeButton("Lovely")
    } else {
      bigTitle("Good to see you", Theme.text)
      Text("Check in every day for coins, rerolls and gift boxes. Day seven is the best one.")
        .font(Theme.ui(14)).foregroundStyle(Theme.dim)
      CheckinCalendar(model: model).frame(maxWidth: 640)
      HStack(spacing: 12) {
        Button("Check in") { model.act { $0.checkin(Model.epoch()) } }
          .buttonStyle(Pill(on: true, big: true)).keyboardShortcut(.defaultAction)
        Button("Later") { model.closeStage() }.buttonStyle(Pill(big: true)).keyboardShortcut(.cancelAction)
      }
    }
  }

  // A pass redeemed: the permission slip -----------------------------------------------

  @ViewBuilder var redeem: some View {
    VStack(spacing: 14) {
      Text("PERMISSION SLIP").font(Theme.ui(13, .heavy)).kerning(4).foregroundStyle(Color(hex: 0x8A5A2B))
      Icon(name: item.icon, size: 46, colour: Color(hex: 0xB9862A))
      Text(item.name).font(Theme.serif(30, .bold)).foregroundStyle(Color(hex: 0x2B2118))
      Text("The bearer, \(model.st.profile.name), has written enough words to deserve this, and is hereby permitted to enjoy it completely, without a shred of guilt.")
        .font(Theme.serif(15).italic()).foregroundStyle(Color(hex: 0x4A3B2E)).multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      Rectangle().fill(Color(hex: 0x8A5A2B).opacity(0.4)).frame(height: 1).padding(.horizontal, 30)
      HStack {
        Text(Fmt.date(Model.epoch())).font(Theme.serif(12)).foregroundStyle(Color(hex: 0x6B5643))
        Spacer()
        Text("Signed, the Writing Battle Pass").font(Theme.serif(14).italic()).foregroundStyle(Color(hex: 0x6B5643))
      }
    }
    .padding(34)
    .frame(maxWidth: 520)
    .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xF6EBD6)))
    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: 0xC9A66B), style: StrokeStyle(lineWidth: 2, dash: [6, 4])).padding(8))
    .rotationEffect(.degrees(shown ? -1.5 : -12))
    .scaleEffect(shown ? 1 : 0.5)
    .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
    closeButton("Enjoy it")
  }

  // A new season -------------------------------------------------------------------

  @ViewBuilder var season: some View {
    Text("A NEW SEASON BEGINS").font(Theme.ui(14, .heavy)).kerning(3).foregroundStyle(Theme.rarity(7))
    bigTitle(item.title, Theme.bright)
    let last = model.st.seasons.sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }.last
    if let l = last { Text("Last season you reached tier \(l.value). The track starts again at tier 1.").font(Theme.ui(14)).foregroundStyle(Theme.dim) }
    closeButton("Let's go")
  }
}

/// First run: what this is, her name, and the permission for counting letters.
struct WelcomeView: View {
  @ObservedObject var model: Model
  @State private var name = ""
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "pencil.and.outline").font(.system(size: 54)).foregroundStyle(Theme.rarity(5))
      Text("Welcome to your Writing Battle Pass").font(Theme.ui(28, .heavy)).multilineTextAlignment(.center)
      VStack(alignment: .leading, spacing: 8) {
        point("clock", "Every fifteen minutes of writing unlocks a tier of this month's pass. Every hour, a big one.")
        point("character.cursor.ibeam", "Every letter you type earns a little XP. Levels bring gift boxes.")
        point("gift", "Gifts are coins, writing prompts, titles, banners - and a wardrobe of clothes, make-up and pens that make you earn faster.")
        point("bag", "Coins buy treats in the Shop: a lipstick, a new top, a makeup haul. You choose the treats and prices in Settings.")
        point("pause.circle", "The clock only runs while you're writing, and pauses when you stop.")
      }
      .frame(maxWidth: 560)
      HStack {
        Text("What should we call you?").font(Theme.ui(13.5))
        TextField("Your name", text: $name).textFieldStyle(.roundedBorder).frame(width: 220)
      }
      if !model.tapRunning {
        VStack(spacing: 6) {
          Text("To count letters, the Mac will ask to let this app see key presses (Input Monitoring). It only counts them - it never reads what you write.")
            .font(Theme.ui(12)).foregroundStyle(Theme.dim).multilineTextAlignment(.center).frame(maxWidth: 520)
          Button("Allow typing to count") { KeyTap.ask() }.buttonStyle(Pill())
        }
      }
      Button("Start writing") {
        let n = name.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { model.act { $0.st.profile.name = String(n.prefix(30)) } }
        model.closeStage()
      }
      .buttonStyle(Pill(on: true, big: true))
      .keyboardShortcut(.defaultAction)
    }
    .onAppear { name = model.st.profile.name == "Writer" ? "" : model.st.profile.name }
  }

  func point(_ icon: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon).frame(width: 22).foregroundStyle(Theme.accent)
      Text(text).font(Theme.ui(13.5)).fixedSize(horizontal: false, vertical: true)
    }
  }
}
