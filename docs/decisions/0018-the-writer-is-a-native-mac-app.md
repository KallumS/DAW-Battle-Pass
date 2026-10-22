# 0018 - Writing Battle Pass is a native Swift Mac app, built by CI

A friend who writes asked for one. She doesn't use REAPER, so it had to be a
standalone app for an Apple silicon Mac.

Considered:

- **LÖVE (Lua game engine)** - would have reused `bp_loot` and `bp_game`
  almost as they are, and could be screenshotted in the Linux container. But
  counting typing in other apps, the menu bar, starting at login and text
  fields would all have been hand-rolled through LuaJIT's FFI, and it would
  never feel like a Mac app.
- **Swift with Lua embedded** - keeps the Lua rules, but every screen would
  need the state copied across a bridge as JSON and mirrored in Swift types.
- **Swift and SwiftUI throughout (chosen)** - the event tap, the front app,
  idle time, the menu bar, login items and text fields are all first-class.
  The rules were ported to a pure-Swift `PassCore` module, the same shape as
  the Lua engines (time passed in, notices out, nothing touching the UI).

The cost: the Linux containers Claude works in can't compile Swift for the
Mac, so GitHub Actions on `macos-15` (Apple silicon) is the compiler, the
test runner and the packager, and `--snapshots` draws every page so the look
can be checked from a PNG. The app is signed ad hoc (no paid Apple developer
account), so the first launch needs "Open Anyway" in Privacy & Security, and
Input Monitoring has to be granted again after an update.

It lives in `writer/` of this repo for now, on its own build; it can move to
a repo of its own whenever that's wanted.
