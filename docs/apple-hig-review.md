# Review against Apple's Human Interface Guidelines: Foundations

DAW Battle Pass checked against all 19 Foundations pages (the user's copy,
October 2026), as Transient Shuffler and the family's other windows were.
Recorded as [0018](decisions/0018-apples-hig-foundations.md).

This window is a game board drawn by hand inside a ReaImGui window: every
page is laid out at fixed coordinates, with particles, toasts and
celebrations on top. A script cannot reach VoiceOver, Dynamic Type, Increase
Contrast or the system's Reduce Motion. Where a guideline is not met, this
says so and why.

## What changed (1.1)

| Guideline | Before | Now |
| --- | --- | --- |
| **Accessibility, Dark Mode: contrast** | Dim text 4.7:1; rarity names in their fill colours, as low as 4.0:1 (Epic) and 4.6:1 (Rare, Mythic); the pass's orange 6.4:1. | Every word at least 7:1 on the ground: dim text `#B0B6C0`, each rarity's name in a lighter shade of its hue (`#8FBBFF`, `#C9A6FF`, `#FFA45C`, `#FF92C9`), the pass in `#FFA45C`. Fills, glows and icons keep their colours. |
| **Accessibility, Motion: Reduce Motion** | Sparks, confetti, rings, shaking, a full-window flash, bouncing entrances, pulsing glows, bobbing crates, sliding toasts. | **Reduce Motion** on the Stats page turns all of it off: no particles, shake or flash; entrances land at their final size; nothing pulses, bobs or spins; numbers fade where they appear; toasts appear without sliding. |
| **Accessibility: avoid time-boxed elements** | Toasts faded after two to six seconds, with a bar counting down. | Toasts stay until clicked or **Esc**; newer ones push the oldest out after four. A click on a toast goes no further. |
| **Accessibility: the keyboard alone** | Mouse only, apart from Enter and Esc on the stage. | Keyboard navigation is on: Tab and the arrow keys move between controls, Space or Return presses one, and a near-white ring shows where you are. |

## Already met

- **Design principles.** Nothing earned is lost (0008); anything that spends
  or destroys asks "Sure?" first (0015); Escape skips a celebration rather
  than closing the window, which would stop the clock (0009); a reward
  replaces the page while it plays, so nothing underneath is clicked by
  mistake (0012).
- **Feedback.** Every action is answered: a toast, a counter rolling, a
  celebration.
- **Colour.** One meaning per colour: yellow is *on*, a rarity colour is that
  rarity, red is *something is waiting*, gold is a coin. Rarities are named in
  words as well as coloured, so colour is never the only sign.
- **Dark Mode.** Always dark, the house scheme; Apple allows a dark-only
  appearance for media apps.
- **Writing.** Plain words, sentence-case messages, buttons that say what they
  do.
- **Privacy.** Everything stays on the computer, in one save file in REAPER's
  Data folder; nothing is sent anywhere. It reads which plugins you use and how
  long you work, only to make quests and count time.
- **Inclusion.** No assumptions about who plays; the name is yours to type.

## Not met, and why

- **Text Size up to 200% and 28-point controls.** Every page is drawn at fixed
  coordinates, so larger text or taller buttons would collide. It needs every
  page laid out on a scale - a redesign rather than a setting. Text is 10 to 14
  points (Apple's Mac minimum is 10).
- **The system's Reduce Motion** cannot be read by a script, so it is a
  setting here, off by default.
- **VoiceOver, Voice Control and Switch Control** cannot read a ReaImGui
  window; **Dynamic Type and Increase Contrast** cannot be read from a script.
- **Right to left.** English only.

## Not relevant

Materials, app icons, SF Symbols, images, spatial layout and immersive
experiences: the window draws its own icons and has none of these.

## Unverified in REAPER

Nothing in this window has run in REAPER yet; the mocks are written from the
documented signatures. Keyboard navigation over a hand-drawn page reaches the
real buttons only, not the cards and crates drawn on the draw list.

## Checked by

`tests/test_fx.lua`: a calm `fx` makes no particles, shake, flash, bump or coin
flight and its numbers stay put; toasts stay two minutes, are dismissed one at
a time or all, and never number more than four. `tests/test_game.lua`: the
setting defaults off and only true stays true. `tests/test_ui.lua`: keyboard
navigation and its ring; every opaque word on every page 7:1; a crate opened
with Reduce Motion draws no sparks (60+ circles a frame without it, under 30
with); the setting saved; a toast still there a minute later, gone on a click
and on Esc. Each rule was broken on purpose and the suite failed.

## Final sweep (22 October 2026, version 1.2)

One verdict per checklist item that applies to this window (from the
Accessibility, Color, Dark Mode, Layout, Motion, Typography and Writing pages).

| Item | Verdict |
| --- | --- |
| Text can be made at least twice as big (Accessibility, Typography) | Fixed now: Text Size 100-200%, View menu and Cmd+= / Cmd+- / Cmd+0, saved; the whole board scales |
| Controls 28 points tall, 12 apart (Layout) | Fixed now (`pushSize`) |
| Buttons never narrower than their label | Fixed now (`fit` in `pick`) |
| Nothing cut off or past the window's edge at 200% (Layout) | Fixed now: rows wrap, pages lay out to their width or scroll; tested at 100% and 200%, roomy and smallest |
| Truncated text available in full | Fixed now: a cut-short card or toast shows whole in a tooltip |
| Minimum window size | Fixed now: 420 by 360 points, grown with the text |
| Popups and menus lighter than the window (Dark Mode) | Fixed now: `#2A2F37`, edge `#3A404A`; toasts too |
| Menu key labels 7:1 | Fixed now: `#BFC5CE` |
| Non-text contrast 3:1 (scrollbar, frames, marks) | Fixed now: grab `#6D7581`, boxes and sliders edged, `MARK` for meaning without words |
| Every grey blue-shifted; no ImGui defaults (menu bar, headers, resize grip) | Fixed now, checked by `test_ui` |
| Colour never alone for "chosen" | Fixed now: an ink bar under a chosen button |
| No time limits | Fixed now: "Click Again to ..." no longer gives up after three seconds |
| Esc lets go of focus or a menu first | Fixed now; Esc still never closes the window (0009) |
| Window title names what is shown | Fixed now: "DAW Battle Pass — Quests", or the celebration |
| Ask before something is spent or thrown away | Met: `sure()` (0015) |
| Reduce Motion; no flashes over three a second | Met in 1.1 |
| Keyboard navigation, its own ring | Met in 1.1 |
| Words 7:1 | Met in 1.1; checked again at every size |
| Writing: title-style buttons | Fixed now ("Check In", "Let's Go", "Not Now") |
| Messages at the top until dismissed | User's decision (0018): news is toasts at the top, which stay; settings messages sit by their setting |
| VoiceOver, Dynamic Type, Increase Contrast, system Reduce Motion | Not possible from a ReaImGui script |
| Hit targets for drawn things (crates, tiers) | Met: invisible buttons over them, their drawn size, reachable by Tab |

Checked by `tests/test_ui.lua` (the family's `tests/hig_mock.lua`, the title,
the smallest window, overflow at both sizes, Esc, no timer, the theme) and
`tools/bite.sh`. **Unverified in REAPER**: how the scaled board looks at
125-200%, the fonts made per size, the menu bar, and Cmd+= reaching the window.
