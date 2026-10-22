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

# The final sweep of Apple's Foundations (0018, 21 October 2026).
UI="reascripts/DAW Battle Pass.lua"
bite "$UI" '  ui.pageW = math.max(260, w / S)' '  ui.pageW = math.max(260, w)' \
     test_ui.lua "pages laid out in pixels, not points: they run off the window at 200%"
bite "$UI" '    if i > 1 and cx + bwid > x + w then cx, cy = x, cy + 28 + 12 end' '    if false then end' \
     test_ui.lua "rows of buttons that never wrap"
bite "$UI" '  return math.max(px(width or 0), select(1, ImGui.CalcTextSize(ctx, text)) + px(16))' '  return px(width or 0)' \
     test_ui.lua "a button narrower than its label at 200%"
bite "$UI" '    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), x1 + px(8), y2 - px(5), x2 - px(8), y2 - px(3), INK)' '' \
     test_ui.lua "a chosen button shown by colour alone"
bite "$UI" '  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, px(8), 7.5 * S)' '  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, px(8), 4 * S)' \
     test_ui.lua "controls shorter than 28 points"
bite "$UI" '  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, px(12), px(12))' '  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, px(8), px(8))' \
     test_ui.lua "controls closer than 12 points"
bite "$UI" '    setTextSize(cur - 1); saveSoon()
  elseif' '    saveSoon()
  elseif' test_ui.lua "Cmd+- does nothing"
bite "$UI" '  if st then st.settings.textSize = i end' '' \
     test_ui.lua "the text size forgotten"
bite "$UI" '     and not ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId)' '' \
     test_ui.lua "Esc with a menu open goes past the menu"
bite "$UI" '  return ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) and not ImGui.IsAnyItemFocused(ctx)' '  return ImGui.IsKeyPressed(ctx, ImGui.Key_Escape)' \
     test_ui.lua "Esc with a control focused goes past it"
bite "$UI" '  local armed = ui.confirm.id == id' '  if ui.confirm.id == id and not ui.confirm.t then ui.confirm.t = ui.tp end
  local armed = ui.confirm.id == id and ui.tp - ui.confirm.t < 3' \
     test_ui.lua "Click Again gives up on a timer"
bite "$UI" 'windowTitle() .. "###" .. TITLE' 'TITLE .. "###" .. TITLE' \
     test_ui.lua "a title that does not name the page"
bite "$UI" 'SetNextWindowSizeConstraints(ctx, px(420), px(360),' 'SetNextWindowSizeConstraints(ctx, 420, 360,' \
     test_ui.lua "the smallest window not grown with the text"
bite "$UI" '  { "Col_PopupBg",           0x2A2F37FF },' '  { "Col_PopupBg",           0x1B1F25FF },' \
     test_ui.lua "menus darker than the window"
bite "$UI" '  { "Col_TextDisabled",      0xBFC5CEFF },' '  { "Col_TextDisabled",      0x8A919CFF },' \
     test_ui.lua "menu keys under 7:1"
bite "$UI" '  { "Col_ScrollbarGrab",     0x6D7581FF },' '  { "Col_ScrollbarGrab",     0x585F6BFF },' \
     test_ui.lua "a scrollbar grab under 3:1"
bite "$UI" '  { "Col_ResizeGrip",        0x6D7581FF },' '  { "Col_ResizeGrip",        0x707070FF },' \
     test_ui.lua "a neutral grey in the theme"

exit $bad
