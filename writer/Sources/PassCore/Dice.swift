import Foundation

/// Park and Miller's generator, as Good Idea and DAW Battle Pass use: a seed
/// gives the same rewards on any machine.
public final class Dice {
  private var s: Int
  public init(_ seed: Int) {
    s = abs(seed) % 2147483646 + 1
    for _ in 0..<4 { _ = next() }
  }
  public func next() -> Double {
    s = s * 48271 % 2147483647
    return Double(s - 1) / 2147483646
  }
}
