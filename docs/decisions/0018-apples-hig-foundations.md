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
