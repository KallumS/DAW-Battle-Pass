import SwiftUI
import PassCore

/// A picture for an icon name: the coin is drawn, everything else is an SF
/// Symbol.
struct Icon: View {
  let name: String
  var size: CGFloat = 16
  var colour: Color = Theme.text
  var body: some View {
    if name == "coin" {
      CoinView(size: size)
    } else {
      Image(systemName: name)
        .font(.system(size: size * 0.9, weight: .semibold))
        .foregroundStyle(colour)
        .frame(width: size * 1.2, height: size * 1.2)
    }
  }
}

struct CoinView: View {
  var size: CGFloat = 16
  var body: some View {
    ZStack {
      Circle().fill(Theme.coin)
      Circle().strokeBorder(Theme.coinEdge, lineWidth: max(1, size / 8))
      Text("c").font(.system(size: size * 0.55, weight: .heavy, design: .rounded)).foregroundStyle(Theme.coinEdge)
    }
    .frame(width: size, height: size)
  }
}

/// The house button: dark ink on the light control grey; the accent when on.
struct Pill: ButtonStyle {
  var on = false
  var colour: Color? = nil
  var big = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Theme.ui(big ? 15 : 12.5, .semibold))
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, big ? 22 : 12)
      .padding(.vertical, big ? 10 : 5)
      .background(
        RoundedRectangle(cornerRadius: big ? 10 : 7)
          .fill(on ? Theme.accent : (colour ?? Theme.control))
          .brightness(configuration.isPressed ? -0.15 : 0)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .contentShape(Rectangle())
  }
}

/// The two-step button for anything that spends or destroys: the first click
/// turns it into a yellow "Sure?" for three seconds.
struct SureButton: View {
  let label: String
  var disabled = false
  var big = false
  let action: () -> Void
  @State private var armed = false
  @State private var token = 0
  var body: some View {
    Button(armed ? "Sure?" : label) {
      if armed {
        armed = false
        action()
      } else {
        armed = true
        token += 1
        let t = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { if token == t { armed = false } }
      }
    }
    .buttonStyle(Pill(on: armed, big: big))
    .disabled(disabled)
    .opacity(disabled ? 0.45 : 1)
  }
}

/// A row that scrolls sideways - or, in snapshots, just a clipped row,
/// because the renderer can't see inside a ScrollView.
struct HScroll<Content: View>: View {
  let snapshot: Bool
  @ViewBuilder let content: Content
  var body: some View {
    if snapshot {
      HStack(spacing: 0) { content; Spacer(minLength: 0) }.clipped()
    } else {
      ScrollView(.horizontal, showsIndicators: true) { content }
    }
  }
}

/// A sunken panel.
struct Panel<Content: View>: View {
  var padding: CGFloat = 14
  var stroke: Color? = nil
  @ViewBuilder let content: Content
  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sunken))
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(stroke ?? Theme.rule.opacity(0.6), lineWidth: stroke == nil ? 1 : 1.5))
  }
}

struct SectionTitle: View {
  let text: String
  var right: String? = nil
  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(text.uppercased()).font(Theme.ui(11.5, .bold)).kerning(1.2).foregroundStyle(Theme.dim)
      Spacer()
      if let r = right { Text(r).font(Theme.ui(11.5)).foregroundStyle(Theme.dim) }
    }
  }
}

/// A bar: the empty part deep, the full part a colour.
struct Bar: View {
  let frac: Double
  var colour: Color = Theme.xp
  var height: CGFloat = 10
  var stripes = false
  var body: some View {
    GeometryReader { geo in
      let f = CGFloat(min(1, max(0, frac)))
      ZStack(alignment: .leading) {
        Capsule().fill(Theme.deep)
        Capsule().fill(colour)
          .frame(width: max(height, geo.size.width * f))
          .opacity(frac <= 0 ? 0.25 : 1)
        if stripes {
          Stripes().fill(Theme.accent.opacity(0.45))
            .frame(width: max(height, geo.size.width * f))
            .clipShape(Capsule())
        }
      }
    }
    .frame(height: height)
  }
}

