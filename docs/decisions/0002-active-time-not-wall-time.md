# 0002 - Active time, not wall time

The point is to encourage longer music-making, so the clock must not run
while the user is away or in another app.

"Active" is: the project's change count moved, the transport changed, the
edit cursor moved, the mouse moved (only if REAPER is in front, when
js_ReaScriptAPI can tell us), a key was pressed (js again), or the mouse moved
over the battle pass itself. After `settings.idle` (3 minutes, adjustable 1-15)
with none of that, the clock stops. Playback gets at least 8 minutes, because
listening back is work; recording always counts.

The alternative - counting time with the project open - would reward leaving
REAPER open. The cost of this one: up to the idle time is counted after you
walk away. Taking it back afterwards would mean un-unlocking tiers, which is
worse than three generous minutes.

Without js_ReaScriptAPI, the mouse moving anywhere counts. That is a known
weakness, said plainly in the README.
