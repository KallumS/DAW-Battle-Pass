# Handover

The prompt to start a fresh session with. Paste everything under the line.
Update it at the end of a session if the next steps have changed.

---

I'm continuing work on **DAW Battle Pass**, a ReaScript for REAPER in my repo
`KallumS/DAW-Battle-Pass`. The work so far is on the branch
`claude/reaper-battle-pass-u6bb3m` (not yet merged to `main`); build on that
branch.

It's a battle pass for making music: every 15 minutes of active work unlocks
a tier of a monthly season pass (a big one every hour), actions earn XP and
loot crates, coins buy permission passes (takeaway, movie, gaming) in a shop,
and there are daily check-ins, daily and weekly quests, Diablo-style gear,
achievements and endlessly generated rewards from Poor to Mythic. It's built
in the same shape as my other repos (Good Idea, Midi Catalogue, Starting
Blocks, ScaleView): ReaImGui window, pure-Lua engine files, tests against
mocked REAPER and ReaImGui, ReaPack index, house colours.

I'm a musician, not a programmer, so please explain things in plain terms.

**Before doing anything, read these in the repo, in this order:**
1. `CLAUDE.md` - how the code is laid out and the rules that are easy to break
2. `docs/ARCHITECTURE.md` - every big decision on one page
3. the latest log in `docs/sessions/` - especially "Not done yet"

**Setting up:** the container has no Lua: `apt-get install -y lua5.4`. Then
`tools/test.sh` should pass all six suites and `tools/bite.sh` should say
"bites" on every line. Commit and push early and often - a container
restarted mid-session last time.

**Where it stands:** version 1.0 is written and fully tested against mocks,
but it has **never been run inside REAPER**. I'm about to try it (or have
tried it) and will tell you what I see. Expect small fixes in the drawing:
the draw list calls, the fonts, the foreground draw list.

**What I'd like to do next** (I'll say which):
- Fix whatever goes wrong on the first real run in REAPER. When something is
  fixed, make the test fail on the old code first, and correct the mocks
  from the ReaImGui / REAPER API docs, never from what the code expects.
- Check every `reaper.` call against the REAPER API functions page (I can
  upload it, as I did for the other repos).
- Open a pull request to `main` (merge, don't squash, so the commit pinned
  in `index.xml` stays on `main`), and release new versions through
  `index.xml` the way `CLAUDE.md` describes.
- Ideas not started: a preview image for the README, sound effects, my own
  plugin list for the quests.

At the end of the session, write a new log in `docs/sessions/`, add a
decision record for any choice that could reasonably have gone the other
way (and list it in `docs/ARCHITECTURE.md`), keep `CLAUDE.md` true, and
update this handover if the next steps have changed.
