# 0011 - Progress is one file, read in an empty environment

The sister repos keep their settings in ExtState, one `key=value;` string.
The battle pass keeps much more: a vault of up to 400 ideas with their MIDI,
a stash of 60 items, quests, history. That is too much for ExtState, and it
is the user's progress rather than a preference, so it must survive anything.

So it is one file, `<resource>/Data/DAW Battle Pass/progress.lua`: the state
as a Lua table literal, keys sorted so the same state always writes the same
text. It is written to `.tmp` beside the old one, the old one is moved to
`.bak`, then the new one swapped in, so a crash mid-write never costs
anything. It is read with `load(..., "t", {})` - an empty environment - so a
damaged or tampered file can never run anything. A save that won't read is
copied aside as `.damaged-<time>` and the backup loaded. Settings that belong
to the window (none yet) would go in ExtState as the sister repos do.

Progress is never per project: the user asked for it to carry across every
project, so a project only contributes its name, for the stats.
