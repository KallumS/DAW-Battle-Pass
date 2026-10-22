import XCTest
@testable import PassCore

/// Thursday 8 October 2026, 8pm, in London.
let START: Int = {
  Dates.calendar.timeZone = TimeZone(identifier: "Europe/London")!
  return Int(Dates.calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 20))!.timeIntervalSince1970)
}()

func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Int {
  _ = START
  return Int(Dates.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!.timeIntervalSince1970)
}

/// A game with a clock that the test winds on.
final class Rig {
  let g: Engine
  var tp = 1000.0
  var epoch: Int
  init(_ epoch: Int = START) {
    self.epoch = epoch
    g = Engine(state: GameState(epoch: epoch), tp: tp, epoch: epoch)
    g.ss.rnd = Dice(42)
  }
  /// Runs the clock for `secs`, a tick a second. `every`: she does something
  /// every n seconds; nil for nothing at all.
  func run(_ secs: Int, every: Int? = 20) {
    for i in 1...max(1, secs) {
      tp += 1; epoch += 1
      g.tick(tp, epoch, Signals(input: every.map { (i - 1) % $0 == 0 } ?? false))
    }
  }
  func count(_ k: Notice.Kind) -> Int { g.ss.notices.filter { $0.kind == k }.count }
  func last(_ k: Notice.Kind) -> Notice? { g.ss.notices.last { $0.kind == k } }
}
