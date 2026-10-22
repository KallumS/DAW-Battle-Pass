import Foundation

/// The dice: Park and Miller's generator, the one Good Idea and DAW Battle
/// Pass use, so a seed gives the same reward on any machine. That is what
/// lets the season track show its rewards before they are reached: a tier's
/// reward is a function of the season and the tier, nothing else.
public final class Dice {
  private var s: Int

  public init(_ seed: Int) {
    s = abs(seed) % 2147483646 + 1
    for _ in 0..<4 { _ = next() }
  }

  /// A number from 0 up to (not including) 1.
  public func next() -> Double {
    s = s * 48271 % 2147483647
    return Double(s - 1) / 2147483646
  }

  public func between(_ lo: Int, _ hi: Int) -> Int {
    lo + Int(next() * Double(hi - lo + 1))
  }

  public func chance(_ p: Double) -> Bool { next() < p }

  /// One word from a word list (not generic, so long sentences built from
  /// many picks type-check quickly).
  public func word(_ list: [String]) -> String { pick(list) }

  public func pick<T>(_ list: [T]) -> T {
    list[min(list.count - 1, Int(next() * Double(list.count)))]
  }

  /// Picks from (weight, value) pairs.
  public func weighted<T>(_ list: [(Double, T)]) -> T {
    let total = list.reduce(0) { $0 + $1.0 }
    var x = next() * total
    for e in list {
      x -= e.0
      if x <= 0 { return e.1 }
    }
    return list[list.count - 1].1
  }

  public func shuffled<T>(_ list: [T]) -> [T] {
    var t = list
    if t.count < 2 { return t }
    for i in stride(from: t.count - 1, through: 1, by: -1) {
      let j = Int(next() * Double(i + 1))
      t.swapAt(i, j)
    }
    return t
  }
}

/// A seed from any mix of numbers and strings, so "season 10, tier 37" is
/// always the same dice.
public func seedOf(_ parts: CustomStringConvertible...) -> Int {
  var h = 5381
  for p in parts {
    for b in p.description.utf8 { h = (h * 33 + Int(b)) % 2147483629 }
    h = (h * 33 + 7) % 2147483629
  }
  return h + 1
}

/// "a" before a consonant, "an" before a vowel, wherever a word list put it.
public func articles(_ s: String) -> String {
  var out = ""
  let chars = Array(s)
  var i = 0
  while i < chars.count {
    let c = chars[i]
    let startOfWord = i == 0 || !(chars[i - 1].isLetter || chars[i - 1].isNumber)
    if (c == "a" || c == "A") && startOfWord && i + 2 < chars.count && chars[i + 1] == " "
        && "AEIOUaeiou".contains(chars[i + 2]) {
      out.append(c); out.append("n")
    } else {
      out.append(c)
    }
    i += 1
  }
  return out
}

public func plural(_ w: String) -> String {
  if w.hasSuffix("s") { return w }
  if w.hasSuffix("y"), let before = w.dropLast().last, !"aeiou".contains(before) {
    return String(w.dropLast()) + "ies"
  }
  return w + "s"
}

/// Joins clauses into sentences: ". " between them, except after a quote
/// that already ends with its own full stop, question or exclamation mark.
public func sentences(_ parts: [String]) -> String {
  var out = ""
  for (i, p) in parts.enumerated() {
    if i > 0 {
      let ended = out.hasSuffix(".\u{201D}") || out.hasSuffix("?\u{201D}") || out.hasSuffix("!\u{201D}")
      out += ended ? " " : ". "
    }
    out += p
  }
  return out
}

/// The first letter in capitals.
public func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

/// Rounds half up to a whole number, as Lua's math.floor(x + 0.5) did.
public func roundHalf(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }
