import Foundation

/// Saving: one JSON file, written to a temporary file first, the old one
/// kept as a backup, then swapped in. A damaged file is copied aside and the
/// backup read instead. Anything missing from an old save is filled in from
/// a fresh state, and nonsense is put right.
public enum Save {
  public static func encode(_ st: GameState) throws -> Data {
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys, .prettyPrinted]
    e.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "0", negativeInfinity: "0", nan: "0")
    return try e.encode(st)
  }

  static func isBool(_ x: Any) -> Bool {
    guard let n = x as? NSNumber else { return false }
    return CFGetTypeID(n) == CFBooleanGetTypeID()
  }

  /// Puts every field back inside what exists: missing ones from a fresh
  /// state, the wrong type replaced. Lists are kept as they are.
  static func fill(_ saved: Any?, _ def: Any) -> Any {
    if let d = def as? [String: Any] {
      guard var s = saved as? [String: Any] else { return def }
      for (k, v) in d { s[k] = fill(s[k], v) }
      return s
    }
    guard let saved = saved else { return def }
    if def is [Any] { return saved is [Any] ? saved : def }
    if def is String { return saved is String ? saved : def }
    if isBool(def) { return isBool(saved) ? saved : def }
    if def is NSNumber { return (saved is NSNumber && !isBool(saved)) ? saved : def }
    return saved
  }

  /// Reads a save, or nil if it can't be read at all.
  public static func decode(_ data: Data, epoch: Int = 0) -> GameState? {
    guard let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let defData = try? encode(GameState(epoch: epoch)),
          let def = try? JSONSerialization.jsonObject(with: defData) as? [String: Any] else { return nil }
    let merged = fill(saved, def)
    guard let mData = try? JSONSerialization.data(withJSONObject: merged),
          var st = try? JSONDecoder().decode(GameState.self, from: mData) else { return nil }
    clamp(&st)
    return st
  }

  public static func clamp(_ st: inout GameState) {
    while st.inv.crates.count < 7 { st.inv.crates.append(0) }
    if st.inv.crates.count > 7 { st.inv.crates = Array(st.inv.crates.prefix(7)) }
    st.inv.crates = st.inv.crates.map { max(0, $0) }
    st.level = max(1, st.level)
    st.coins = max(0, st.coins)
    st.xp = st.xp.isFinite ? max(0, st.xp) : 0
    st.settings.idle = min(1800, max(60, st.settings.idle.isFinite ? st.settings.idle : Rules.idleSeconds))
    if !st.cos.titles.indices.contains(st.profile.title) { st.profile.title = -1 }
    if !st.cos.banners.indices.contains(st.profile.banner) { st.profile.banner = -1 }
    if st.nextId < 1 { st.nextId = 1 }
  }

  /// Where the save lives: ~/Library/Application Support/Writing Battle Pass.
  public static func folder() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSHomeDirectory())
    return base.appendingPathComponent("Writing Battle Pass", isDirectory: true)
  }

  /// Writes atomically: .tmp, the old file to .bak, then the swap.
  public static func write(_ st: GameState, to url: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encode(st)
    let tmp = url.appendingPathExtension("tmp")
    let bak = url.appendingPathExtension("bak")
    try data.write(to: tmp)
    if fm.fileExists(atPath: url.path) {
      try? fm.removeItem(at: bak)
      try fm.moveItem(at: url, to: bak)
    }
    try fm.moveItem(at: tmp, to: url)
  }

  /// Reads the save. A damaged one is copied aside and the backup tried; if
  /// nothing can be read, a fresh state. `damaged` says whether that happened.
  public static func read(from url: URL, epoch: Int) -> (state: GameState, damaged: Bool) {
    let fm = FileManager.default
    guard fm.fileExists(atPath: url.path) else { return (GameState(epoch: epoch), false) }
    if let data = try? Data(contentsOf: url), let st = decode(data, epoch: epoch) { return (st, false) }
    let aside = url.deletingPathExtension().appendingPathExtension("damaged-\(epoch).json")
    try? fm.copyItem(at: url, to: aside)
    let bak = url.appendingPathExtension("bak")
    if let data = try? Data(contentsOf: bak), let st = decode(data, epoch: epoch) { return (st, true) }
    return (GameState(epoch: epoch), true)
  }
}
