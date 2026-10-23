# Building and changing Writing Battle Pass

A Swift package in `writer/`, built and tested on GitHub's Mac runners by
`.github/workflows/writer-mac.yml` - nobody needs a Mac or Xcode to change
it, and the Linux containers Claude works in can't compile it, so **CI is the
compiler**: push, then read the run.

| | |
| --- | --- |
| `Sources/PassCore/` | The game. Pure Swift, Foundation only, no AppKit or SwiftUI: dice, rarities, word lists, prompts, the wardrobe, loot, the rules (`Engine`), dates, saving. |
| `Sources/WritingBattlePass/` | The app: `Model` (runs the game twice a second), `Watcher` (typing, the front app, idle time), the window's pages, the stage, the FX, the menu bar, `Snapshots`. |
| `Tests/PassCoreTests/` | XCTest: dates, the clock, typing XP and its cap, words and sprints, quests, check-ins, the shop and her own treats, the wardrobe, gift boxes, seasons, achievements, saving; every prompt at every rarity; a **Demo** that prints a sample of everything and an **Economy** run that prints coins per hour and what each treat costs in hours. |
| `tools/make_app.sh` | `swift build -c release --arch arm64`, then the `.app` bundle, the icon (`sips` + `iconutil`), an ad-hoc signature and a `.dmg` with an Applications shortcut and `docs/INSTALL-MAC.txt` as "Read me first" (Miderator's packaging). |
| `tools/snapshots.sh` | Runs the built app with `--snapshots`: every page and celebration of a made-up save drawn to `build/snapshots/*.png`. |
| `Resources/` | `Info.plist` and the 1024px icon, drawn by `tools/draw_icon.py` (Pillow). |

| `tools/print_snapshots.sh` | Prints each snapshot into the CI log as a small base64 JPEG between `SNAP-BEGIN`/`SNAP-END` lines - Claude's containers can read job logs but not download artifacts. |

In snapshot mode pages are drawn without their ScrollView (the renderer
can't see into one), and text fields draw as a yellow "no" box: both are
the renderer's limits, not the app's.

CI uploads two artifacts: **Writing-Battle-Pass** (the .dmg to hand over) and
**snapshots** (the PNGs - look at them after any change to the window).
Pushing a tag `writer-v1.0` builds a release with the .dmg attached.

## Rules worth keeping

- **PassCore never imports AppKit or SwiftUI.** The time is always passed
  in (`tick(tp, epoch, signals)`), so the tests run weeks in a second.
- **New saved state goes in `GameState` with a default.** Old saves are
  filled in from a fresh state by `Save.fill` before decoding, so a new field
  never breaks a save.
- **Typing is counted, never recorded** (`KeyTap.handle`): letters, words and
  key presses leave the tap as three numbers. Keep it that way.
- **No gear stat ever shortens a tier** (DAW Battle Pass 0006), and typing
  XP stays small and capped (`Rules.xpLetter`, `Rules.letterXpCap`).
- Change any reward size and read the Economy line in the CI log before
  trusting the prices.
- Colours: `docs/COLOUR.md`. Text is at least 7:1 on what it sits on, and
  the Mac's Reduce Motion turns off particles, floating numbers, the gift
  box's wobble and the cards' spring (Miderator's 0048, borrowed: 0024).
- Rewards are clothes and kit, not frills (0023): `testRewardsAreNotFrilly`
  holds the line.
