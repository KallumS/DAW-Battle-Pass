# DAW Battle Pass

A ReaScript that turns time spent making music in REAPER into a game: a
season pass whose tiers unlock every fifteen *active* minutes (a big one each
hour), XP and levels from everything you do, loot crates, coins for a shop of
permission slips (a takeaway, a movie, a gaming session), daily check-ins,
daily and weekly quests (some naming your own plugins), Diablo-style gear,
achievements, and endless procedurally made rewards from Poor to Mythic.
ReaImGui for the window. **The user is a musician, not a programmer -
explain in those terms.**

Built in the same shape as its sister repos (Good Idea, Midi Catalogue,
Starting Blocks, Midi Suggester, Midi Variator, ScaleView for REAPER). When in
doubt, do what Midi Catalogue does.

## Shape of it

| | |
| --- | --- |
| `reascripts/DAW Battle Pass.lua` | The window and the wiring. ReaImGui lives only here: the header, eight pages, the reward stage, the particle and toast overlay. |
| `reascripts/bp_theory.lua` | Keys, scales and chord names: Good Idea's theory (so ScaleView's and Starting Blocks' tables), copied unchanged, cut down. |
| `reascripts/bp_loot.lua` | Everything handed out: the dice, the rarity ladder, the idea generators, gear, cosmetics, crates, the season and its track. |
| `reascripts/bp_game.lua` | The rules: state and saving, the idle-aware clock, XP and levels, tiers, quests, check-in, shop, gear, achievements. |
| `reascripts/bp_fx.lua` | Particles, floating numbers, toasts, flash and shake, colour arithmetic. Positions only; the window draws them. |
| `reascripts/bp_watch.lua` | Everything that touches REAPER: activity signals, project scans, putting ideas into the project, files, autostart. |
| `tools/demo.lua` | Every kind of reward at every rarity, printed. **Read it before and after changing a generator or word list.** |
| `tools/bite.sh` | Breaks the code on purpose in a copy and checks a suite fails. |
| `docs/decisions/` | Why things are the way they are, one file per decision. |
| `docs/sessions/` | What happened in a session, written at the end of it. |

**`bp_theory`, `bp_loot`, `bp_game` and `bp_fx` never touch `reaper.` or
`ImGui.`** They take plain tables and return plain tables. `bp_watch`
touches REAPER but not ImGui. Engines are loaded with `dofile(...).init(x)`,
handed what they need (`L.init(T)`, `G.init(L)`, `W.init(G)`).

## The ideas that hold it up

- **The time is always passed in** ([0003](docs/decisions/0003-time-is-passed-in.md)).
  `G.tick(st, ss, tp, epoch, signals)`: `tp` is `time_precise()` (idle, dt),
  `epoch` is `os.time()` (days, weeks, seasons). A day starts at 4am
  (`G.DAY_START_HOUR`). Tests run weeks in a second.
- **Active time, not wall time** ([0002](docs/decisions/0002-active-time-not-wall-time.md)).
  `W.signals` says whether anything happened: the project change count,
  transport, edit cursor, mouse (only while REAPER is in front, if
  js_ReaScriptAPI can say), keys (js), or the mouse over our own window. No
  input for `settings.idle` (3 min) plus gear's `grace` means idle; playback
  allows at least `G.IDLE_PLAYING` (8 min); recording always counts. `dt` is
  capped at a second.
- **Two tracks** ([0004](docs/decisions/0004-tiers-are-time-levels-are-actions.md)):
  the season pass fills with active time only (`G.TIER_SECONDS`); levels fill
  with XP from actions and time. **No gear stat or power ever shortens a
  tier** ([0006](docs/decisions/0006-gear-never-shortens-the-clock.md)).
- **A tier's reward is a function of season and tier**
  ([0005](docs/decisions/0005-rewards-are-made-from-a-seed.md)):
  `L.tierRewards(season, tier, ilvl)`, Park-Miller dice seeded by
  `L.seedOf("tier", season, tier)`, so the track can be previewed. Live drops
  (crates, deals) use `ss.rnd`. Gear's item level is the player's level when
  made.
- **Nothing earned is lost** ([0008](docs/decisions/0008-nothing-earned-is-lost.md)).
  A drop is granted the moment it is won and the window animates it after;
  finished quests left unclaimed are claimed when the day or week turns; the
  stash, when full, sells its weakest item rather than refusing. A tier or
  crate notice is pushed **before** its drops are granted, so a crate opens
  before the level-up its contents cause.
- **The window learns what happened from `ss.notices`**: `tier`, `crate`,
  `level`, `checkin`, `redeem`, `season` become modals (the "stage", drawn in
  place of the page); `quest`, `ach`, `toast`, `purchase`, `idle`, `active`,
  `equip` become toasts; `claim` and `coins` become flying coins and
  floating numbers. `handleNotices` is the only reader.

## The loot

Seven rarities, `L.RARITY`: Poor, Common, Uncommon, Rare, Epic, Legendary,
Mythic ([0007](docs/decisions/0007-seven-rarities.md)). `L.rollRarity(rnd,
min, max, luck)`: luck compounds each step up. A rarer idea is a richer one
(more chords, sevenths, borrowed chords, applied dominants, a lift; more bars;
more parts to the brief). Poor ideas are deliberately the grey junk.

Ideas are in `L.IDEAS` (`id`, `label`, `icon`, `weight`, `midi`, `make(rnd,
r)` returning `{ text, sub, data }`). `data.block` (`{ name, beats, notes = {
start, len, pitch, vel } }` in quarter notes) is MIDI the window can insert;
`data.sections` regions; `data.bpm` a tempo. **Add a kind there and the
window, the vault filters, the demo and the tests pick it up.**

