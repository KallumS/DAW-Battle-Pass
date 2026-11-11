# 0019. An Ableton device that plays the game on Middaw's Lua

Taken 2026-11-10. Stands.

## Context

The user is moving from REAPER to Ableton Live and asked for every family REAPER project as Max for Live, each on its own branch. The window is ReaImGui and the watcher is REAPER's API, which Max has no equivalent of; the engine is pure Lua, and Max 9 runs modern JavaScript (`[v8]`, `[v8ui]`).

## Decision

`ableton/` holds a Max for Live device that runs the game unchanged on Middaw's Lua 5.4 runtime, through Middaw's host, as Middaw's own Battle Pass window does. `ableton/battlepass.js` is what is new: a panel (tier, level, coins, check-in, quests, crates) in the house palette, and the watch, which does what `bp_watch.lua` does with the Live Object Model - a scan every two seconds that turns new tracks, clips, devices, notes, locators and recorded clips into the game's events, and a tick every second saying whether anyone is there.

The save is the musician's, so it goes in a file beside the device as well as with the set.

## Consequences

- `ableton/kit/` is copied into every family repository with a device; `VENDORED.md` there records where each part came from.
- The bundle is built, not hand-written, and `tools/test.sh` fails when it is stale.
- Nothing here has been opened in Live. The tests run the device in Node on a stand-in for Max and the Live Object Model.

## 11 November 2026: Live's colours

The user asked for the Ableton versions to look like Ableton, and pointed to the Ableton-inspired scheme the family had tried: Starting Blocks' window themed after Live 8 on 18 September 2026 (commit 2765b0a3), neutral greys with a warm amber accent, replaced the same day by the yellow house scheme. The devices now draw in that scheme (`ableton/kit/palette.js`), with two changes so the family's rules hold: the chrome is #3E3E3E rather than #4A4A4A, because on the lighter grey a secondary word cannot reach 7:1 and still look secondary; and the buttons are light grey with dark ink, because light words on its #5E5E5E buttons reach only 5:1. The greys are neutral, as Live's are, not blue-shifted as the house scheme's.

Everything the device draws goes through `UI.C`, which is the palette. The REAPER version keeps the house scheme. `kit/test/palette_suite.js` holds the contrast, and was checked by breaking each rule.
