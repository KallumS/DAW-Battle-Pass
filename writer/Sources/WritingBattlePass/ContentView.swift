import SwiftUI
import PassCore

struct ContentView: View {
  @ObservedObject var model: Model

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(spacing: 0) {
        Header(model: model)
          .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)
        TabBar(model: model)
          .padding(.horizontal, 20).padding(.bottom, 10)
        Rectangle().fill(Theme.rule).frame(height: 1)
        Group {
          if let item = model.stage.first {
            StageView(model: model, item: item)
              .id(item.id)
              .transition(.opacity.combined(with: .scale(scale: 0.97)))
          } else {
            ScrollView {
              page.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(model.tab)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      ToastStack(model: model)
        .padding(.top, 118).padding(.trailing, 16)
      FXOverlay(model: model)
    }
    .coordinateSpace(name: "root")
    .background(Theme.ground)
    .foregroundStyle(Theme.text)
    .preferredColorScheme(.dark)
    .animation(.easeOut(duration: 0.2), value: model.stage.first?.id)
  }

  @ViewBuilder var page: some View {
    switch model.tab {
    case .pass: PassPage(model: model)
    case .quests: QuestsPage(model: model)
    case .loot: LootPage(model: model)
    case .shop: ShopPage(model: model)
    case .wardrobe: WardrobePage(model: model)
    case .ideas: IdeasPage(model: model)
    case .trophies: TrophiesPage(model: model)
    case .settings: SettingsPage(model: model)
    }
  }
}

/// Banner, name and title, the level bar, coins, the pass clock.
struct Header: View {
  @ObservedObject var model: Model
  var body: some View {
    let st = model.st
    let need = Rules.levelNeed(st.level)
    HStack(spacing: 16) {
      ZStack(alignment: .bottom) {
        BannerView(data: model.engine.activeBanner(), size: 56)
        Text("\(st.level)")
          .font(Theme.ui(13, .heavy)).foregroundStyle(Theme.bright)
          .frame(width: 28, height: 28)
          .background(Circle().fill(Theme.deep))
          .overlay(Circle().strokeBorder(Theme.xp, lineWidth: 2))
          .offset(y: 12)
      }
      .padding(.bottom, 8)

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text(st.profile.name).font(Theme.ui(19, .bold))
          let title = model.engine.activeTitle()
          if !title.isEmpty { Text(title).font(Theme.serif(14).italic()).foregroundStyle(Theme.dim) }
        }
        Bar(frac: st.xp / need, colour: Theme.xp, height: 11, stripes: st.boost > 0)
          .background(GeometryReader { g in
            Color.clear.onAppear { place(g) }.onChange(of: st.xp) { _ in place(g) }
          })
        HStack {
          Text("Level \(st.level)   \(Fmt.num(st.xp)) / \(Fmt.num(need)) XP")
          Spacer()
          if st.boost > 0 {
            Text("2x XP  " + Fmt.clock(st.boost)).font(Theme.ui(11.5, .bold)).foregroundStyle(Theme.accent)
          }
        }
        .font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
      }
      .frame(maxWidth: .infinity)

      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 7) {
          CoinView(size: CGFloat(18 + 6 * model.fx.coinBump))
          Text(Fmt.num(st.coins)).font(Theme.ui(21, .heavy)).foregroundStyle(Theme.coin).monospacedDigit()
        }
        .background(GeometryReader { g in
          Color.clear.onAppear { model.fx.coinPos = CGPoint(x: g.frame(in: .named("root")).minX + 9, y: g.frame(in: .named("root")).midY) }
        })
        HStack(spacing: 5) {
          Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(Theme.control)
          Text("Style score \(model.engine.gearScore())").font(Theme.ui(11.5)).foregroundStyle(Theme.dim)
        }
      }
      .frame(width: 150, alignment: .leading)

      PassClock(model: model).frame(width: 150)
    }
  }

  func place(_ g: GeometryProxy) {
    let f = g.frame(in: .named("root"))
    let frac = CGFloat(min(1, max(0, model.st.xp / Rules.levelNeed(model.st.level))))
    model.fx.xpPos = CGPoint(x: f.minX + max(6, f.width * frac), y: f.midY)
  }
}

/// The ring that fills towards the next tier: yellow while the clock runs
/// (it's on), grey while paused.
struct PassClock: View {
  @ObservedObject var model: Model
  var body: some View {
    let idle = model.engine.ss.idle
    let frac = model.st.pass.secs / Rules.tierSeconds
    HStack(spacing: 10) {
      ZStack {
        Ring(frac: frac, colour: idle ? Theme.grab : Theme.accent, width: 6)
        Image(systemName: idle ? "pause.fill" : "pencil")
          .font(.system(size: 14, weight: .bold)).foregroundStyle(idle ? Theme.dim : Theme.accent)
      }
      .frame(width: 44, height: 44)
      VStack(alignment: .leading, spacing: 1) {
        Text("TIER \(model.st.pass.tier + 1)").font(Theme.ui(10, .heavy)).kerning(1).foregroundStyle(Theme.pass)
        Text(Fmt.clock(model.secsToTier)).font(Theme.ui(18, .bold)).monospacedDigit()
          .foregroundStyle(idle ? Theme.dim : Theme.text)
        Text(idle ? (model.counting ? "Paused" : "Not writing") : "Writing")
          .font(Theme.ui(10.5)).foregroundStyle(Theme.dim)
      }
    }
    .help(model.statusLine)
  }
}

struct TabBar: View {
  @ObservedObject var model: Model
  var body: some View {
    let dots = model.waitingDot
    HStack(spacing: 6) {
      ForEach(Tab.allCases) { t in
        Button(t.label) {
          model.tab = t
          model.selectedGear = nil
        }
        .buttonStyle(Pill(on: model.tab == t))
        .overlay(alignment: .topTrailing) {
          if dots.contains(t) {
            Circle().fill(Theme.warn).frame(width: 9, height: 9).offset(x: 3, y: -3)
          }
        }
      }
      Spacer()
      if !model.stage.isEmpty {
        Text("\(model.stage.count) to celebrate").font(Theme.ui(11.5, .semibold)).foregroundStyle(Theme.accent)
      }
    }
  }
}

struct ToastStack: View {
  @ObservedObject var model: Model
  var body: some View {
    VStack(alignment: .trailing, spacing: 8) {
      ForEach(model.toasts) { t in
        HStack(alignment: .top, spacing: 10) {
          Icon(name: t.icon, size: 20, colour: Theme.rarity(t.rarity))
          VStack(alignment: .leading, spacing: 2) {
            Text(t.text).font(Theme.ui(13.5, .bold)).foregroundStyle(t.trophy ? Theme.rarity(t.rarity) : Theme.text)
            Text(t.sub).font(Theme.ui(11.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            if t.coins > 0 || t.xp > 0 {
              HStack(spacing: 8) {
                if t.coins > 0 { HStack(spacing: 3) { CoinView(size: 11); Text("+\(t.coins)").foregroundStyle(Theme.coin) } }
                if t.xp > 0 { Text("+\(t.xp) XP").foregroundStyle(Theme.xp) }
              }
              .font(Theme.ui(11, .bold))
            }
          }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sunken.opacity(0.97)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rarity(t.rarity).opacity(0.85), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .onTapGesture { model.toasts.removeAll { $0.id == t.id } }
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.toasts.map(\.id))
  }
}
