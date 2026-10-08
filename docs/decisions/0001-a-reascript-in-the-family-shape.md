# 0001 - A ReaScript with ReaImGui, in the family's shape

The first draft was a single file drawing with REAPER's `gfx`. It would have
installed by copying one file, and needed no extension.

Then the user pointed at their other repos. Every one is a ReaImGui
ReaScript: the window in one file, pure-Lua engines beside it loaded with
`dofile(...).init()`, tests against a mocked REAPER and ImGui, a ReaPack
index, the house colours. The user already has ReaImGui, ReaPack installs the
six files as one package, and ReaImGui's draw list does everything the
animations need (filled shapes, paths, clip rects, scaled fonts) with real
anti-aliasing - `gfx` has no clipping and no rounded fills.

So it is built like Midi Catalogue: `bp_theory`, `bp_loot`, `bp_game`,
`bp_fx` pure; `bp_watch` the only file that talks to REAPER; the window the
only file that talks to ImGui.
