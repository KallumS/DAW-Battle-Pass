import AppKit
import CoreGraphics

/// Everything that watches the Mac: typing (counted, never recorded), which
/// app is in front, and how long since the mouse or keyboard was touched.
///
/// Typing is counted with a listen-only event tap, which needs the Input
/// Monitoring permission. Only three numbers leave the tap - letters, words
/// and keys pressed. What was typed is never kept, stored or sent anywhere.
/// Without the permission the clock still runs on mouse and keyboard
/// activity in her writing apps; only the letters go uncounted.
enum KeyTap {
  static var letters = 0
  static var words = 0
  static var keys = 0
  static var inWord = false
  static var tap: CFMachPort?
  static var source: CFRunLoopSource?

  static var running: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

  /// Starts counting if the Mac allows it. Returns whether it is counting.
  @discardableResult
  static func start() -> Bool {
    if running { return true }
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                    eventsOfInterest: mask, callback: keyTapCallback, userInfo: nil) else { return false }
    tap = t
    source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: t, enable: true)
    return true
  }

  static func handle(_ type: CGEventType, _ event: CGEvent) {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
      return
    }
    guard type == .keyDown else { return }
    keys += 1
    let flags = event.flags
    if flags.contains(.maskCommand) || flags.contains(.maskControl) { return }
    // Holding a key down doesn't write anything.
    if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }
    var len = 0
    var chars = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &chars)
    guard len > 0, let scalar = Unicode.Scalar(chars[0]) else { return }
    let ch = Character(scalar)
    if ch.isLetter || ch.isNumber {
      letters += 1
      inWord = true
    } else if ch == "'" || ch == "\u{2019}" || ch == "-" {
      // don't, well-known: still the same word
    } else if inWord && (ch.isWhitespace || ch.isPunctuation || ch.isNewline) {
      words += 1
      inWord = false
    }
  }

  /// What's been counted since the last call.
  static func take() -> (letters: Int, words: Int, keys: Int) {
    defer { letters = 0; words = 0; keys = 0 }
    return (letters, words, keys)
  }

  static var permitted: Bool { CGPreflightListenEventAccess() }

  /// Asks for Input Monitoring: the Mac's own prompt the first time, and the
  /// right page of System Settings after that.
  static func ask() {
    if !CGRequestListenEventAccess() {
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
        NSWorkspace.shared.open(url)
      }
    }
  }
}

private let keyTapCallback: CGEventTapCallBack = { _, type, event, _ in
  KeyTap.handle(type, event)
  return Unmanaged.passUnretained(event)
}

struct FrontApp: Equatable {
  var id: String
  var name: String
}

enum Watch {
  static let me = Bundle.main.bundleIdentifier ?? "com.kallums.writingbattlepass"

  static func front() -> FrontApp? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    return FrontApp(id: app.bundleIdentifier ?? app.localizedName ?? "?", name: app.localizedName ?? app.bundleIdentifier ?? "?")
  }

  /// Seconds since anything was touched: mouse, trackpad or keyboard. Needs
  /// no permission.
  static func secondsSinceInput() -> Double {
    let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .keyDown, .leftMouseDragged, .flagsChanged]
    return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 1e9
  }

  /// Apps with a window that she might write in, for Settings.
  static func runningApps() -> [FrontApp] {
    NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != me }
      .compactMap { a in a.bundleIdentifier.map { FrontApp(id: $0, name: a.localizedName ?? $0) } }
  }
}