/// Diagonal stripes, for an XP Boost on the bar: yellow, because it is on.
struct Stripes: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    var x = r.minX - r.height
    while x < r.maxX {
      p.move(to: CGPoint(x: x, y: r.maxY))
      p.addLine(to: CGPoint(x: x + 6, y: r.maxY))
      p.addLine(to: CGPoint(x: x + 6 + r.height, y: r.minY))
      p.addLine(to: CGPoint(x: x + r.height, y: r.minY))
      p.closeSubpath()
      x += 14
    }
    return p
  }
}

/// A ring that fills: the pass clock.
struct Ring: View {
  let frac: Double
  var colour: Color
  var width: CGFloat = 8
  var body: some View {
    ZStack {
      Circle().stroke(Theme.deep, lineWidth: width)
      Circle().trim(from: 0, to: min(1, max(0.001, frac)))
        .stroke(colour, style: StrokeStyle(lineWidth: width, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

/// A coloured strip down the side of a card: its rarity.
struct RarityTag: View {
  let r: Int
  var body: some View {
    Text(Rarity.name(r).uppercased())
      .font(Theme.ui(9.5, .heavy)).kerning(1)
      .foregroundStyle(Theme.rarity(r))
  }
}

/// A card for anything that drops.
struct DropCard: View {
  let drop: Drop
  var compact = false
  var glow = true
  var body: some View {
    let col = Theme.rarity(drop.rarity)
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        if drop.type == "banner", let b = drop.banner {
          BannerView(data: b, size: compact ? 26 : 34)
        } else {
          Icon(name: drop.icon, size: compact ? 18 : 24, colour: col)
        }
        VStack(alignment: .leading, spacing: 1) {
          RarityTag(r: drop.rarity)
          Text(drop.name).font(Theme.ui(11)).foregroundStyle(Theme.dim)
        }
        Spacer(minLength: 0)
      }
      Text(drop.text)
        .font(drop.type == "idea" ? Theme.serif(compact ? 13 : 15, .medium) : Theme.ui(compact ? 13 : 15, .bold))
        .foregroundStyle(drop.type == "idea" ? Theme.text : col)
        .fixedSize(horizontal: false, vertical: true)
        .lineLimit(compact ? 3 : 8)
      if !drop.sub.isEmpty && !compact {
        Text(drop.sub).font(drop.type == "idea" ? Theme.serif(12).italic() : Theme.ui(11.5))
          .foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true).lineLimit(6)
      }
      if drop.type == "gear" && !compact { GearLines(item: drop) }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sunken))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(col.opacity(drop.rarity <= 2 ? 0.35 : 0.9), lineWidth: 1.5))
    .shadow(color: glow && drop.rarity >= Rarity.epic ? col.opacity(0.55) : .clear, radius: drop.rarity >= Rarity.legendary ? 14 : 8)
  }
}

/// A piece of gear's stats, and against another, each line's difference.
struct GearLines: View {
  let item: Drop
  var against: Drop? = nil
  var body: some View {
    let stats = Gear.stats(item)
    let other = against.map { Gear.stats($0) } ?? [:]
    VStack(alignment: .leading, spacing: 2) {
      if let i = item.implicit {
        line(Gear.statLine(i.id, stats[i.id] ?? i.value), diff: against == nil ? nil : (stats[i.id] ?? 0) - (other[i.id] ?? 0), implicit: true)
      }
      ForEach(item.affixes ?? [], id: \.id) { a in
        line(Gear.statLine(a.id, a.value), diff: against == nil ? nil : (stats[a.id] ?? 0) - (other[a.id] ?? 0), implicit: false)
      }
      if let p = item.power.flatMap({ Gear.power($0) }) {
        Text("\(p.name): \(p.text)").font(Theme.ui(11.5, .semibold)).foregroundStyle(Theme.rarity(Rarity.legendary))
          .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
      }
      if against != nil {
        let d = Gear.score(item) - Gear.score(against!)
        Text("Style score \(Gear.score(item)) (\(d >= 0 ? "+" : "")\(d) on what you wear)")
          .font(Theme.ui(11)).foregroundStyle(d >= 0 ? Theme.rarity(3) : Theme.warn).padding(.top, 2)
      }
    }
  }

  func line(_ s: String, diff: Int?, implicit: Bool) -> some View {
    HStack(spacing: 6) {
      Text(s).font(Theme.ui(11.5, implicit ? .regular : .medium)).foregroundStyle(implicit ? Theme.dim : Theme.text)
      if let d = diff, d != 0 {
        Text(d > 0 ? "+\(d)" : "\(d)").font(Theme.ui(10.5, .bold)).foregroundStyle(d > 0 ? Theme.rarity(3) : Theme.warn)
      }
    }
  }
}

