import SwiftUI
import PassCore

/// Every colour the window uses - see docs/COLOUR.md in the writer folder.
/// The family's house scheme, warmed to plum: greys with a little red and
/// blue in them, one lemon yellow for whatever is switched on, and the
/// rarity ladder for everything that drops.
enum Theme {
  static let accent = Color(hex: 0xFFF200)      // whatever is on
  static let control = Color(hex: 0xBDB3C6)     // buttons, raised off the ground
  static let ground = Color(hex: 0x26212B)      // the window behind everything
  static let ink = Color(hex: 0x1A161E)         // the text on any button
  static let sunken = Color(hex: 0x1D1922)      // panels and cards
  static let deep = Color(hex: 0x15121A)        // tracks, bars' empty part
  static let rule = Color(hex: 0x3B3443)        // separators, locked things
  static let grab = Color(hex: 0x5A5163)        // the clock's ring when paused
  static let text = Color(hex: 0xEDE7F0)
  static let dim = Color(hex: 0xB3AABB)        // 7:1 on the ground (Apple's guidelines, as Miderator)
  static let bright = Color(hex: 0xF7F3F9)
  static let warn = Color(hex: 0xE0485A)        // the dot on a tab with something waiting
  static let xp = Color(hex: 0x3D8EFF)          // the level bar: Rare's blue
  static let pass = Color(hex: 0xFF8A1C)        // the season track: Legendary's orange
  static let coin = Color(hex: 0xFFC83D)
  static let coinEdge = Color(hex: 0xB9862A)

  static func rarity(_ r: Int) -> Color { Color(hex: Rarity.info(r).colour) }

  static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }
  /// Prompts, slips and quotes are set in the serif: they are writing.
  static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .serif)
  }
}

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: alpha)
  }
  /// A banner's hue, kept clear of the accent's yellow.
  static func banner(_ h: Double, sat: Double = 0.62, bright: Double = 0.92) -> Color {
    var hue = h.truncatingRemainder(dividingBy: 1)
    if hue > 0.11 && hue < 0.2 { hue += 0.1 }
    return Color(hue: hue, saturation: sat, brightness: bright)
  }
}

enum Fmt {
  static func num(_ n: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: n.rounded(.down))) ?? String(Int(n))
  }
  static func num(_ n: Int) -> String { num(Double(n)) }

  /// 3725 seconds as "1h 2m"; under an hour "12m"; under a minute "40s".
  static func dur(_ s: Double) -> String {
    let s = max(0, Int(s))
    if s >= 86400 { return "\(s / 86400)d \(s % 86400 / 3600)h" }
    if s >= 3600 { return "\(s / 3600)h \(s % 3600 / 60)m" }
    if s >= 60 { return "\(s / 60)m" }
    return "\(s)s"
  }

  /// 432 seconds as "7:12".
  static func clock(_ s: Double) -> String {
    let s = max(0, Int(s.rounded(.up)))
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) }
    return String(format: "%d:%02d", s / 60, s % 60)
  }

  static func date(_ t: Int) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: Date(timeIntervalSince1970: TimeInterval(t)))
  }
}