Key spelling: `keyFor(pc, scale)` takes the root spelling with the fewest
accidentals (Good Idea's `T.transpose` rule) - Ab Phrygian would need Bbb,
so it is G# Phrygian. Chord names come from Starting Blocks' table
(`T.symbolOf`); `spell` never writes a double flat or sharp.

Gear (`L.makeGear`): a slot's base, the slot's implicit stat, `AFFIX_COUNT`
affixes by rarity (no affix twice, never the implicit again), a power on
Legendary and Mythic. Names: Poor "Cracked X", Uncommon prefix or suffix, Rare
both, Epic two words, Legendary "Name's Base", Mythic "Name, Epithet".
`G.bonus(st, stat)` sums what's equipped; `G.hasPower(st, id)`.

## Saving

One file, `<resource>/Data/DAW Battle Pass/progress.lua`: the state as a Lua
table literal (`G.serialize`, keys sorted, `_`-prefixed keys skipped). Read
with `load(..., "t", {})` - an empty environment, so a save cannot reach
anything. Written to `.tmp`, the old file moved to `.bak`, then swapped in.
A damaged save is copied to `.damaged-<time>` and the backup loaded.
`G.clampState` fills anything missing from `G.newState` and puts nonsense
right. **New state goes in `G.newState`**; old saves pick it up from there.

## ReaImGui

The sister repos' rules: loaded with `ImGui_GetBuiltinPath` and
`dofile(...)("0.9")`; every `PushID` has its `PopID`, every
`PushStyleColor`, `PushFont` and `BeginDisabled` its pop; the theme is pushed
before `Begin` and popped after `End`, outside the `visible` test. `End` and
`EndChild` only when `Begin`/`BeginChild` returned true.

Pages draw on the window's draw list in screen coordinates and place real
buttons with `SetCursorScreenPos`; `finish(x, y)` leaves a `Dummy` so the
page child scrolls. The particle and toast overlay is on
`GetForegroundDrawList`. Text on the draw list goes through `dtext`/`wrap`
with the four attached fonts (`FONT.body/bold/big/huge`), measured with
`PushFont` + `CalcTextSize` scaled to the size drawn. A modal replaces the
page child entirely, so nothing underneath can be clicked.

**Escape closes a celebration, not the window**
([0009](docs/decisions/0009-escape-closes-a-celebration.md)) - unlike the
sister repos. Closing the window stops the clock, which here costs progress.

`sure(id, label)` is the two-step button for anything that spends or
destroys: the first click turns it into a yellow "Sure?" for three seconds.

## Colour

The house scheme, unchanged, plus a game's colours kept off the accent's hue:
see `docs/COLOUR.md`. Every button wears the dark ink. The yellow accent is
still only for what is on: the chosen tab or filter, the clock while it is
running, a claimable quest, an active XP Boost.

## REAPER, from a script

Every `reaper.` call is listed, with its documented signature, in
`tests/reaper_mock.lua`. Not yet checked against the REAPER API page the user
uploaded for the sister repos (REAPER 7.79) - do that when it is to hand, and
fix the mock from the page, never from the code.

- `TimeMap_GetTimeSigAtTime` returns `num, denom, tempo` - no retval first.
- `CountProjectMarkers` returns `retval, num_markers, num_regions`.
- `TrackFX_GetNamedConfigParm(tr, i, "fx_name")` gives a plugin's real name
  when the user has renamed it; `TrackFX_GetFXName` is the fallback.
- `EnumInstalledFX(i)` returns `retval, name, ident` (REAPER 6.37+).
- `GetProjectName(proj, "")`: the second argument keeps older REAPERs happy.
- js_ReaScriptAPI and SWS functions are reached only through `W.ext(name)`;
  the mock answers nil for them unless a test installs them.
- `CreateNewMIDIItemInProj(track, t0, t1, false)`: seconds, not QN.
- `set_action_options(1)`: running the action again ends the script.

## Tests

```
tools/test.sh      # all six suites
tools/bite.sh      # every line should say "bites"
```

| | |
| --- | --- |
| `test_theory.lua` | The copied tables still match the family's; spelling and numerals. |
| `test_loot.lua` | Thousands of rewards, rule by rule (reported once each, with a count and an example): every idea at every rarity, MIDI blocks in range, chords, drums, melodies in key, gear affixes, crates, the season track. |
| `test_game.lua` | The clock and idling, tiers, levels, the XP cap, events, plugin matching, quests, rerolls, resets, check-in streaks and freezes, the shop, deals, crates, gear, achievements, seasons, saving. |
| `test_fx.lua` | Particles live and die, coins land, toasts expire, colour arithmetic. |
| `test_watch.lua` | Signals, scans (GUIDs, undo/redo, takes, project switches), insert, regions, tempo, plugin lists, atomic saves and backups, autostart. |
| `test_ui.lua` | The real script against a mocked ReaImGui: the welcome, the check-in, a crate opened, every button on every page (twice, once with a full inventory), an hour of music, buying and redeeming a takeaway, equipping gear, saving, restarting, a damaged save. |

A fresh container has no Lua: `apt-get install -y lua5.4`
(`tools/run_lua.py` runs the suites through lupa otherwise).

## Releasing

`index.xml` is the ReaPack index. Each `<version>` pins every file to a
commit hash, so a release is: commit the code, then add a new `<version>`
block pointing at that commit. Never edit an existing one. ReaPack keys a
package by its name, so do not rename `DAW Battle Pass.lua`. **Merge rather
than squash** a release's pull request, or the pinned commit is not on
`main`.
