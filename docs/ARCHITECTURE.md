# DAW Battle Pass: its architecture, and the decisions behind it

One page for the whole shape of the script and every big decision in it.
Each decision has its own record in [`decisions/`](decisions/README.md), with
the reasoning and what it costs; this page is the map.

## The shape

```
                         bp_theory   keys, scales, chord names
                         (Good Idea's, copied unchanged)
                             |
                             v
                         bp_loot     the dice, rarities, ideas, gear,
                             |       cosmetics, crates, the season track
                             v
   REAPER  <-->  bp_watch  ----->  bp_game     the rules: the clock, XP and
   (the only     signals,  events  (state,     levels, tiers, quests, check-in,
    file that    scans,             session)   shop, gear, achievements, saving
    calls it)    insert, files         |
                                       |  ss.notices: what just happened
                                       v
   ReaImGui <-->  DAW Battle Pass.lua  (the window: header, eight pages,
   (the only      the stage for rewards, the overlay)  <--  bp_fx
    file that                                               particles, toasts,
    calls it)                                               floating numbers
```

Each frame, the window:

1. asks `bp_watch` whether anything happened (`W.signals`) and what changed
   in the project (`W.scan`), and hands both to `bp_game`
   (`G.event`, `G.tick`);
2. every two seconds, lets `bp_game` turn the day, week or season and check
   achievements (`G.refresh`, `G.checkAchievements`);
3. turns `ss.notices` into rewards on the stage, toasts, flying coins and
   floating numbers (`handleNotices` - the only reader);
4. draws, and saves when something was bought, claimed or equipped, or
   every twenty seconds otherwise.

- **Four of the six files are pure Lua** - `bp_theory`, `bp_loot`, `bp_game`,
  `bp_fx` never touch `reaper.` or `ImGui.`, so they are tested in seconds.
  `bp_watch` is the only file that talks to REAPER; the window the only one
  that talks to ImGui.
- **Two kinds of state.** `st` is saved: everything the player owns and has
  done. `ss`, the session, lives only while the script runs: the idle clock,
  this session's active time, the notices, the session's dice.
- **Everything handed out is made, not stored.** 13 kinds of idea, gear for 6
  slots with 14 affixes and 10 powers, titles, banners: word lists and
  musical rules, at seven rarities.

## The decisions

### What it is

| | |
| --- | --- |
| [0001](decisions/0001-a-reascript-in-the-family-shape.md) | A ReaImGui ReaScript in the sister repos' shape - window, pure engines, mocks, ReaPack, house colours - after a first single-file `gfx` draft was dropped. |
| [0017](decisions/0017-released-through-reapack-pinned.md) | Released through ReaPack with every file pinned to a tested commit; never rename the script; merge, don't squash. |

### Time

| | |
| --- | --- |
| [0002](decisions/0002-active-time-not-wall-time.md) | Only active time counts: edits, transport, cursor, mouse (only with REAPER in front, given js_ReaScriptAPI), keys, the battle pass window. Idle after 3 minutes; 8 while playing back; never while recording. |
| [0003](decisions/0003-time-is-passed-in.md) | The rules never read a clock; the time is passed in, so tests run weeks in a second. |
| [0014](decisions/0014-seasons-are-months-days-start-at-4am.md) | A season is a calendar month with 100 tiers and endless bonus tiers; a day starts at 4am; a week is named for its Monday. |

### Progression

| | |
| --- | --- |
| [0004](decisions/0004-tiers-are-time-levels-are-actions.md) | Two tracks: the season pass fills with active time (a tier per 15 minutes, a big one per hour); the level bar with XP from everything, a crate per level. Editing XP capped at 120 a minute. |
| [0006](decisions/0006-gear-never-shortens-the-clock.md) | Gear rewards work - more XP, coins, loot, grace - and never makes a tier come faster. |
| [0013](decisions/0013-prices-from-a-simulated-economy.md) | About 575 coins an active hour, so a takeaway costs 2,500: about five hours of music. Prices are the user's to change. |

### Loot

| | |
| --- | --- |
| [0005](decisions/0005-rewards-are-made-from-a-seed.md) | Rewards are made from seeded dice (Park-Miller, as in Good Idea): a tier's reward depends only on season and tier, so the track can be shown in advance. Randomness only chooses among musically meaningful options. |
| [0007](decisions/0007-seven-rarities.md) | Seven rarities, Poor to Mythic. Rarer means richer, not just a different colour; Poor is real junk. |
| [0010](decisions/0010-plugin-quests-from-your-list-or-everything.md) | Plugin quests choose from the user's own list when there is one, everything installed (JSFX left out) when not. |

### Keeping what's earned

| | |
| --- | --- |
| [0008](decisions/0008-nothing-earned-is-lost.md) | A drop is granted the moment it is won and celebrated afterwards; unclaimed quests are claimed at the reset; a full stash sells its weakest item. A reward is announced before it is granted, so the stage plays in order. |
| [0011](decisions/0011-one-save-file-read-in-an-empty-room.md) | Progress is one Lua file in REAPER's Data folder, written atomically with a backup, read in an empty environment so it can never run anything. |

### The window

| | |
| --- | --- |
| [0012](decisions/0012-the-stage-replaces-the-page.md) | A reward replaces the page while it plays (nothing underneath can be clicked); particles and toasts float on the foreground draw list. |
| [0009](decisions/0009-escape-closes-a-celebration.md) | Escape skips a celebration and never closes the window - closing it stops the clock. |
| [0015](decisions/0015-sure-before-spending.md) | Anything that spends or destroys turns into a yellow "Sure?" for three seconds first. |

Colour has its own page, [`COLOUR.md`](COLOUR.md): the house scheme
unchanged, plus the rarity ladder, the XP blue, the pass orange and the coin
gold, all kept off the accent's yellow.

### Proving it

| | |
| --- | --- |
| [0016](decisions/0016-mocks-from-the-docs-and-tests-that-bite.md) | Six suites against a REAPER and a ReaImGui mocked from the documented signatures, run headless through the real script; `tools/bite.sh` breaks eight things on purpose to prove the tests notice. What it can't prove is how the window looks in REAPER. |

## Where to look

| To change | Look in |
| --- | --- |
| A reward, a word list, a rarity, gear | `bp_loot.lua` - then read `tools/demo.lua`'s output before and after |
| Prices, shop items | `G.SHOP` at the top of `bp_game.lua` |
| XP values, the tier length, the idle time | `G.XP`, `G.TIER_SECONDS`, `G.IDLE_SECONDS` in `bp_game.lua` |
| Quests, check-in rewards, achievements | `G.QUESTS`, `G.CHECKIN`, `G.ACHIEVEMENTS` in `bp_game.lua` |
| What counts as activity, what a scan sees | `W.signals`, `W.scan` in `bp_watch.lua` |
| How anything looks or moves | `DAW Battle Pass.lua` (drawing), `bp_fx.lua` (motion) |