/// A banner: a shape, a pattern in two hues, and on rarer ones a glyph.
struct BannerView: View {
  let data: BannerData?
  var size: CGFloat = 52
  var body: some View {
    let b = data ?? BannerData(shape: "circle", pattern: "plain", h1: 0.75, h2: 0.85, glyph: "pencil", glow: false, spin: false, sat: 0.25)
    let sat = b.sat ?? 0.62
    let c1 = Color.banner(b.h1, sat: sat), c2 = Color.banner(b.h2, sat: sat, bright: 0.6)
    let shape = BannerShape(kind: b.shape)
    ZStack {
      shape.fill(c2)
      BannerPattern(kind: b.pattern).fill(c1).clipShape(shape)
      shape.stroke(Color.white.opacity(0.65), lineWidth: max(1, size / 26))
      if let g = b.glyph {
        Image(systemName: g).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(.white)
          .shadow(color: .black.opacity(0.4), radius: 1)
      }
    }
    .frame(width: size, height: size)
    .shadow(color: b.glow ? c1.opacity(0.8) : .clear, radius: size / 5)
  }
}

struct BannerShape: Shape {
  let kind: String
  func path(in r: CGRect) -> Path {
    let c = CGPoint(x: r.midX, y: r.midY), rad = min(r.width, r.height) / 2
    func poly(_ n: Int, _ inner: CGFloat? = nil, rot: CGFloat = -.pi / 2) -> Path {
      var p = Path()
      let count = inner == nil ? n : n * 2
      for i in 0..<count {
        let a = rot + CGFloat(i) * 2 * .pi / CGFloat(count)
        let rr = (inner != nil && i % 2 == 1) ? rad * inner! : rad
        let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
      }
      p.closeSubpath()
      return p
    }
    switch kind {
    case "shield":
      var p = Path()
      p.move(to: CGPoint(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.08))
      p.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY + r.height * 0.08))
      p.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY + r.height * 0.5))
      p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY - r.height * 0.12))
      p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.5), control: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.12))
      p.closeSubpath()
      return p
    case "diamond": return poly(4)
    case "hexagon": return poly(6, rot: 0)
    case "star": return poly(5, 0.55)
    default: return Path(ellipseIn: r.insetBy(dx: r.width * 0.04, dy: r.height * 0.04))
    }
  }
}

struct BannerPattern: Shape {
  let kind: String
  func path(in r: CGRect) -> Path {
    var p = Path()
    switch kind {
    case "split": p.addRect(CGRect(x: r.minX, y: r.minY, width: r.width / 2, height: r.height))
    case "stripes":
      for i in stride(from: 0, to: 6, by: 2) { p.addRect(CGRect(x: r.minX, y: r.minY + r.height * CGFloat(i) / 6, width: r.width, height: r.height / 6)) }
    case "chevron":
      p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.25))
      p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
      p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
    case "rings":
      p.addEllipse(in: r.insetBy(dx: r.width * 0.18, dy: r.height * 0.18))
      p.addEllipse(in: r.insetBy(dx: r.width * 0.32, dy: r.height * 0.32))
    case "rays":
      let c = CGPoint(x: r.midX, y: r.midY)
      for i in 0..<8 where i % 2 == 0 {
        let a1 = CGFloat(i) * .pi / 4, a2 = a1 + .pi / 4
        p.move(to: c)
        p.addLine(to: CGPoint(x: c.x + cos(a1) * r.width, y: c.y + sin(a1) * r.width))
        p.addLine(to: CGPoint(x: c.x + cos(a2) * r.width, y: c.y + sin(a2) * r.width))
        p.closeSubpath()
      }
    case "dots":
      for i in 0..<3 { for j in 0..<3 {
        let s: CGFloat = r.width * 0.16
        let fx: CGFloat = 0.17 + 0.33 * CGFloat(i), fy: CGFloat = 0.17 + 0.33 * CGFloat(j)
        let x: CGFloat = r.minX + r.width * fx - s / 2, y: CGFloat = r.minY + r.height * fy - s / 2
        p.addEllipse(in: CGRect(x: x, y: y, width: s, height: s))
      } }
    default: break
    }
    return p
  }
}
