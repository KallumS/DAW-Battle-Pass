#!/bin/sh
# Proves the tests bite: breaks the code on purpose, in a copy, and checks
# that the suite covering it fails. Every line here once passed when it
# should not have, or is a rule worth keeping honest.
#
#   tools/bite.sh
cd "$(dirname "$0")/.."
if command -v lua5.4 >/dev/null 2>&1; then RUN="lua5.4"; else RUN="lua"; fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

bad=0
bite() {   # file, text to replace, replacement, suite, what
  rm -rf "$WORK/x"; mkdir -p "$WORK/x"; cp -r reascripts tests "$WORK/x/"
  python3 - "$WORK/x/$1" "$2" "$3" <<'PY' || { echo "PATTERN GONE  $5"; bad=1; return; }
import sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
if a not in s: sys.exit(1)
open(p, "w").write(s.replace(a, b, 1))
PY
  if (cd "$WORK/x" && $RUN "tests/$4" >/dev/null 2>&1); then
    echo "DID NOT BITE  $5"; bad=1
  else
    echo "bites         $5"
  fi
}

bite reascripts/bp_game.lua 'local idle = (tp - ss.lastInput) > G.idleLimit(st, signals.playing)' 'local idle = false' \
     test_game.lua "idle never happens"
bite "reascripts/DAW Battle Pass.lua" '  ImGui.PushStyleColor(ctx, ImGui.Col_Text, INK)
  if disabled' '  ImGui.PushStyleColor(ctx, ImGui.Col_Text, TEXT)
  if disabled' test_ui.lua "buttons lose the dark ink"
bite reascripts/bp_watch.lua 'for g in pairs(now.tracks) do if not w.tracks[g] then n = n + 1; w.tracks[g] = true end end' \
     'for g in pairs(now.tracks) do n = n + 1 end; for g in pairs(w.tracks) do n = n - 1 end; w.tracks = now.tracks; if n < 0 then n = 0 end' \
     test_watch.lua "tracks counted by number rather than by GUID"
bite reascripts/bp_loot.lua 'if i == 1 then rr = L.rollRarity(rnd, r, L.MYTHIC, luck)' 'if i == 1 then rr = L.rollRarity(rnd, 1, L.MYTHIC, luck)' \
     test_loot.lua "a crate forgets its guaranteed rarity"
bite reascripts/bp_game.lua 'elseif c.last ~= "" and gap > 1 and gap - 1 <= (st.inv.tokens.freeze or 0) then' 'elseif false then' \
     test_game.lua "Streak Freezes ignored"
bite reascripts/bp_game.lua 'local fn = load("return " .. s, "progress", "t", {})' 'local fn = load("return " .. s, "progress", "t", _G)' \
     test_game.lua "a save file able to reach the system"
bite reascripts/bp_game.lua '  notice(ss, { kind = "crate", rarity = r, drops = drops })
  grantAll(st, ss, drops)' '  grantAll(st, ss, drops)
  notice(ss, { kind = "crate", rarity = r, drops = drops })' \
     test_ui.lua "a level-up jumps ahead of the crate that caused it"
bite reascripts/bp_loot.lua '      if not bestCost or cost < bestCost then best, bestCost = k, cost end' '      if not bestCost then best, bestCost = k, cost end' \
     test_loot.lua "keys spelled without minding their accidentals (Ab Phrygian's Bbb)"

exit $bad
