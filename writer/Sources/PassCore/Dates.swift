import Foundation

/// Days, weeks and seasons. A day starts at Rules.dayStartHour, so a session
/// past midnight counts for the day it began. A week is named for its
/// Monday; a season is a calendar month. The time is always passed in.
public enum Dates {
  /// The calendar every date is read with. Tests set a fixed time zone.
  public static var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone.current
    return c
  }()

  static func date(_ t: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(t)) }
  static func shifted(_ t: Int) -> Date { date(t - Rules.dayStartHour * 3600) }

  static func key(_ d: Date) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }

  public static func dayKey(_ t: Int) -> String { key(shifted(t)) }

  public static func weekKey(_ t: Int) -> String {
    let s = shifted(t)
    let wday = calendar.component(.weekday, from: s)          // 1 is Sunday
    let since = (wday - 2 + 7) % 7
    return key(calendar.date(byAdding: .day, value: -since, to: s)!)
  }

  static func keyTime(_ k: String) -> Date? {
    let parts = k.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
  }

  /// Whole days from one key to another; a huge number if either is blank.
  public static func daysBetween(_ a: String, _ b: String) -> Int {
    guard let ta = keyTime(a), let tb = keyTime(b) else { return Int.max / 4 }
    return Int((tb.timeIntervalSince(ta) / 86400).rounded())
  }

  static func startOfShiftedDay(_ t: Int) -> Date { calendar.startOfDay(for: shifted(t)) }

  static func atDayStart(_ d: Date) -> Date {
    calendar.date(bySettingHour: Rules.dayStartHour, minute: 0, second: 0, of: d) ?? d
  }

  public static func secsToNextDay(_ t: Int) -> Int {
    let next = atDayStart(calendar.date(byAdding: .day, value: 1, to: startOfShiftedDay(t))!)
    return max(0, Int(next.timeIntervalSince1970) - t)
  }

  public static func secsToNextWeek(_ t: Int) -> Int {
    let s = shifted(t)
    let wday = calendar.component(.weekday, from: s)
    let left = 7 - (wday - 2 + 7) % 7
    let next = atDayStart(calendar.date(byAdding: .day, value: left, to: startOfShiftedDay(t))!)
    return max(0, Int(next.timeIntervalSince1970) - t)
  }

  public static func seasonOf(_ t: Int) -> Int {
    let c = calendar.dateComponents([.year, .month], from: shifted(t))
    return Loot.seasonId(year: c.year!, month: c.month!)
  }

  public static func secsToNextSeason(_ t: Int) -> Int {
    let c = calendar.dateComponents([.year, .month], from: shifted(t))
    var y = c.year!, m = c.month! + 1
    if m > 12 { m = 1; y += 1 }
    let next = calendar.date(from: DateComponents(year: y, month: m, day: 1, hour: Rules.dayStartHour))!
    return max(0, Int(next.timeIntervalSince1970) - t)
  }

  /// The hour of the day (0-23) and the weekday (0 is Sunday) at a time.
  public static func hourAndWeekday(_ t: Int) -> (Int, Int) {
    let c = calendar.dateComponents([.hour, .weekday], from: date(t))
    return (c.hour!, c.weekday! - 1)
  }

  /// "2026-10-22" as "Thu 22".
  public static func shortDay(_ k: String) -> String {
    guard let d = keyTime(k) else { return k }
    let f = DateFormatter()
    f.calendar = calendar; f.timeZone = calendar.timeZone
    f.dateFormat = "EEE d"
    return f.string(from: d)
  }
}
