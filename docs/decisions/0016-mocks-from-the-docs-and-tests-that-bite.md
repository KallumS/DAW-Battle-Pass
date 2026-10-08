# 0016 - Tested against mocks written from the documentation, and proven to bite

Nothing here can run REAPER, so the family's approach is followed: a mocked
REAPER (`tests/reaper_mock.lua`, which grew from Midi Catalogue's) written
from the documented signatures, not from what the code calls, and raising on
anything it lacks; and a mocked ReaImGui in `test_ui.lua` that runs the real
script, checks every argument is a real number or colour, and that every push
is popped. Extension functions (js_ReaScriptAPI, SWS) answer nil unless a
test installs them, which is what REAPER does without the extension.

A test that cannot fail proves nothing, so `tools/bite.sh` breaks eight
things on purpose - idling switched off, the ink taken off the buttons,
tracks counted by number rather than GUID, a crate's guarantee, Streak
Freezes, the save's sandbox, the order of a crate and its level-up, key
spelling - and expects a suite to fail each time. Two of them did not bite
at first and the tests were tightened until they did.

What this cannot prove is how the window looks in REAPER. The first run in
REAPER is the real test of the drawing.
