# 0018 - Apple's HIG Foundations, as far as a game board allows

The user asked for every repository to follow Apple's Human Interface
Guidelines, as Transient Shuffler does, and sent the 19 Foundations pages.
The family's ReaImGui windows took the full set (Midi Suggester's 0009). This
window is different: a game board drawn by hand at fixed positions, with
particles, shaking, flashing and toasts. So it took what fits it:

- **Words at 7:1.** Dim text `#B0B6C0`; each rarity gains a `text` colour, the
  same hue lightened to 7:1, for its name (`RT`), while its fill stays
  (`RC`); the pass's orange has `PASS_TEXT`. `test_ui` checks every opaque
  word on every page.
- **Reduce Motion**, a setting on the Stats page (`st.settings.reduceMotion`):
  no sparks, confetti, rings, twinkles, shaking, flashing or coin flights
  (`bp_fx`'s `fx.calm`); every eased entrance lands at its final size
  (`settle`), nothing pulses, bobs or spins (`wave`, `D.rays`), numbers fade
  where they appear. A script cannot read the system's Reduce Motion, so it is
  chosen here. Off by default, as the game's own character.
- **Toasts stay** until clicked or Esc, or until newer ones push them out (four
  at most). They used to fade after two to six seconds; Apple asks for nothing
  that goes away on a timer. A click on a toast goes no further.
- **The keyboard**: ReaImGui's keyboard navigation, its ring `#F2F4F7`, not
  the accent.

## Not taken, and why

- **Text Size and 28-point controls.** Every page is drawn at fixed
  coordinates, so larger text or taller buttons would collide. Doing it means
  laying every page out on a scale - a redesign, not a setting. Left for the
  user to ask for.
- **Messages at the top.** The Stats page's settings messages sit beside the
  setting they are about, which Apple's Writing page prefers; the game's own
  news comes as toasts at the top already.
- VoiceOver, Dynamic Type, Increase Contrast and right to left cannot be
  reached from a ReaImGui script.

Every rule was broken on purpose and a test failed, except "Reduce Motion
clamped to true/false" in `clampState`: `fill` already replaces a value of the
wrong type, so that line was dead and was removed.

## The final sweep (22 October 2026, version 1.2)

The two things "Not taken" above are taken now, with the rest of the family's
final sweep:

- **Text Size, 100-200%**, from a View menu and Cmd+= / Cmd+- / Cmd+0, saved.
  The board is laid out in points and drawn at the text size (`S`): one turn
  of every coordinate, in `D.*`, `dtext`, `at`, `hit` and `mouseIn`, so the
  pages needed no new layouts, only to lay out to `ui.pageW` and wrap their
  rows of buttons. A page too wide for the window scrolls. Fonts are made for
  each size, so 200% stays sharp.
- **Controls 28 points tall and 12 apart**, never narrower than their label;
  a chosen button carries an ink bar under its label.
- **Menus and tooltips a step lighter** (`#2A2F37`, edge `#3A404A`), menu
  keys `#BFC5CE` (7:1 on the menu), the scrollbar's grab and the resize grip
  in house greys at 3:1, every theme colour R < G < B; the name box, slider
  and ticks wear a 3:1 edge; toasts sit on the popup grey too.
- **No timers**: "Sure?" became "Click Again to Buy" (Salvage, Redeem,
  Delete) and waits until clicked again, Esc or another page - 0015's two
  steps without its three seconds.
- **Esc** lets go of the keyboard's place or a menu before it touches the
  stage, an armed button or the toasts. It still never closes the window
  (0009).
- **A minimum window** of 420 by 360 points, grown with the text; **the
  title** names the page or the celebration; **cut-short text** (a card, a
  toast) shows whole in a tooltip; button labels take title style.

Not taken: messages at the top (as above - news is already toasts at the
top); VoiceOver, Dynamic Type and Increase Contrast (unreachable). Every new
rule was broken on purpose with `tools/bite.sh` and the suite failed; the
first Esc test did not bite (it used the welcome, which Esc never closes) and
was moved to an armed button, where it does.
