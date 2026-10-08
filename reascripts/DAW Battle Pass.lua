--[[
 * ReaScript Name: DAW Battle Pass
 * Description:    A battle pass for making music. Every fifteen minutes of
 *                 active work unlocks a tier of rewards, with a big one every
 *                 hour; everything you do earns XP and loot crates; coins buy
 *                 permission slips in the shop; daily check-ins, daily and
 *                 weekly quests, Diablo-style gear and achievements.
 *
 * About:          Run it and keep the window open (dock it if you like) while
 *                 you work. It notices when you're making music and pauses
 *                 when you're away. Progress is saved for you, not per
 *                 project, so it carries on whatever you open.
 *
 *                 Rewards are made on the fly and never run out: song titles,
 *                 song themes, chord progressions, drum patterns, melodies,
 *                 sound design briefs, challenges, genre fusions, artist
 *                 aliases, lyric openers, arrangements, song seeds, gear,
 *                 titles and banners - Poor to Mythic. Chords, drums and
 *                 melodies drop into your project as MIDI.
 *
 *                 Needs ReaImGui, from the ReaTeam Extensions repository.
 *                 js_ReaScriptAPI (optional) makes idle detection sharper.
 * Author:         Kallum Shah
 * Links:          https://github.com/KallumS/DAW-Battle-Pass
 * Version:        1.0
 * Provides:
 *   bp_theory.lua
 *   bp_loot.lua
 *   bp_game.lua
 *   bp_fx.lua
 *   bp_watch.lua
--]]

local TITLE   = "DAW Battle Pass"
local SECTION = "DAWBattlePass"

------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------

local imgui_path = reaper.ImGui_GetBuiltinPath and
                   (reaper.ImGui_GetBuiltinPath() .. "/imgui.lua")
if not imgui_path then
  reaper.MB("DAW Battle Pass needs the ReaImGui extension.\n\n" ..
            "Install it with ReaPack, from the ReaTeam Extensions repository.",
            "Missing dependency", 0)
  return
end
local ImGui = dofile(imgui_path)("0.9")

local SCRIPT = ({ reaper.get_action_context() })[2]
local HERE  = SCRIPT:match("^(.*[/\\])")
local T     = dofile(HERE .. "bp_theory.lua")
local L     = dofile(HERE .. "bp_loot.lua").init(T)
local G     = dofile(HERE .. "bp_game.lua").init(L)
local F     = dofile(HERE .. "bp_fx.lua")
local W     = dofile(HERE .. "bp_watch.lua").init(G)

------------------------------------------------------------------------------
-- Look
--
-- The house scheme, the same as the sister repos: a dark cool-grey ground,
-- light grey controls with dark ink, and one yellow for whatever is switched
-- on. Every grey is blue-shifted, R < G < B. Added for a game, and kept off
-- the accent's hue: the rarity ladder, the XP blue, the pass orange and the
-- coin gold. docs/COLOUR.md has all of it.
------------------------------------------------------------------------------

local THEME = {
  { "Col_Text",              0xDDE1E7FF },
  { "Col_TextDisabled",      0x8A919CFF },
  { "Col_WindowBg",          0x23272EFF },
  { "Col_ChildBg",           0x23272EFF },
  { "Col_PopupBg",           0x1B1F25FF },
  { "Col_Border",            0x14171CFF },
  { "Col_FrameBg",           0x1A1D23FF },
  { "Col_FrameBgHovered",    0x22262DFF },
  { "Col_FrameBgActive",     0x2A2F37FF },
  { "Col_TitleBg",           0x1B1F25FF },
  { "Col_TitleBgActive",     0x23272EFF },
  { "Col_TitleBgCollapsed",  0x1B1F25FF },
  { "Col_Button",            0xA9AFBAFF },
  { "Col_ButtonHovered",     0xC0C6CFFF },
  { "Col_ButtonActive",      0x8F96A2FF },
  { "Col_CheckMark",         0xFFF200FF },
  { "Col_SliderGrab",        0xA9AFBAFF },
  { "Col_SliderGrabActive",  0xFFF200FF },
  { "Col_Separator",         0x3A404AFF },
  { "Col_ScrollbarBg",       0x1A1D23FF },
  { "Col_ScrollbarGrab",     0x585F6BFF },
  { "Col_ScrollbarGrabHovered", 0x6D7581FF },
  { "Col_ScrollbarGrabActive",  0xA9AFBAFF },
}

local SELECTED = 0xFFF200FF   -- the accent: what is switched on
local INK      = 0x14171CFF   -- the text on every button
local TEXT     = 0xDDE1E7FF
local DIM      = 0x8A919CFF
local WARN     = 0xD2483FFF
local GROUND   = 0x23272EFF
local SUNKEN   = 0x1A1D23FF
local DEEP     = 0x111419FF
local RULE     = 0x3A404AFF
local CONTROL  = 0xA9AFBAFF
local GRAB     = 0x585F6BFF
local BRIGHT   = 0xF2F4F7FF
local XP_COL   = 0x3D8EFFFF   -- the level bar: Rare's blue
local PASS_COL = 0xFF8A1CFF   -- the season track: Legendary's orange
local COIN     = 0xFFC83DFF
local COIN_DK  = 0xB9862AFF

local function shade(col, amount)
  local a = col % 256
  local b = math.floor(col / 256) % 256
  local g = math.floor(col / 65536) % 256
  local r = math.floor(col / 16777216) % 256
  local function mix(c)
    if amount >= 0 then return math.floor(c + (255 - c) * amount + 0.5) end
    return math.floor(c * (1 + amount) + 0.5)
  end
  return mix(r) * 16777216 + mix(g) * 65536 + mix(b) * 256 + a
end
local A = F.alpha
local function RC(r) return L.RARITY[r].col end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local ctx, FONT
local st, ss, watcher, fx
local plugins, pluginSource = {}, ""
local ui = {
  tab = "pass", modals = {}, confirm = {}, filter = "all",
  disp = { level = 1, coins = 0 }, xpShown = 0, xpAt = 0,
  coinPos = { 0, 0 }, xpPos = { 0, 0 }, lastClick = { 0, 0 },
  headlines = {}, wraps = {}, selected = nil, nameBuf = nil,
  nextSlow = 0, nextSave = 0, saveSoon = nil, lastMouse = { 0, 0 }, own = false,
  tp = 0, epoch = 0, dt = 0, status = "",
}

local TABS = {
  { id = "pass", label = "Pass" }, { id = "quests", label = "Quests" }, { id = "shop", label = "Shop" },
  { id = "gear", label = "Gear" }, { id = "loot", label = "Loot" }, { id = "ideas", label = "Ideas" },
  { id = "trophies", label = "Trophies" }, { id = "stats", label = "Stats" },
}

local function fmtDur(sec)
  sec = math.max(0, math.floor(sec))
  local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
  if d > 0 then return string.format("%dd %dh", d, h) end
  if h > 0 then return string.format("%dh %02dm", h, m) end
  if m > 0 then return string.format("%dm", m) end
  return string.format("%ds", sec)
end

local function fmtClock(sec)
  sec = math.max(0, math.floor(sec))
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function fmtNum(n)
  local s = tostring(math.floor(n + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

local function saveSoon() ui.saveSoon = ui.tp + 1 end

local function save()
  if st then W.writeAtomic(W.savePath(), G.serialize(st)) end
  ui.nextSave, ui.saveSoon = ui.tp + 20, nil
end

------------------------------------------------------------------------------
-- Widgets (the sister repos' own)
------------------------------------------------------------------------------

local function pushTheme()
  for _, c in ipairs(THEME) do ImGui.PushStyleColor(ctx, ImGui[c[1]], c[2]) end
end
local function popTheme() ImGui.PopStyleColor(ctx, #THEME) end

-- An unchosen button wears the theme's grey, a chosen one the accent. Either
-- way its text is INK.
local function pick(label, selected, width, disabled)
  local pushed = 1
  if selected then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, SELECTED)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, shade(SELECTED, 0.18))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, shade(SELECTED, -0.18))
    pushed = 4
  end
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, INK)
  if disabled then ImGui.BeginDisabled(ctx, true) end
  local hit = ImGui.Button(ctx, label, width or 0, 0)
  if disabled then ImGui.EndDisabled(ctx) end
  ImGui.PopStyleColor(ctx, pushed)
  if hit then
    local mx, my = ImGui.GetMousePos(ctx)
    ui.lastClick = { mx, my }
  end
  return hit and not disabled
end

-- A button at a place on the screen.
local function pickAt(x, y, label, selected, width, disabled)
  ImGui.SetCursorScreenPos(ctx, x, y)
  return pick(label, selected, width, disabled)
end

-- A button that asks once more before doing something that costs: the first
-- click turns it into "Sure?" for three seconds.
local function sure(id, label, width, disabled)
  local armed = ui.confirm.id == id and ui.tp - ui.confirm.t < 3
  if pick(armed and "Sure?" or label, armed, width, disabled) then
    if armed then ui.confirm = {}; return true end
    ui.confirm = { id = id, t = ui.tp }
  end
  return false
end

local function tip(text)
  if text and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
end

local function dim(text)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, DIM)
  ImGui.Text(ctx, text)
  ImGui.PopStyleColor(ctx, 1)
end

------------------------------------------------------------------------------
-- Text on the draw list
------------------------------------------------------------------------------

local function measure(font, size, s)
  ImGui.PushFont(ctx, font.f)
  local w, h = ImGui.CalcTextSize(ctx, s)
  ImGui.PopFont(ctx)
  local k = size / font.size
  return w * k, h * k
end

local function dtext(dl, font, size, x, y, col, s, align)
  if align == "center" or align == "right" then
    local w = measure(font, size, s)
    x = (align == "center") and (x - w / 2) or (x - w)
  end
  ImGui.DrawList_AddTextEx(dl, font.f, size, x, y, col, s)
end

-- Lines of text no wider than maxw, cached: a vault of four hundred ideas
-- is measured once, not every frame.
local function wrap(font, size, s, maxw)
  local key = s .. "|" .. size .. "|" .. math.floor(maxw)
  local hit = ui.wraps[key]
  if hit then return hit end
  -- Resizing the window makes new widths; start the cache again now and then.
  ui.wrapCount = (ui.wrapCount or 0) + 1
  if ui.wrapCount > 4000 then ui.wraps, ui.wrapCount = {}, 0 end
  local lines = {}
  for para in (s .. "\n"):gmatch("(.-)\n") do
    local line = ""
    for word in para:gmatch("%S+") do
      local try = (line == "") and word or (line .. " " .. word)
      if line ~= "" and measure(font, size, try) > maxw then
        lines[#lines + 1] = line
        line = word
      else line = try end
    end
    lines[#lines + 1] = line
  end
  ui.wraps[key] = lines
  return lines
end

local function wrapText(dl, font, size, x, y, maxw, col, s, maxLines, gap)
  local lines = wrap(font, size, s, maxw)
  local lh = size + (gap or 3)
  local n = math.min(#lines, maxLines or #lines)
  for i = 1, n do
    local line = lines[i]
    if i == n and n < #lines then line = line .. "..." end
    ImGui.DrawList_AddTextEx(dl, font.f, size, x, y + (i - 1) * lh, col, line)
  end
  return n * lh
end

------------------------------------------------------------------------------
-- Drawing: shapes and icons
------------------------------------------------------------------------------

local D = {}

function D.rect(dl, x1, y1, x2, y2, col, r) ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, col, r or 0) end
function D.frame(dl, x1, y1, x2, y2, col, r, th) ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, col, r or 0, 0, th or 1) end
function D.circle(dl, x, y, r, col) ImGui.DrawList_AddCircleFilled(dl, x, y, r, col) end
function D.ring(dl, x, y, r, col, th) ImGui.DrawList_AddCircle(dl, x, y, r, col, 0, th or 1) end
function D.line(dl, x1, y1, x2, y2, col, th) ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, col, th or 1) end
function D.tri(dl, x1, y1, x2, y2, x3, y3, col) ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, col) end
function D.quad(dl, a, b, c, d, col)
  ImGui.DrawList_AddQuadFilled(dl, a[1], a[2], b[1], b[2], c[1], c[2], d[1], d[2], col)
end

function D.arc(dl, x, y, r, a1, a2, col, th)
  if a2 - a1 < 0.01 then return end
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, x, y, r, a1, a2, 48)
  ImGui.DrawList_PathStroke(dl, col, 0, th)
end

function D.glow(dl, x1, y1, x2, y2, col, r, strength)
  for i = 4, 1, -1 do
    D.frame(dl, x1 - i * 2, y1 - i * 2, x2 + i * 2, y2 + i * 2, A(col, strength * 0.14 * (5 - i)), (r or 0) + i * 2, 2)
  end
end

function D.bar(dl, x, y, w, h, frac, col, bg)
  D.rect(dl, x, y, x + w, y + h, bg or DEEP, h / 2)
  frac = math.max(0, math.min(1, frac))
  if frac > 0 then D.rect(dl, x, y, x + math.max(h, w * frac), y + h, col, h / 2) end
end

-- Spokes of light behind a reward.
function D.rays(dl, cx, cy, r, n, rot, col)
  for i = 0, n - 1 do
    local a1 = rot + i * 2 * math.pi / n
    local a2 = a1 + math.pi / n * 0.55
    D.tri(dl, cx, cy, cx + math.cos(a1) * r, cy + math.sin(a1) * r, cx + math.cos(a2) * r, cy + math.sin(a2) * r, col)
  end
end

function D.halo(dl, cx, cy, r, col, a)
  for i = 8, 1, -1 do D.circle(dl, cx, cy, r * i / 8, A(col, (a or 0.5) / 8)) end
end

local function rot(px, py, cx, cy, a)
  local c, s = math.cos(a), math.sin(a)
  local dx, dy = px - cx, py - cy
  return { cx + dx * c - dy * s, cy + dx * s + dy * c }
end

-- A box rotated about its centre.
function D.box(dl, cx, cy, w, h, a, col)
  local x1, y1, x2, y2 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
  D.quad(dl, rot(x1, y1, cx, cy, a), rot(x2, y1, cx, cy, a), rot(x2, y2, cx, cy, a), rot(x1, y2, cx, cy, a), col)
end

function D.star(dl, cx, cy, r, col, spin)
  spin = spin or 0
  local pts = {}
  for i = 0, 9 do
    local a = -math.pi / 2 + spin + i * math.pi / 5
    local rr = (i % 2 == 0) and r or r * 0.45
    pts[i] = { cx + math.cos(a) * rr, cy + math.sin(a) * rr }
  end
  for i = 0, 9 do
    local p, q = pts[i], pts[(i + 1) % 10]
    D.tri(dl, cx, cy, p[1], p[2], q[1], q[2], col)
  end
end

function D.check(dl, cx, cy, s, col)
  D.line(dl, cx - s * 0.45, cy, cx - s * 0.1, cy + s * 0.35, col, math.max(2, s * 0.18))
  D.line(dl, cx - s * 0.1, cy + s * 0.35, cx + s * 0.5, cy - s * 0.35, col, math.max(2, s * 0.18))
end

-- The crate: a chest in a rarity's colour, rotated `a`, lid lifted `lift`.
function D.crate(dl, cx, cy, s, col, a, lift)
  a, lift = a or 0, lift or 0
  local dark = shade(col, -0.55)
  local mid = shade(col, -0.25)
  D.box(dl, cx, cy + s * 0.12, s, s * 0.62, a, dark)
  D.box(dl, cx, cy + s * 0.12, s * 0.9, s * 0.52, a, mid)
  local lc = rot(cx, cy - s * 0.26 - lift, cx, cy, a)
  D.box(dl, lc[1], lc[2], s * 1.06, s * 0.24, a, col)
  local b1 = rot(cx - s * 0.3, cy + s * 0.12, cx, cy, a)
  local b2 = rot(cx + s * 0.3, cy + s * 0.12, cx, cy, a)
  D.box(dl, b1[1], b1[2], s * 0.08, s * 0.62, a, col)
  D.box(dl, b2[1], b2[2], s * 0.08, s * 0.62, a, col)
  local lk = rot(cx, cy - s * 0.1 - lift * 0.5, cx, cy, a)
  D.box(dl, lk[1], lk[2], s * 0.16, s * 0.2, a, COIN)
end

local ICON = {}

function ICON.coin(dl, x, y, r)
  D.circle(dl, x, y, r, COIN_DK)
  D.circle(dl, x, y, r * 0.84, COIN)
  D.ring(dl, x, y, r * 0.56, COIN_DK, math.max(1, r * 0.13))
  D.circle(dl, x - r * 0.32, y - r * 0.36, r * 0.16, 0xFFF3C8FF)
end
function ICON.crate(dl, x, y, r, col) D.crate(dl, x, y, r * 1.8, col) end
function ICON.star(dl, x, y, r, col) D.star(dl, x, y, r, col) end
function ICON.bolt(dl, x, y, r, col)
  D.tri(dl, x + r * 0.25, y - r, x - r * 0.55, y + r * 0.15, x + r * 0.05, y + r * 0.1, col)
  D.tri(dl, x - r * 0.05, y - r * 0.1, x + r * 0.55, y - r * 0.15, x - r * 0.25, y + r, col)
end
function ICON.dice(dl, x, y, r, col)
  D.rect(dl, x - r * 0.8, y - r * 0.8, x + r * 0.8, y + r * 0.8, col, r * 0.25)
  for _, p in ipairs({ { -0.4, -0.4 }, { 0.4, 0.4 }, { 0, 0 }, { 0.4, -0.4 }, { -0.4, 0.4 } }) do
    D.circle(dl, x + p[1] * r, y + p[2] * r, r * 0.13, INK)
  end
end
function ICON.snow(dl, x, y, r, col)
  for i = 0, 2 do
    local a = i * math.pi / 3
    D.line(dl, x - math.cos(a) * r, y - math.sin(a) * r, x + math.cos(a) * r, y + math.sin(a) * r, col, math.max(2, r * 0.18))
  end
  D.circle(dl, x, y, r * 0.2, col)
end
function ICON.note(dl, x, y, r, col)
  D.circle(dl, x - r * 0.3, y + r * 0.55, r * 0.38, col)
  D.rect(dl, x - r * 0.0, y - r * 0.85, x + r * 0.14, y + r * 0.55, col)
  D.tri(dl, x + r * 0.14, y - r * 0.85, x + r * 0.7, y - r * 0.4, x + r * 0.14, y - r * 0.35, col)
end
function ICON.keys(dl, x, y, r, col)
  D.rect(dl, x - r, y - r * 0.7, x + r, y + r * 0.7, col, r * 0.12)
  for i = 1, 3 do D.line(dl, x - r + i * r / 2, y - r * 0.7, x - r + i * r / 2, y + r * 0.7, INK, 1.5) end
  for i = 0, 2 do if i ~= 1 then D.rect(dl, x - r * 0.62 + i * r * 0.62, y - r * 0.7, x - r * 0.4 + i * r * 0.62, y + r * 0.05, INK) end end
end
function ICON.drum(dl, x, y, r, col)
  D.rect(dl, x - r * 0.85, y - r * 0.4, x + r * 0.85, y + r * 0.6, col, r * 0.2)
  D.rect(dl, x - r * 0.85, y - r * 0.55, x + r * 0.85, y - r * 0.25, shade(col, 0.4), r * 0.15)
  D.line(dl, x - r * 0.9, y - r * 1.0, x - r * 0.1, y - r * 0.5, col, 2)
  D.line(dl, x + r * 0.9, y - r * 1.0, x + r * 0.1, y - r * 0.5, col, 2)
end
function ICON.wave(dl, x, y, r, col)
  local px, py
  for i = 0, 16 do
    local t = i / 16
    local qx, qy = x - r + t * 2 * r, y + math.sin(t * math.pi * 3) * r * 0.55
    if px then D.line(dl, px, py, qx, qy, col, math.max(2, r * 0.18)) end
    px, py = qx, qy
  end
end
function ICON.dial(dl, x, y, r, col)
  D.ring(dl, x, y, r * 0.85, col, math.max(2, r * 0.16))
  D.line(dl, x, y, x + r * 0.45, y - r * 0.45, col, math.max(2, r * 0.18))
  D.circle(dl, x, y, r * 0.18, col)
end
function ICON.flag(dl, x, y, r, col)
  D.rect(dl, x - r * 0.7, y - r, x - r * 0.52, y + r, col)
  D.tri(dl, x - r * 0.52, y - r, x + r * 0.8, y - r * 0.55, x - r * 0.52, y - r * 0.1, col)
end
function ICON.atom(dl, x, y, r, col)
  D.ring(dl, x, y, r * 0.9, col, 2)
  D.ring(dl, x, y, r * 0.5, col, 2)
  D.circle(dl, x, y, r * 0.2, col)
end
function ICON.mask(dl, x, y, r, col)
  D.circle(dl, x, y, r * 0.85, col)
  D.circle(dl, x - r * 0.32, y - r * 0.15, r * 0.15, INK)
  D.circle(dl, x + r * 0.32, y - r * 0.15, r * 0.15, INK)
  D.arc(dl, x, y + r * 0.1, r * 0.4, 0.3, math.pi - 0.3, INK, 2)
end
function ICON.mic(dl, x, y, r, col)
  D.rect(dl, x - r * 0.35, y - r, x + r * 0.35, y + r * 0.2, col, r * 0.35)
  D.arc(dl, x, y - r * 0.1, r * 0.6, 0.2, math.pi - 0.2, col, 2)
  D.line(dl, x, y + r * 0.5, x, y + r, col, 2)
end
function ICON.blocks(dl, x, y, r, col)
  D.rect(dl, x - r, y - r * 0.2, x - r * 0.1, y + r * 0.7, col, 2)
  D.rect(dl, x + r * 0.05, y - r * 0.8, x + r, y + r * 0.7, shade(col, -0.2), 2)
end
function ICON.seed(dl, x, y, r, col)
  D.circle(dl, x, y + r * 0.3, r * 0.5, col)
  D.tri(dl, x, y - r, x - r * 0.5, y + r * 0.1, x + r * 0.5, y + r * 0.1, col)
end
function ICON.bulb(dl, x, y, r, col)
  D.circle(dl, x, y - r * 0.2, r * 0.65, col)
  D.rect(dl, x - r * 0.3, y + r * 0.35, x + r * 0.3, y + r * 0.85, shade(col, -0.3), 2)
end
function ICON.phones(dl, x, y, r, col)
  D.arc(dl, x, y, r * 0.8, math.pi, 2 * math.pi, col, math.max(2, r * 0.2))
  D.rect(dl, x - r, y - r * 0.05, x - r * 0.55, y + r * 0.75, col, 3)
  D.rect(dl, x + r * 0.55, y - r * 0.05, x + r, y + r * 0.75, col, 3)
end
function ICON.speaker(dl, x, y, r, col)
  D.rect(dl, x - r * 0.7, y - r, x + r * 0.7, y + r, col, 3)
  D.circle(dl, x, y + r * 0.35, r * 0.42, INK)
  D.circle(dl, x, y - r * 0.5, r * 0.2, INK)
end
function ICON.gem(dl, x, y, r, col)
  D.tri(dl, x - r, y - r * 0.2, x + r, y - r * 0.2, x, y + r, col)
  D.quad(dl, { x - r * 0.6, y - r * 0.75 }, { x + r * 0.6, y - r * 0.75 }, { x + r, y - r * 0.2 }, { x - r, y - r * 0.2 }, shade(col, 0.3))
end
function ICON.crown(dl, x, y, r, col)
  D.rect(dl, x - r * 0.8, y + r * 0.1, x + r * 0.8, y + r * 0.6, col)
  D.tri(dl, x - r * 0.8, y + r * 0.1, x - r * 0.8, y - r * 0.6, x - r * 0.3, y + r * 0.1, col)
  D.tri(dl, x - r * 0.35, y + r * 0.1, x, y - r * 0.8, x + r * 0.35, y + r * 0.1, col)
  D.tri(dl, x + r * 0.3, y + r * 0.1, x + r * 0.8, y - r * 0.6, x + r * 0.8, y + r * 0.1, col)
end
function ICON.banner(dl, x, y, r, col)
  D.rect(dl, x - r * 0.6, y - r, x + r * 0.6, y + r * 0.4, col)
  D.tri(dl, x - r * 0.6, y + r * 0.4, x + r * 0.6, y + r * 0.4, x, y + r, col)
end
function ICON.scroll(dl, x, y, r, col)
  D.rect(dl, x - r * 0.65, y - r * 0.8, x + r * 0.65, y + r * 0.8, col, 2)
  for i = 0, 2 do D.line(dl, x - r * 0.4, y - r * 0.35 + i * r * 0.35, x + r * 0.4, y - r * 0.35 + i * r * 0.35, INK, 1.5) end
end
function ICON.coffee(dl, x, y, r, col)
  D.rect(dl, x - r * 0.65, y - r * 0.3, x + r * 0.35, y + r * 0.8, col, 3)
  D.ring(dl, x + r * 0.5, y + r * 0.2, r * 0.28, col, 2)
  for i = 0, 1 do D.line(dl, x - r * 0.3 + i * r * 0.4, y - r * 0.5, x - r * 0.2 + i * r * 0.4, y - r, col, 1.5) end
end
function ICON.cookie(dl, x, y, r, col)
  D.circle(dl, x, y, r * 0.85, col)
  for _, p in ipairs({ { -0.35, -0.3 }, { 0.3, -0.1 }, { -0.1, 0.35 }, { 0.35, 0.4 } }) do D.circle(dl, x + p[1] * r, y + p[2] * r, r * 0.12, INK) end
end
function ICON.tv(dl, x, y, r, col)
  D.rect(dl, x - r, y - r * 0.65, x + r, y + r * 0.65, col, 4)
  D.tri(dl, x - r * 0.25, y - r * 0.35, x - r * 0.25, y + r * 0.35, x + r * 0.35, y, INK)
end
function ICON.moon(dl, x, y, r, col, bg)
  D.circle(dl, x, y, r * 0.85, col)
  D.circle(dl, x + r * 0.35, y - r * 0.25, r * 0.7, bg or SUNKEN)
end
function ICON.film(dl, x, y, r, col)
  D.rect(dl, x - r, y - r * 0.7, x + r, y + r * 0.7, col, 2)
  for i = 0, 3 do
    D.rect(dl, x - r * 0.85 + i * r * 0.5, y - r * 0.6, x - r * 0.65 + i * r * 0.5, y - r * 0.42, INK)
    D.rect(dl, x - r * 0.85 + i * r * 0.5, y + r * 0.42, x - r * 0.65 + i * r * 0.5, y + r * 0.6, INK)
  end
  D.tri(dl, x - r * 0.2, y - r * 0.25, x - r * 0.2, y + r * 0.25, x + r * 0.25, y, INK)
end
function ICON.gamepad(dl, x, y, r, col)
  D.rect(dl, x - r, y - r * 0.45, x + r, y + r * 0.5, col, r * 0.4)
  D.rect(dl, x - r * 0.65, y - r * 0.05, x - r * 0.2, y + r * 0.08, INK)
  D.rect(dl, x - r * 0.49, y - r * 0.22, x - r * 0.36, y + r * 0.25, INK)
  D.circle(dl, x + r * 0.4, y - r * 0.1, r * 0.12, INK)
  D.circle(dl, x + r * 0.6, y + r * 0.12, r * 0.12, INK)
end
function ICON.pizza(dl, x, y, r, col)
  D.tri(dl, x - r * 0.8, y - r * 0.7, x + r * 0.8, y - r * 0.7, x, y + r, col)
  D.rect(dl, x - r * 0.85, y - r * 0.85, x + r * 0.85, y - r * 0.6, shade(col, -0.35), 3)
  D.circle(dl, x - r * 0.25, y - r * 0.3, r * 0.14, WARN)
  D.circle(dl, x + r * 0.2, y - r * 0.15, r * 0.14, WARN)
  D.circle(dl, x, y + r * 0.3, r * 0.12, WARN)
end
function ICON.calendar(dl, x, y, r, col)
  D.rect(dl, x - r * 0.8, y - r * 0.7, x + r * 0.8, y + r * 0.8, col, 3)
  D.rect(dl, x - r * 0.8, y - r * 0.7, x + r * 0.8, y - r * 0.35, WARN, 3)
  D.check(dl, x, y + r * 0.25, r * 0.7, INK)
end
function ICON.plug(dl, x, y, r, col)
  D.rect(dl, x - r * 0.5, y - r * 0.3, x + r * 0.5, y + r * 0.4, col, 3)
  D.rect(dl, x - r * 0.35, y - r, x - r * 0.18, y - r * 0.3, col)
  D.rect(dl, x + r * 0.18, y - r, x + r * 0.35, y - r * 0.3, col)
  D.rect(dl, x - r * 0.1, y + r * 0.4, x + r * 0.1, y + r, col)
end
function ICON.ticket(dl, x, y, r, col, bg)
  D.rect(dl, x - r, y - r * 0.55, x + r, y + r * 0.55, col, 3)
  D.circle(dl, x - r, y, r * 0.22, bg or SUNKEN)
  D.circle(dl, x + r, y, r * 0.22, bg or SUNKEN)
end
function ICON.flame(dl, x, y, r, col)
  D.circle(dl, x, y + r * 0.3, r * 0.6, col)
  D.tri(dl, x - r * 0.58, y + r * 0.2, x + r * 0.58, y + r * 0.2, x + r * 0.1, y - r, col)
  D.circle(dl, x, y + r * 0.42, r * 0.3, 0xFFE27AFF)
end
function ICON.trophy(dl, x, y, r, col)
  D.rect(dl, x - r * 0.6, y - r * 0.8, x + r * 0.6, y + r * 0.1, col, r * 0.3)
  D.rect(dl, x - r * 0.12, y + r * 0.1, x + r * 0.12, y + r * 0.6, col)
  D.rect(dl, x - r * 0.5, y + r * 0.6, x + r * 0.5, y + r * 0.85, col, 2)
  D.ring(dl, x - r * 0.65, y - r * 0.4, r * 0.25, col, 2)
  D.ring(dl, x + r * 0.65, y - r * 0.4, r * 0.25, col, 2)
end
function ICON.clock(dl, x, y, r, col)
  D.ring(dl, x, y, r * 0.85, col, math.max(2, r * 0.16))
  D.line(dl, x, y, x, y - r * 0.55, col, 2)
  D.line(dl, x, y, x + r * 0.4, y + r * 0.1, col, 2)
end
function ICON.lock(dl, x, y, r, col)
  D.rect(dl, x - r * 0.6, y - r * 0.1, x + r * 0.6, y + r * 0.8, col, 3)
  D.arc(dl, x, y - r * 0.1, r * 0.4, math.pi, 2 * math.pi, col, math.max(2, r * 0.2))
end

local function icon(dl, name, x, y, r, col, bg)
  local f = ICON[name]
  if f then f(dl, x, y, r, col or TEXT, bg) else D.circle(dl, x, y, r * 0.7, col or TEXT) end
end

-- A banner (the profile emblem): a shape in one colour, a pattern in a
-- second, a glyph on top; Legendary ones glow, Mythic ones spin light.
local function drawBanner(dl, cx, cy, r, b, t)
  if not b then
    D.circle(dl, cx, cy, r, RULE)
    return
  end
  local sat = b.sat or 0.7
  local c1 = F.hsv(b.h1, sat, 0.75)
  local c2 = F.hsv(b.h2, sat * 0.9, 0.95)
  t = t or 0
  if b.spin then D.rays(dl, cx, cy, r * 1.5, 10, t * 0.6, A(c2, 0.25)) end
  if b.glow then D.halo(dl, cx, cy, r * 1.35, c2, 0.45 + 0.2 * math.sin(t * 3)) end
  if b.shape == "diamond" then
    D.quad(dl, { cx, cy - r }, { cx + r, cy }, { cx, cy + r }, { cx - r, cy }, c1)
  elseif b.shape == "shield" then
    D.rect(dl, cx - r * 0.85, cy - r, cx + r * 0.85, cy + r * 0.2, c1, r * 0.15)
    D.tri(dl, cx - r * 0.85, cy + r * 0.15, cx + r * 0.85, cy + r * 0.15, cx, cy + r, c1)
  elseif b.shape == "hexagon" then
    for i = 0, 5 do
      local a1, a2 = i * math.pi / 3, (i + 1) * math.pi / 3
      D.tri(dl, cx, cy, cx + math.cos(a1) * r, cy + math.sin(a1) * r, cx + math.cos(a2) * r, cy + math.sin(a2) * r, c1)
    end
  elseif b.shape == "star" then D.star(dl, cx, cy, r * 1.1, c1)
  else D.circle(dl, cx, cy, r, c1) end
  local ir = r * 0.62
  if b.pattern == "split" then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, ir, math.pi / 2, math.pi * 1.5, 24)
    ImGui.DrawList_PathFillConvex(dl, c2)
  elseif b.pattern == "stripes" then
    for i = -1, 1 do D.rect(dl, cx - ir * 0.8, cy + i * ir * 0.55 - ir * 0.12, cx + ir * 0.8, cy + i * ir * 0.55 + ir * 0.12, c2) end
  elseif b.pattern == "chevron" then
    D.line(dl, cx - ir, cy - ir * 0.3, cx, cy + ir * 0.4, c2, ir * 0.3)
    D.line(dl, cx, cy + ir * 0.4, cx + ir, cy - ir * 0.3, c2, ir * 0.3)
  elseif b.pattern == "rings" then
    D.ring(dl, cx, cy, ir, c2, ir * 0.16)
    D.ring(dl, cx, cy, ir * 0.55, c2, ir * 0.16)
  elseif b.pattern == "rays" then
    D.rays(dl, cx, cy, ir, 8, t * (b.spin and 1 or 0), c2)
  elseif b.pattern == "dots" then
    for i = 0, 5 do
      local a = i * math.pi / 3
      D.circle(dl, cx + math.cos(a) * ir * 0.7, cy + math.sin(a) * ir * 0.7, ir * 0.18, c2)
    end
  end
  if b.glyph then icon(dl, b.glyph, cx, cy, r * 0.42, BRIGHT, c1) end
end

------------------------------------------------------------------------------
-- A reward card: what every drop looks like, in the reveal and the shop.
------------------------------------------------------------------------------

local function dropCard(dl, x, y, w, h, d, t, scale)
  scale = scale or 1
  local cx, cy = x + w / 2, y + h / 2
  local sw, sh = w * scale, h * scale
  local x1, y1, x2, y2 = cx - sw / 2, cy - sh / 2, cx + sw / 2, cy + sh / 2
  local col = RC(d.rarity)
  if d.rarity >= L.LEGENDARY then D.glow(dl, x1, y1, x2, y2, col, 8, 0.7 + 0.3 * math.sin(t * 4)) end
  D.rect(dl, x1, y1, x2, y2, SUNKEN, 8)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1 + 2, y1 + 2, x2 - 2, y1 + sh * 0.45, A(col, 0.35), A(col, 0.35), A(col, 0), A(col, 0))
  D.frame(dl, x1, y1, x2, y2, col, 8, d.rarity >= L.EPIC and 2.5 or 1.5)
  if scale < 0.92 then return end
  local pad = 10
  local iconCol = (d.type == "coins") and COIN or col
  if d.type == "banner" then drawBanner(dl, cx, y1 + 34, 22, d.data, t)
  elseif d.type == "crate" then D.crate(dl, cx, y1 + 36, 40, col, math.sin(t * 2) * 0.05)
  else icon(dl, d.icon, cx, y1 + 34, 18, iconCol) end
  dtext(dl, FONT.body, 12, cx, y1 + 60, col, L.RARITY[d.rarity].name:upper(), "center")
  dtext(dl, FONT.body, 12, cx, y1 + 75, DIM, d.name or "", "center")
  local used = wrapText(dl, FONT.bold, 15, x1 + pad, y1 + 96, sw - pad * 2, TEXT, d.text or "", 4)
  if d.sub and d.sub ~= "" then
    wrapText(dl, FONT.body, 12, x1 + pad, y1 + 100 + used, sw - pad * 2, DIM, d.sub, math.max(1, math.floor((sh - 110 - used) / 15)))
  end
end

-- Lines describing a piece of gear, for its tooltip and its panel.
local function gearLines(item, against)
  local lines = { item.name, L.RARITY[item.rarity].name .. " " .. L.SLOTS[item.slot].name ..
                  "  /  item level " .. item.ilvl .. "  /  score " .. L.gearScore(item) }
  local mine = L.gearStats(item)
  lines[#lines + 1] = L.statLine(item.implicit.id, item.implicit.value) .. "  (implicit)"
  for _, a in ipairs(item.affixes) do lines[#lines + 1] = L.statLine(a.id, a.value) end
  if item.power then
    local p = L.POWERS[item.power]
    lines[#lines + 1] = "Power - " .. p.name .. ": " .. p.text
  end
  if against and against ~= item then
    local theirs = L.gearStats(against)
    local diff = {}
    for id, v in pairs(mine) do diff[id] = v - (theirs[id] or 0) end
    for id, v in pairs(theirs) do if not mine[id] then diff[id] = -v end end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Compared with your " .. against.name .. ":"
    local keys = {}
    for id in pairs(diff) do keys[#keys + 1] = id end
    table.sort(keys)
    for _, id in ipairs(keys) do
      if diff[id] ~= 0 then lines[#lines + 1] = (diff[id] > 0 and "  more: " or "  less: ") .. L.statLine(id, math.abs(diff[id])) end
    end
    local ds = L.gearScore(item) - L.gearScore(against)
    lines[#lines + 1] = string.format("  score %+d", ds)
  end
  return lines
end

------------------------------------------------------------------------------
-- What the game said: modals, toasts and particles
------------------------------------------------------------------------------

local function pushModal(m)
  m.t = 0
  ui.modals[#ui.modals + 1] = m
end

local function toastCorner()
  return ui.winX + ui.winW - 16, ui.winY + 130
end

local function handleNotices()
  for _, n in ipairs(ss.notices) do
    local k = n.kind
    if k == "tier" then
      pushModal({ type = "reward", tier = n.tier, tierKind = n.tierKind, drops = n.drops })
    elseif k == "crate" then
      pushModal({ type = "reward", crate = n.rarity, drops = n.drops, phase = "closed" })
    elseif k == "level" then
      pushModal({ type = "level", level = n.level, crate = n.crate })
    elseif k == "checkin" then
      -- The check-in modal may already be showing it (its own button).
      local m = ui.modals[1]
      if m and m.type == "checkin" then
        if not m.got then m.got, m.t = n, 0 end
      else pushModal({ type = "checkin", got = n }) end
    elseif k == "redeem" then
      pushModal({ type = "redeem", name = n.name, icon = n.icon })
    elseif k == "season" then
      pushModal({ type = "season", season = n.season, name = n.name })
    elseif k == "quest" then
      F.toast(fx, { text = "Quest complete!", sub = n.text, icon = "scroll", rarity = n.rarity })
      local x, y = toastCorner()
      F.confetti(fx, x - 150, y + 20, 50, 300)
    elseif k == "claim" then
      F.coins(fx, ui.lastClick[1], ui.lastClick[2], math.min(30, math.floor(n.coins / 5) + 6), ui.coinPos[1], ui.coinPos[2])
      F.burst(fx, ui.lastClick[1], ui.lastClick[2], 24, { cols = { RC(4), SELECTED, BRIGHT }, speed = 300 })
      if n.crate then F.toast(fx, { text = "Quest reward", sub = L.RARITY[n.crate].name .. " Crate added to Loot", icon = "crate", rarity = n.crate }) end
    elseif k == "ach" then
      F.toast(fx, { ach = true, text = n.name, sub = n.text .. (n.title and ("  -  title: " .. n.title) or ""),
                    icon = "trophy", rarity = n.final and 6 or 5, life = 6, coins = n.coins, xp = n.xp })
      F.confetti(fx, ui.winX + ui.winW / 2, ui.winY + 140, 70, 380)
    elseif k == "toast" then
      F.toast(fx, { text = n.text, sub = n.sub, icon = n.icon, rarity = n.rarity or 3 })
    elseif k == "coins" then
      F.bump(fx, "coins")
      F.floater(fx, "+" .. fmtNum(n.amount), ui.coinPos[1] - 10, ui.coinPos[2] + 12, COIN)
    elseif k == "purchase" then
      F.toast(fx, { text = "Bought " .. n.name, sub = "-" .. fmtNum(n.price) .. " coins", icon = n.icon, rarity = n.rarity or 4 })
      F.burst(fx, ui.lastClick[1], ui.lastClick[2], 30, { cols = { COIN, SELECTED, BRIGHT }, speed = 320 })
      F.ring(fx, ui.lastClick[1], ui.lastClick[2], COIN, 70, 0.6)
    elseif k == "idle" then
      F.toast(fx, { text = "Paused", sub = "Nothing's happened for a while, so the clock has stopped", icon = "clock", rarity = 1 })
    elseif k == "active" then
      F.toast(fx, { text = "Welcome back", sub = "The clock is running again", icon = "clock", rarity = 3, life = 3 })
    elseif k == "equip" then
      F.toast(fx, { text = "Equipped", sub = n.name, icon = "gem", rarity = n.rarity, life = 3 })
    end
  end
  ss.notices = {}
  -- XP floats up from the bar in batches rather than every frame.
  if (ss.xpGained or 0) >= 1 and ui.tp - ui.xpAt > 0.7 then
    F.floater(fx, "+" .. math.floor(ss.xpGained) .. " XP", ui.xpPos[1], ui.xpPos[2] - 6, XP_COL)
    F.burst(fx, ui.xpPos[1], ui.xpPos[2] + 5, 6, { col = XP_COL, speed = 90, life = 0.5, size = 2 })
    ss.xpGained, ui.xpAt = 0, ui.tp
  end
end

------------------------------------------------------------------------------
-- The header: banner, name and title, the level bar, coins
------------------------------------------------------------------------------

local function drawHeader()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = select(1, ImGui.GetContentRegionAvail(ctx))
  local h = 64
  ImGui.InvisibleButton(ctx, "header", math.max(1, w), h)
  local t = ui.tp

  -- Banner with the level on it.
  drawBanner(dl, x + 30, y + 30, 26, G.activeBanner(st) and G.activeBanner(st).data, t)
  local shown = ui.disp.level
  local lvl = math.floor(shown)
  D.circle(dl, x + 30, y + 54, 13, DEEP)
  D.ring(dl, x + 30, y + 54, 13, XP_COL, 2)
  dtext(dl, FONT.bold, 13, x + 30, y + 47, TEXT, tostring(lvl), "center")

  -- Name, title, and the bar.
  local nx = x + 70
  dtext(dl, FONT.bold, 17, nx, y + 4, TEXT, st.profile.name)
  local title = G.activeTitle(st)
  if title ~= "" then
    local nw = measure(FONT.bold, 17, st.profile.name)
    dtext(dl, FONT.body, 13, nx + nw + 10, y + 7, DIM, title)
  end
  local barW = math.max(120, w - 70 - 190)
  local frac = shown - lvl
  local by = y + 30
  D.bar(dl, nx, by, barW, 12, frac, XP_COL)
  if st.boost > 0 then
    -- Boost: yellow stripes run along the bar, because the boost is on.
    ImGui.DrawList_PushClipRect(dl, nx, by, nx + barW * math.max(frac, 0.02), by + 12, true)
    for i = -1, math.floor(barW / 14) + 1 do
      local sx = nx + i * 14 + (t * 30) % 14
      D.quad(dl, { sx, by + 12 }, { sx + 6, by + 12 }, { sx + 12, by }, { sx + 6, by }, A(SELECTED, 0.45))
    end
    ImGui.DrawList_PopClipRect(dl)
  end
  local ex = nx + math.max(6, barW * frac)
  D.halo(dl, ex, by + 6, 10, XP_COL, 0.5 + 0.3 * math.sin(t * 5))
  ui.xpPos = { ex, by }
  local need = G.levelNeed(lvl)
  local label = string.format("Level %d   %s / %s XP", lvl, fmtNum(frac * need), fmtNum(need))
  dtext(dl, FONT.body, 12, nx, by + 15, DIM, label)
  if st.boost > 0 then dtext(dl, FONT.bold, 12, nx + barW, by + 15, SELECTED, "2x XP  " .. fmtClock(st.boost), "right") end

  -- Coins, bumped as they land.
  local bump = fx.bumps.coins or 0
  local cx = x + w - 150
  ICON.coin(dl, cx, y + 20, 12 + bump * 5)
  ui.coinPos = { cx, y + 20 }
  dtext(dl, FONT.bold, 20 + bump * 4, cx + 20, y + 9 - bump * 2, COIN, fmtNum(ui.disp.coins))
  local score = G.gearScore(st)
  icon(dl, "gem", cx, y + 48, 8, CONTROL)
  dtext(dl, FONT.body, 12, cx + 20, y + 41, DIM, "Gear score " .. score)
  ImGui.Dummy(ctx, 0, 2)
end

-- Which tabs have something waiting: a dot like a game's.
local function tabDot(id)
  if id == "quests" then
    if G.checkinAvailable(st, ui.epoch) then return true end
    for _, s in ipairs({ "daily", "weekly" }) do
      for _, q in ipairs(st[s].quests) do if q.done and not q.claimed then return true end end
    end
  elseif id == "loot" then
    for r = 1, 7 do if st.inv.crates[r] > 0 then return true end end
  elseif id == "shop" then
    for _, d in ipairs(st.shop.deals) do if not d.bought and st.coins >= d.price then return true end end
  end
  return false
end

local function drawTabs()
  local dl = ImGui.GetWindowDrawList(ctx)
  for i, tab in ipairs(TABS) do
    if i > 1 then ImGui.SameLine(ctx) end
    if pick(tab.label, ui.tab == tab.id, 0) and ui.tab ~= tab.id then
      ui.tab, ui.tabT, ui.selected = tab.id, ui.tp, nil
    end
    if tabDot(tab.id) then
      local _, y1 = ImGui.GetItemRectMin(ctx)
      local x2 = select(1, ImGui.GetItemRectMax(ctx))
      local p = 0.5 + 0.5 * math.sin(ui.tp * 6)
      D.circle(dl, x2 - 2, y1 + 2, 4 + p, WARN)
    end
  end
end

------------------------------------------------------------------------------
-- Page helpers
------------------------------------------------------------------------------

-- The page area: where the page starts and how wide it is. Pages draw with
-- the draw list and place buttons with SetCursorScreenPos, then `finish`
-- tells the scrolling child how tall they were.
local function area()
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = select(1, ImGui.GetContentRegionAvail(ctx))
  return x, y, math.max(260, w)
end

local function finish(x, y)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.Dummy(ctx, 1, 8)
end

local function panel(dl, x, y, w, h, col)
  D.rect(dl, x, y, x + w, y + h, col or SUNKEN, 6)
end

local function sectionTitle(dl, x, y, text, right)
  dtext(dl, FONT.bold, 15, x, y, TEXT, text)
  if right then dtext(dl, FONT.body, 12, x + measure(FONT.bold, 15, text) + 12, y + 3, DIM, right) end
  return y + 24
end

local function mouseIn(x1, y1, x2, y2)
  if not ImGui.IsWindowHovered(ctx) then return false end
  local mx, my = ImGui.GetMousePos(ctx)
  return mx >= x1 and mx < x2 and my >= y1 and my < y2
end

local function headline(season, tier)
  local key = season .. ":" .. tier .. ":" .. st.level
  local h = ui.headlines[key]
  if not h then
    local best, kind = L.tierHeadline(season, tier, st.level)
    local list = L.tierRewards(season, tier, st.level)
    h = { best = best, kind = kind, list = list }
    ui.headlines[key] = h
  end
  return h
end

------------------------------------------------------------------------------
-- Pass: the season, the clock, the track
------------------------------------------------------------------------------

local function pagePass()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()
  local t = ui.tp
  local season = st.pass.season

  -- The season.
  panel(dl, x, y, w, 70)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x, y, x + w, y + 70, A(PASS_COL, 0.18), A(PASS_COL, 0.0), A(PASS_COL, 0.0), A(PASS_COL, 0.18))
  dtext(dl, FONT.body, 12, x + 14, y + 8, PASS_COL, "SEASON " .. season)
  dtext(dl, FONT.big, 26, x + 14, y + 22, TEXT, L.seasonName(season))
  dtext(dl, FONT.body, 12, x + w - 14, y + 10, DIM, "ends in " .. fmtDur(G.secsToNextSeason(ui.epoch)), "right")
  local tier = st.pass.tier
  local bonus = tier > L.SEASON_TIERS
  dtext(dl, FONT.bold, 15, x + w - 14, y + 28, TEXT,
        bonus and ("Bonus tier " .. (tier - L.SEASON_TIERS)) or ("Tier " .. tier .. " / " .. L.SEASON_TIERS), "right")
  D.bar(dl, x + w - 214, y + 52, 200, 6, math.min(1, tier / L.SEASON_TIERS), PASS_COL)
  y = y + 82

  -- The clock: a ring filling towards the next tier, yellow while it runs.
  local frac = st.pass.secs / G.TIER_SECONDS
  local rcx, rcy, rr = x + 96, y + 96, 78
  panel(dl, x, y, w, 192)
  local live = not ss.idle
  local ringCol = live and SELECTED or GRAB
  if live then D.halo(dl, rcx, rcy, rr + 18, SELECTED, 0.10 + 0.05 * math.sin(t * 2)) end
  D.ring(dl, rcx, rcy, rr, DEEP, 14)
  D.arc(dl, rcx, rcy, rr, -math.pi / 2, -math.pi / 2 + frac * math.pi * 2, ringCol, 14)
  local ea = -math.pi / 2 + frac * math.pi * 2
  if live then
    D.circle(dl, rcx + math.cos(ea) * rr, rcy + math.sin(ea) * rr, 9 + 2 * math.sin(t * 6), SELECTED)
    if math.floor(t * 8) % 3 == 0 then F.twinkle(fx, rcx + math.cos(ea) * rr, rcy + math.sin(ea) * rr, SELECTED, 4) end
  end
  dtext(dl, FONT.body, 11, rcx, rcy - 36, DIM, "NEXT TIER IN", "center")
  dtext(dl, FONT.big, 30, rcx, rcy - 20, TEXT, fmtClock(G.TIER_SECONDS - st.pass.secs), "center")
  if live then
    local p = 0.6 + 0.4 * math.sin(t * 4)
    D.circle(dl, rcx - 30, rcy + 25, 4, A(SELECTED, p))
    dtext(dl, FONT.bold, 12, rcx - 22, rcy + 18, SELECTED, "RECORDING TIME")
  else
    dtext(dl, FONT.bold, 12, rcx, rcy + 18, DIM, "PAUSED - AWAY", "center")
    for i = 0, 2 do
      local zt = (t * 0.6 + i / 3) % 1
      dtext(dl, FONT.bold, 10 + zt * 10, rcx + 30 + zt * 30, rcy - 50 - zt * 40, A(DIM, 1 - zt), "z")
    end
  end
  -- Four pips: where this hour is.
  for i = 1, 4 do
    local on = (tier % 4) >= i
    local px = rcx - 27 + (i - 1) * 18
    if i == 4 then D.star(dl, px, rcy + 50, 7, on and PASS_COL or RULE)
    else D.circle(dl, px, rcy + 50, 5, on and PASS_COL or RULE) end
  end

  -- Beside the clock: the numbers that matter today.
  local sx = x + 200
  local today = st.days[G.dayKey(ui.epoch)] or 0
  local rows = {
    { "This session", fmtDur(ss.active) },
    { "Today", fmtDur(today) },
    { "This week", fmtDur(G.weekSeconds(st, ui.epoch)) },
    { "Check-in streak", st.checkin.streak .. " day" .. (st.checkin.streak == 1 and "" or "s") },
    { "Next big reward", "in " .. fmtDur((3 - tier % 4) * G.TIER_SECONDS + G.TIER_SECONDS - st.pass.secs) },
  }
  if st.boost > 0 then rows[#rows + 1] = { "XP Boost", fmtClock(st.boost) .. " left" } end
  for i, row in ipairs(rows) do
    local ry = y + 16 + (i - 1) * 27
    dtext(dl, FONT.body, 13, sx, ry, DIM, row[1])
    dtext(dl, FONT.bold, 15, sx + 130, ry - 1, TEXT, row[2])
  end

  -- Recent loot, if there's room beside.
  if w > 620 then
    local lx = x + w - 230
    dtext(dl, FONT.bold, 13, lx, y + 14, TEXT, "Recent loot")
    for i = 1, math.min(6, #st.recent) do
      local d = st.recent[i]
      local ry = y + 36 + (i - 1) * 24
      icon(dl, d.icon, lx + 8, ry + 8, 7, d.type == "coins" and COIN or RC(d.rarity))
      local s = d.text or ""
      if #s > 28 then s = s:sub(1, 26) .. "..." end
      dtext(dl, FONT.body, 13, lx + 22, ry, RC(d.rarity), s)
    end
  end
  y = y + 204

  -- The track: tiers sliding past as the clock runs, the hour ones bigger.
  y = sectionTitle(dl, x, y, "Battle pass track", "hover a tier to see what it holds")
  local trackH = 132
  panel(dl, x, y, w, trackH, DEEP)
  local pos = tier + frac
  local spacing = 92
  local nowX = x + math.min(w * 0.3, 240)
  local midY = y + 58
  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + trackH, true)
  D.line(dl, x, midY, x + w, midY, RULE, 4)
  D.line(dl, x, midY, nowX, midY, PASS_COL, 4)
  local first = math.max(1, math.floor(pos) - 3)
  local last = math.floor(pos) + math.ceil((w - (nowX - x)) / spacing) + 1
  local tipText
  for n = first, last do
    local cx = nowX + (n - pos) * spacing
    local h = headline(season, n)
    local big = h.kind ~= "small"
    local cw, ch = big and 76 or 64, big and 92 or 76
    local col = RC(h.best.rarity)
    local got = n <= tier
    local x1, y1 = cx - cw / 2, midY - ch / 2
    if n == tier + 1 then D.glow(dl, x1, y1, x1 + cw, y1 + ch, SELECTED, 8, 0.6 + 0.4 * math.sin(t * 5)) end
    if big and not got then D.halo(dl, cx, midY, cw * 0.9, col, 0.18) end
    D.rect(dl, x1, y1, x1 + cw, y1 + ch, got and GROUND or SUNKEN, 8)
    D.frame(dl, x1, y1, x1 + cw, y1 + ch, A(col, got and 0.5 or 1), 8, big and 2.5 or 1.5)
    local ic = (h.best.type == "coins") and COIN or col
    if h.best.type == "crate" then D.crate(dl, cx, midY - 6, big and 34 or 28, col)
    elseif h.best.type == "banner" then drawBanner(dl, cx, midY - 6, big and 18 or 14, h.best.data, t)
    else icon(dl, h.best.icon, cx, midY - 6, big and 16 or 13, A(ic, got and 0.5 or 1)) end
    dtext(dl, FONT.bold, 12, cx, y1 + ch - 18, got and DIM or TEXT, tostring(n), "center")
    if got then
      D.circle(dl, x1 + cw - 8, y1 + 8, 8, PASS_COL)
      D.check(dl, x1 + cw - 8, y1 + 8, 8, INK)
    end
    if big then dtext(dl, FONT.body, 10, cx, y1 + ch + 4, PASS_COL, h.kind == "big" and "HOUR" or h.kind:upper(), "center") end
    if mouseIn(x1, y1, x1 + cw, y1 + ch) then
      local lines = { "Tier " .. n .. (got and "  (unlocked)" or ("  -  in " .. fmtDur((n - pos) * G.TIER_SECONDS) .. " of active time")) }
      for _, d in ipairs(h.list) do
        local what = (d.type == "coins") and (d.amount .. " coins") or (L.RARITY[d.rarity].name .. " " .. (d.type == "crate" and "Crate" or d.name))
        lines[#lines + 1] = "  " .. what
      end
      tipText = table.concat(lines, "\n")
    end
  end
  -- The marker for now.
  D.line(dl, nowX, y + 6, nowX, y + trackH - 6, A(SELECTED, 0.8), 2)
  ImGui.DrawList_PopClipRect(dl)
  if tipText then ImGui.SetTooltip(ctx, tipText) end
  y = y + trackH + 14

  if w <= 620 and #st.recent > 0 then
    y = sectionTitle(dl, x, y, "Recent loot")
    for i = 1, math.min(6, #st.recent) do
      local d = st.recent[i]
      icon(dl, d.icon, x + 8, y + 8, 7, d.type == "coins" and COIN or RC(d.rarity))
      dtext(dl, FONT.body, 13, x + 22, y, RC(d.rarity), d.text or "")
      y = y + 22
    end
  end
  finish(x, y)
end

------------------------------------------------------------------------------
-- Quests: check-in, daily, weekly
------------------------------------------------------------------------------

local function questCard(dl, x, y, w, scope, i, q)
  local h = 66
  local done = q.done
  panel(dl, x, y, w, h, done and GROUND or SUNKEN)
  local col = RC(q.rarity)
  D.rect(dl, x, y, x + 4, y + h, col, 2)
  if done and not q.claimed then D.glow(dl, x, y, x + w, y + h, SELECTED, 6, 0.5 + 0.5 * math.sin(ui.tp * 5)) end
  dtext(dl, FONT.bold, 15, x + 14, y + 8, done and (q.claimed and DIM or TEXT) or TEXT, q.text)
  local key = scope .. i
  ui.qdisp = ui.qdisp or {}
  local real = q.progress / q.target
  ui.qdisp[key] = F.approach(ui.qdisp[key] or real, real, ui.dt, 6)
  local barW = math.max(80, w - 250)
  D.bar(dl, x + 14, y + 34, barW, 10, ui.qdisp[key], done and PASS_COL or col)
  local unit = G.QUESTS[q.kind] and G.QUESTS[q.kind].unit or 1
  local prog = string.format("%d / %d", math.floor(q.progress / unit), math.floor(q.target / unit))
  dtext(dl, FONT.body, 12, x + 14, y + 47, DIM, prog .. (unit == 60 and " min" or ""))
  local reward = fmtNum(q.coins) .. " coins  /  " .. q.xp .. " XP" .. (q.crate and ("  /  " .. L.RARITY[q.crate].name .. " Crate") or "")
  dtext(dl, FONT.body, 12, x + 14 + barW, y + 47, DIM, reward, "right")
  local bx = x + w - 110
  ImGui.PushID(ctx, key)
  if q.claimed then
    D.check(dl, bx + 50, y + 32, 16, PASS_COL)
  elseif done then
    if pickAt(bx, y + 20, "Claim", true, 96) then
      G.claimQuest(st, ss, scope, i)
      saveSoon()
    end
  else
    if pickAt(bx, y + 20, "Reroll", false, 96, not G.canReroll(st, scope)) then
      G.reroll(st, ss, scope, i, plugins)
      ui.qdisp[key] = 0
      saveSoon()
    end
    tip("Swap this quest for a new one. Uses a Quest Reroll (you have " .. (st.inv.tokens.reroll or 0) .. ")")
  end
  ImGui.PopID(ctx)
  return h + 8
end

local function pageQuests()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()

  -- Check-in: a week of boxes.
  y = sectionTitle(dl, x, y, "Daily check-in", "streak " .. st.checkin.streak .. "  /  best " .. st.checkin.best ..
                   "  /  Streak Freezes " .. (st.inv.tokens.freeze or 0))
  local avail = G.checkinAvailable(st, ui.epoch)
  local day, streak = G.checkinPreview(st, ui.epoch)
  local bw = math.min(84, (w - 6 * 8) / 7)
  for i = 1, 7 do
    local bx = x + (i - 1) * (bw + 8)
    local r = G.CHECKIN[i]
    local past = i < day or (not avail and i == day)
    local today = avail and i == day
    panel(dl, bx, y, bw, 86, past and GROUND or SUNKEN)
    if today then D.glow(dl, bx, y, bx + bw, y + 86, SELECTED, 6, 0.6 + 0.4 * math.sin(ui.tp * 4)) end
    dtext(dl, FONT.body, 11, bx + bw / 2, y + 6, today and SELECTED or DIM, "DAY " .. i, "center")
    if r.crate then local cr = (i == 7 and streak % 28 == 0) and 6 or r.crate; D.crate(dl, bx + bw / 2, y + 40, 30, RC(cr))
    elseif r.token then icon(dl, L.TOKENS[r.token].icon, bx + bw / 2, y + 40, 12, RC(3))
    else ICON.coin(dl, bx + bw / 2, y + 40, 12) end
    local what = r.coins and (r.coins .. "") or (r.crate and "crate" or "reroll")
    dtext(dl, FONT.body, 11, bx + bw / 2, y + 62, DIM, what, "center")
    if past then
      D.circle(dl, bx + bw - 10, y + 10, 8, PASS_COL)
      D.check(dl, bx + bw - 10, y + 10, 8, INK)
    end
  end
  y = y + 96
  if avail then
    if pickAt(x, y, "Check in for day " .. day, true, 180) then
      G.checkin(st, ss, ui.epoch)
      saveSoon()
    end
  else
    ImGui.SetCursorScreenPos(ctx, x, y + 3)
    dim("Checked in today. Next check-in in " .. fmtDur(G.secsToNextDay(ui.epoch)) .. ".")
  end
  y = y + 40

  for _, scope in ipairs({ "daily", "weekly" }) do
    local set = st[scope]
    local resets = (scope == "daily") and G.secsToNextDay(ui.epoch) or G.secsToNextWeek(ui.epoch)
    local bonus = (scope == "daily") and "Uncommon" or "Epic"
    y = sectionTitle(dl, x, y, scope == "daily" and "Daily quests" or "Weekly quests",
                     "new ones in " .. fmtDur(resets) .. (set.bonus and "  /  all done!" or ("  /  finish them all for an " .. bonus .. " Crate")))
    for i, q in ipairs(set.quests) do y = y + questCard(dl, x, y, w, scope, i, q) end
    y = y + 10
  end
  if #plugins > 0 then
    ImGui.SetCursorScreenPos(ctx, x, y)
    dim("Plugin quests choose from " .. pluginSource .. " (" .. #plugins .. " plugins). Change this on the Stats page.")
    y = y + 22
  end
  finish(x, y)
end

------------------------------------------------------------------------------
-- Shop: daily deals, passes, tokens and crates
------------------------------------------------------------------------------

local function shopItemCard(dl, x, y, cw, item)
  local ch = 128
  local afford = st.coins >= item.price
  panel(dl, x, y, cw, ch)
  local col = item.kind == "crate" and RC(item.rarity) or (item.kind == "pass" and SELECTED or RC(3))
  if item.kind == "crate" then D.crate(dl, x + 32, y + 34, 38, col)
  else icon(dl, item.icon, x + 32, y + 32, 17, item.kind == "pass" and CONTROL or col) end
  dtext(dl, FONT.bold, 15, x + 62, y + 12, TEXT, item.name)
  local owned = item.kind == "pass" and (st.inv.passes[item.id] or 0)
             or (item.kind == "token" and (st.inv.tokens[item.token] or 0))
             or (st.inv.crates[item.rarity] or 0)
  dtext(dl, FONT.body, 11, x + 62, y + 32, DIM, "you have " .. owned)
  wrapText(dl, FONT.body, 12, x + 12, y + 56, cw - 24, DIM, item.desc, 2)
  ImGui.PushID(ctx, item.id)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + ch - 32)
  if sure("buy" .. item.id, fmtNum(item.price) .. " coins", cw - 24, not afford) then
    G.buy(st, ss, item.id)
    saveSoon()
  end
  if not afford then
    tip(string.format("You have %d%% of the coins for this", math.floor(st.coins / item.price * 100)))
    D.bar(dl, x + 12, y + ch - 6, cw - 24, 3, st.coins / item.price, COIN)
  end
  ImGui.PopID(ctx)
end

local function pageShop()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()
  y = sectionTitle(dl, x, y, "Daily deals", "new deals in " .. fmtDur(G.secsToNextDay(ui.epoch)))
  local cols = math.max(1, math.min(3, math.floor((w + 12) / 220)))
  local cw = (w - (cols - 1) * 12) / cols
  for i, deal in ipairs(st.shop.deals) do
    local c = (i - 1) % cols
    local cx = x + c * (cw + 12)
    local cy = y + math.floor((i - 1) / cols) * 262
    dropCard(dl, cx, cy, cw, 214, deal.drop, ui.tp, 1)
    if deal.drop.type == "gear" and ImGui.IsWindowHovered(ctx) and mouseIn(cx, cy, cx + cw, cy + 214) then
      ImGui.SetTooltip(ctx, table.concat(gearLines(deal.drop, st.gear.equipped[deal.drop.slot]), "\n"))
    end
    ImGui.PushID(ctx, "deal" .. i)
    ImGui.SetCursorScreenPos(ctx, cx, cy + 220)
    if deal.bought then dim("  Sold out - see you tomorrow")
    elseif sure("deal" .. i, fmtNum(deal.price) .. " coins", cw, st.coins < deal.price) then
      G.buyDeal(st, ss, i)
      saveSoon()
    end
    ImGui.PopID(ctx)
  end
  y = y + math.ceil(#st.shop.deals / cols) * 262 + 6

  for _, group in ipairs({ { "pass", "Passes", "permission slips - redeem them from Loot when the time comes" },
                           { "token", "Tokens" }, { "crate", "Crates" } }) do
    y = sectionTitle(dl, x, y, group[2], group[3])
    local list = {}
    for _, item in ipairs(G.SHOP) do if item.kind == group[1] then list[#list + 1] = item end end
    local cols2 = math.max(1, math.floor((w + 12) / 230))
    local cw2 = (w - (cols2 - 1) * 12) / cols2
    for i, item in ipairs(list) do
      local c = (i - 1) % cols2
      shopItemCard(dl, x + c * (cw2 + 12), y + math.floor((i - 1) / cols2) * 140, cw2, item)
    end
    y = y + math.ceil(#list / cols2) * 140 + 8
  end
  finish(x, y)
end

------------------------------------------------------------------------------
-- Gear: what you wear, what it adds up to, the stash
------------------------------------------------------------------------------

local function gearTile(dl, x, y, s, item, selected)
  local col = RC(item.rarity)
  D.rect(dl, x, y, x + s, y + s, SUNKEN, 6)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x, y, x + s, y + s, A(col, 0.0), A(col, 0.0), A(col, 0.3), A(col, 0.3))
  D.frame(dl, x, y, x + s, y + s, col, 6, item.rarity >= L.EPIC and 2 or 1.2)
  if selected then D.glow(dl, x, y, x + s, y + s, SELECTED, 6, 1) end
  icon(dl, item.icon, x + s / 2, y + s / 2, s * 0.28, col)
  if item.power then D.star(dl, x + s - 9, y + 9, 5, RC(6), ui.tp) end
end

local function pageGear()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()
  y = sectionTitle(dl, x, y, "Equipped", "gear score " .. G.gearScore(st))
  local cols = (w >= 560) and 3 or 2
  local sw = (math.min(w, 760) - (cols - 1) * 10) / cols
  for i, slot in ipairs(L.SLOTS) do
    local c = (i - 1) % cols
    local sx, sy = x + c * (sw + 10), y + math.floor((i - 1) / cols) * 74
    local item = st.gear.equipped[slot.id]
    panel(dl, sx, sy, sw, 66)
    ImGui.SetCursorScreenPos(ctx, sx, sy)
    ImGui.InvisibleButton(ctx, "slot" .. slot.id, sw, 66)
    if item then
      gearTile(dl, sx + 6, sy + 6, 54, item, ui.selected == item.uid)
      dtext(dl, FONT.body, 11, sx + 68, sy + 8, DIM, slot.name:upper())
      wrapText(dl, FONT.bold, 14, sx + 68, sy + 24, sw - 76, RC(item.rarity), item.name, 2, 1)
      if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, table.concat(gearLines(item), "\n")) end
    else
      D.frame(dl, sx + 6, sy + 6, sx + 60, sy + 60, RULE, 6, 1)
      icon(dl, slot.icon, sx + 33, sy + 33, 13, RULE)
      dtext(dl, FONT.body, 11, sx + 68, sy + 8, DIM, slot.name:upper())
      dtext(dl, FONT.body, 13, sx + 68, sy + 26, DIM, "empty")
    end
  end
  y = y + math.ceil(#L.SLOTS / cols) * 74 + 6

  -- What it all adds up to.
  local sums = {}
  for _, a in ipairs(L.AFFIXES) do
    local v = G.bonus(st, a.id)
    if v > 0 then sums[#sums + 1] = L.statLine(a.id, v) end
  end
  for _, p in ipairs(L.POWERS) do if G.hasPower(st, p.id) then sums[#sums + 1] = p.name .. ": " .. p.text end end
  if #sums > 0 then
    y = sectionTitle(dl, x, y, "Your bonuses")
    for _, line in ipairs(sums) do
      dtext(dl, FONT.body, 13, x + 6, y, TEXT, line)
      y = y + 19
    end
    y = y + 8
  end

  -- The stash.
  y = sectionTitle(dl, x, y, "Stash", #st.gear.stash .. " / " .. G.STASH_MAX .. "  /  click an item to look at it")
  local s = 54
  local per = math.max(1, math.floor((w + 6) / (s + 6)))
  local selItem
  for i, item in ipairs(st.gear.stash) do
    local c = (i - 1) % per
    local tx, ty = x + c * (s + 6), y + math.floor((i - 1) / per) * (s + 6)
    ImGui.SetCursorScreenPos(ctx, tx, ty)
    if ImGui.InvisibleButton(ctx, "stash" .. item.uid, s, s) then ui.selected = item.uid end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, table.concat(gearLines(item, st.gear.equipped[item.slot]), "\n"))
    end
    gearTile(dl, tx, ty, s, item, ui.selected == item.uid)
    if ui.selected == item.uid then selItem = item end
  end
  if #st.gear.stash == 0 then
    ImGui.SetCursorScreenPos(ctx, x, y)
    dim("Nothing here yet. Gear drops from pass tiers, crates and the shop's daily deals.")
    y = y + 24
  else
    y = y + math.ceil(#st.gear.stash / per) * (s + 6) + 8
  end

  if selItem then
    local lines = gearLines(selItem, st.gear.equipped[selItem.slot])
    local ph = 30 + #lines * 18 + 40
    panel(dl, x, y, w, ph)
    D.frame(dl, x, y, x + w, y + ph, RC(selItem.rarity), 6, 1.5)
    dtext(dl, FONT.bold, 16, x + 12, y + 10, RC(selItem.rarity), lines[1])
    for i = 2, #lines do dtext(dl, FONT.body, 13, x + 12, y + 16 + i * 18, i == 2 and DIM or TEXT, lines[i]) end
    ImGui.PushID(ctx, "sel" .. selItem.uid)
    if pickAt(x + 12, y + ph - 34, "Equip", true, 110) then
      G.equip(st, ss, selItem.uid)
      F.burst(fx, ui.lastClick[1], ui.lastClick[2], 30, { col = RC(selItem.rarity), speed = 260 })
      ui.selected = nil
      saveSoon()
    end
    ImGui.SameLine(ctx)
    if sure("salvage" .. selItem.uid, "Salvage for " .. L.sellValue(selItem) .. " coins", 200) then
      G.salvage(st, ss, selItem.uid)
      F.burst(fx, ui.lastClick[1], ui.lastClick[2], 20, { col = COIN, speed = 200 })
      ui.selected = nil
      saveSoon()
    end
    ImGui.PopID(ctx)
    y = y + ph + 10
  end

  if #st.gear.stash > 0 then
    ImGui.SetCursorScreenPos(ctx, x, y)
    if sure("junk2", "Salvage all Poor and Common", 230) then G.salvageUpTo(st, ss, 2); saveSoon() end
    ImGui.SameLine(ctx)
    if sure("junk3", "...and Uncommon", 150) then G.salvageUpTo(st, ss, 3); saveSoon() end
    y = y + 34
  end
  finish(x, y)
end

------------------------------------------------------------------------------
-- Loot: crates, passes, tokens, cosmetics
------------------------------------------------------------------------------

local function pageLoot()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()
  y = sectionTitle(dl, x, y, "Loot crates", "from levelling up, pass tiers, quests and the shop")
  local tw = 100
  local per = math.max(1, math.floor((w + 8) / (tw + 8)))
  local shown = 0
  for r = 2, 7 do
    local n = st.inv.crates[r]
    local c = shown % per
    local tx, ty = x + c * (tw + 8), y + math.floor(shown / per) * 140
    shown = shown + 1
    panel(dl, tx, ty, tw, 132)
    local bob = n > 0 and math.sin(ui.tp * 3 + r) * 3 or 0
    if n > 0 then D.halo(dl, tx + tw / 2, ty + 42, 34, RC(r), 0.25) end
    D.crate(dl, tx + tw / 2, ty + 40 + bob, 46, n > 0 and RC(r) or RULE, n > 0 and math.sin(ui.tp * 2 + r) * 0.04 or 0)
    dtext(dl, FONT.body, 11, tx + tw / 2, ty + 74, RC(r), L.RARITY[r].name:upper(), "center")
    dtext(dl, FONT.bold, 13, tx + tw / 2, ty + 88, n > 0 and TEXT or DIM, "x" .. n, "center")
    ImGui.PushID(ctx, "crate" .. r)
    if pickAt(tx + 8, ty + 104, "Open", n > 0, tw - 16, n == 0) then
      G.openCrate(st, ss, r)
      saveSoon()
    end
    ImGui.PopID(ctx)
  end
  y = y + math.ceil(shown / per) * 140 + 6

  -- Passes.
  y = sectionTitle(dl, x, y, "Passes", "permission slips you've bought")
  local any = false
  for _, item in ipairs(G.SHOP) do
    local n = item.kind == "pass" and (st.inv.passes[item.id] or 0) or 0
    if n > 0 then
      any = true
      panel(dl, x, y, w, 46)
      icon(dl, item.icon, x + 24, y + 23, 13, CONTROL)
      dtext(dl, FONT.bold, 15, x + 48, y + 6, TEXT, item.name .. "  x" .. n)
      dtext(dl, FONT.body, 12, x + 48, y + 26, DIM, item.desc)
      ImGui.PushID(ctx, "redeem" .. item.id)
      ImGui.SetCursorScreenPos(ctx, x + w - 130, y + 10)
      if sure("redeem" .. item.id, "Redeem", 118) then
        G.redeem(st, ss, item.id, ui.epoch)
        saveSoon()
      end
      tip("Use it now: this is your permission.")
      ImGui.PopID(ctx)
      y = y + 52
    end
  end
  if not any then
    ImGui.SetCursorScreenPos(ctx, x, y)
    dim("None yet. Buy passes in the Shop - a takeaway, a movie, a gaming session.")
    y = y + 26
  end
  y = y + 6

  -- Tokens.
  y = sectionTitle(dl, x, y, "Tokens")
  for _, id in ipairs({ "reroll", "freeze", "boost" }) do
    local tk = L.TOKENS[id]
    local n = st.inv.tokens[id] or 0
    panel(dl, x, y, w, 46)
    icon(dl, tk.icon, x + 24, y + 23, 12, RC(3))
    dtext(dl, FONT.bold, 15, x + 48, y + 6, TEXT, tk.name .. "  x" .. n)
    local how = (id == "reroll") and "Use it on a quest on the Quests page"
             or ((id == "freeze") and "Used by itself when you miss a day" or tk.text)
    dtext(dl, FONT.body, 12, x + 48, y + 26, DIM, how)
    if id == "boost" then
      ImGui.SetCursorScreenPos(ctx, x + w - 130, y + 10)
      if pick("Activate", n > 0, 118, n == 0) then G.useBoost(st, ss); F.flash(fx, 0.25, SELECTED); saveSoon() end
    end
    y = y + 52
  end
  y = y + 6

  -- Cosmetics: titles and banners.
  y = sectionTitle(dl, x, y, "Titles", "shown beside your name")
  ImGui.SetCursorScreenPos(ctx, x, y)
  local avail = w
  local rowX = 0
  if pick("None", st.profile.title == 0, 0) then st.profile.title = 0; saveSoon() end
  rowX = rowX + measure(FONT.body, 14, "None") + 26
  for i, tt in ipairs(st.cos.titles) do
    local tw2 = measure(FONT.body, 14, tt.text) + 26
    if rowX + tw2 < avail then ImGui.SameLine(ctx) else rowX = 0 end
    rowX = rowX + tw2 + 8
    ImGui.PushID(ctx, "title" .. i)
    if pick(tt.text, st.profile.title == i, 0) then st.profile.title = i; saveSoon() end
    tip(L.RARITY[tt.rarity].name .. " title")
    ImGui.PopID(ctx)
  end
  local _, cy = ImGui.GetCursorScreenPos(ctx)
  y = cy + 10

  y = sectionTitle(dl, x, y, "Banners", "click one to wear it")
  local bs = 64
  local bper = math.max(1, math.floor((w + 8) / (bs + 8)))
  for i, b in ipairs(st.cos.banners) do
    local c = (i - 1) % bper
    local bx, by = x + c * (bs + 8), y + math.floor((i - 1) / bper) * (bs + 22)
    panel(dl, bx, by, bs, bs)
    if st.profile.banner == i then D.glow(dl, bx, by, bx + bs, by + bs, SELECTED, 6, 1) end
    drawBanner(dl, bx + bs / 2, by + bs / 2, bs * 0.34, b.data, ui.tp)
    ImGui.SetCursorScreenPos(ctx, bx, by)
    if ImGui.InvisibleButton(ctx, "banner" .. i, bs, bs) then
      st.profile.banner = (st.profile.banner == i) and 0 or i
      saveSoon()
    end
    tip(b.text .. " (" .. L.RARITY[b.rarity].name .. ")")
    local nm = b.text
    if measure(FONT.body, 11, nm) > bs + 6 then nm = nm:match("^(%S+)") or nm end
    dtext(dl, FONT.body, 11, bx + bs / 2, by + bs + 3, RC(b.rarity), nm, "center")
  end
  if #st.cos.banners == 0 then
    ImGui.SetCursorScreenPos(ctx, x, y)
    dim("No banners yet. They drop from tiers and crates.")
    y = y + 24
  else
    y = y + math.ceil(#st.cos.banners / bper) * (bs + 22) + 6
  end

  if #st.log > 0 then
    y = sectionTitle(dl, x, y, "Treats you've had")
    for i = 1, math.min(8, #st.log) do
      local e = st.log[i]
      dtext(dl, FONT.body, 13, x + 6, y, TEXT, os.date("%a %d %b", e.t) .. "  -  " .. e.name)
      y = y + 19
    end
  end
  finish(x, y)
end

------------------------------------------------------------------------------
-- Ideas: the vault
------------------------------------------------------------------------------

local function drumGrid(dl, x, y, w, drums)
  local rows = drums.rows
  local steps = math.min(32, drums.steps)
  local cell = math.max(4, math.min(12, (w - 70) / steps - 1))
  for ri, row in ipairs(rows) do
    local ry = y + (ri - 1) * (cell + 2)
    dtext(dl, FONT.body, 10, x, ry - 1, DIM, row.name)
    for i = 1, steps do
      local cx = x + 64 + (i - 1) * (cell + 1) + math.floor((i - 1) / 4) * 2
      local v = row.steps[i]
      D.rect(dl, cx, ry, cx + cell, ry + cell, v > 0 and A(SELECTED, 0.35 + v / 200) or RULE, 2)
    end
  end
  return #rows * (cell + 2)
end

local FILTERS = { { "all", "All" }, { "fav", "Starred" } }
for _, d in ipairs(L.IDEAS) do FILTERS[#FILTERS + 1] = { d.id, d.label } end

local function ideaCard(dl, x, y, w, v, visible)
  local textW = w - 28
  local mainLines = wrap(FONT.bold, 16, v.text, textW)
  local subLines = (v.sub ~= "") and wrap(FONT.body, 12, v.sub, textW) or {}
  local h = 36 + #mainLines * 20 + #subLines * 16 + 44
  local drums = v.data and v.data.drums
  if drums then h = h + #drums.rows * 12 + 8 end
  if not visible(y, h) then return h + 8 end
  local col = RC(v.rarity)
  panel(dl, x, y, w, h)
  D.rect(dl, x, y, x + 4, y + h, col, 2)
  icon(dl, L.IDEAS[v.kind] and L.IDEAS[v.kind].icon or "note", x + 22, y + 18, 9, col)
  dtext(dl, FONT.body, 12, x + 38, y + 10, col, L.RARITY[v.rarity].name .. " " .. v.name)
  dtext(dl, FONT.body, 11, x + w - 12, y + 11, DIM, os.date("%d %b", v.t or 0) .. (v.used and "  /  used" or ""), "right")
  local ty = y + 32
  for i, line in ipairs(mainLines) do dtext(dl, FONT.bold, 16, x + 14, ty + (i - 1) * 20, TEXT, line) end
  ty = ty + #mainLines * 20 + 2
  for i, line in ipairs(subLines) do dtext(dl, FONT.body, 12, x + 14, ty + (i - 1) * 16, DIM, line) end
  ty = ty + #subLines * 16 + 4
  if drums then ty = ty + drumGrid(dl, x + 14, ty, w - 28, drums) + 6 end

  ImGui.PushID(ctx, "idea" .. v.uid)
  ImGui.SetCursorScreenPos(ctx, x + 14, y + h - 34)
  if pick(v.fav and "Starred" or "Star", v.fav, 80) then v.fav = not v.fav; saveSoon() end
  tip("Starred ideas are never cleared out of the vault")
  ImGui.SameLine(ctx)
  if pick("Copy", false, 70) then
    local text = v.name .. ": " .. v.text .. (v.sub ~= "" and ("\n" .. v.sub) or "")
    if v.data and v.data.text then text = text .. "\n" .. v.data.text end
    ImGui.SetClipboardText(ctx, text)
    F.toast(fx, { text = "Copied", sub = v.text, icon = "scroll", rarity = 2, life = 2 })
  end
  if v.data and v.data.block then
    ImGui.SameLine(ctx)
    if pick("Insert MIDI", false, 110) then
      local res, made = W.insert(v.data.block)
      if res == W.OK then
        G.ideaUsed(st, ss, v.uid)
        F.toast(fx, { text = "In your project", sub = made and "On a new track at the edit cursor" or "On the selected track at the edit cursor", icon = "note", rarity = v.rarity })
        saveSoon()
      end
    end
    tip("Puts it on the selected track at the edit cursor (or a new track if none is selected)")
  end
  if v.data and v.data.sections then
    ImGui.SameLine(ctx)
    if pick("Add regions", false, 110) then
      if W.addRegions(v.data.sections) == W.OK then
        G.ideaUsed(st, ss, v.uid)
        F.toast(fx, { text = "Regions added", sub = "From the edit cursor", icon = "blocks", rarity = v.rarity })
        saveSoon()
      end
    end
    tip("Lays the sections out as regions from the edit cursor")
  end
  if v.data and v.data.bpm then
    ImGui.SameLine(ctx)
    if pick("Set tempo " .. v.data.bpm, false, 0) then
      W.setTempo(v.data.bpm)
      G.ideaUsed(st, ss, v.uid)
      saveSoon()
    end
  end
  ImGui.SameLine(ctx)
  if sure("del" .. v.uid, "Delete", 70) then G.removeIdea(st, v.uid); saveSoon() end
  ImGui.PopID(ctx)
  return h + 8
end

local function pageIdeas()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()
  y = sectionTitle(dl, x, y, "Idea vault", #st.vault .. " ideas  /  newest first")
  ImGui.SetCursorScreenPos(ctx, x, y)
  local rowX = 0
  for i, f in ipairs(FILTERS) do
    local bw = measure(FONT.body, 14, f[2]) + 18
    if i > 1 then
      if rowX + bw < w then ImGui.SameLine(ctx) else rowX = 0 end
    end
    rowX = rowX + bw + 8
    ImGui.PushID(ctx, "filter" .. i)
    if pick(f[2], ui.filter == f[1], 0) then ui.filter = f[1] end
    ImGui.PopID(ctx)
  end
  local _, cy = ImGui.GetCursorScreenPos(ctx)
  y = cy + 8
  -- Only the cards in view are drawn; the rest only take up room.
  local _, wy = ImGui.GetWindowPos(ctx)
  local _, wh = ImGui.GetWindowSize(ctx)
  local function visible(top, h) return top + h >= wy and top <= wy + wh end
  local n = 0
  for i = #st.vault, 1, -1 do
    local v = st.vault[i]
    if ui.filter == "all" or (ui.filter == "fav" and v.fav) or v.kind == ui.filter then
      y = y + ideaCard(dl, x, y, w, v, visible)
      n = n + 1
    end
  end
  if n == 0 then
    ImGui.SetCursorScreenPos(ctx, x, y)
    dim("No ideas here yet. They drop from pass tiers and crates - keep making music.")
    y = y + 24
  end
  finish(x, y)
end

------------------------------------------------------------------------------
-- Trophies
------------------------------------------------------------------------------

local function pageTrophies()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()
  local have, all = G.achievementTotals(st)
  y = sectionTitle(dl, x, y, "Achievements", have .. " of " .. all .. " unlocked")
  D.bar(dl, x, y, w, 8, have / all, RC(6))
  y = y + 18
  local cols = math.max(1, math.floor((w + 10) / 280))
  local cw = (w - (cols - 1) * 10) / cols
  for i, a in ipairs(G.ACHIEVEMENTS) do
    local c = (i - 1) % cols
    local ax, ay = x + c * (cw + 10), y + math.floor((i - 1) / cols) * 100
    local got = st.ach[a.id] or 0
    local done = got == #a.goals
    panel(dl, ax, ay, cw, 92, done and GROUND or SUNKEN)
    if done then D.frame(dl, ax, ay, ax + cw, ay + 92, RC(6), 6, 2) end
    icon(dl, "trophy", ax + 24, ay + 26, 13, got > 0 and (done and RC(6) or RC(math.min(7, 2 + got))) or RULE)
    dtext(dl, FONT.bold, 14, ax + 46, ay + 10, TEXT, a.name .. (got > 0 and (" " .. G.roman(got)) or ""))
    local nextGoal = a.goals[math.min(#a.goals, got + 1)]
    local v = a.value(st)
    local line = done and ("All done. Title earned: " .. a.title) or string.format(a.fmt, G.fmtGoal(nextGoal))
    wrapText(dl, FONT.body, 12, ax + 46, ay + 30, cw - 56, DIM, line, 2)
    local prev = got > 0 and a.goals[got] or 0
    local frac = done and 1 or math.max(0, (v - prev) / (nextGoal - prev))
    D.bar(dl, ax + 46, ay + 66, cw - 120, 7, frac, done and RC(6) or XP_COL)
    dtext(dl, FONT.body, 11, ax + cw - 10, ay + 63, DIM,
          (v >= 100 and fmtNum(v) or string.format("%.1f", v)):gsub("%.0$", "") .. " / " .. G.fmtGoal(nextGoal), "right")
    for p = 1, #a.goals do D.circle(dl, ax + 46 + (p - 1) * 9, ay + 82, 3, p <= got and RC(math.min(7, 1 + p)) or RULE) end
  end
  y = y + math.ceil(#G.ACHIEVEMENTS / cols) * 100
  finish(x, y)
end

------------------------------------------------------------------------------
-- Stats and settings
------------------------------------------------------------------------------

local function pageStats()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y, w = area()
  local s = st.stats
  local plugCount = 0
  for _ in pairs(st.plugins) do plugCount = plugCount + 1 end
  local numbers = {
    { "Time making music", fmtDur(s.active) }, { "Longest session", fmtDur(s.longest) },
    { "Level", tostring(st.level) }, { "Pass tiers unlocked", fmtNum(s.tiers) },
    { "Coins earned", fmtNum(s.coinsEarned) }, { "Quests done", fmtNum(s.dailies + s.weeklies) },
    { "Crates opened", fmtNum(s.crates) }, { "Ideas collected", fmtNum(s.ideas) },
    { "Tracks created", fmtNum(s.tracks) }, { "MIDI notes written", fmtNum(s.notes) },
    { "Plugins discovered", fmtNum(plugCount) }, { "Treats redeemed", fmtNum(s.redeemed) },
  }
  y = sectionTitle(dl, x, y, "All time")
  local cols = math.max(2, math.floor((w + 10) / 190))
  local cw = (w - (cols - 1) * 10) / cols
  for i, n in ipairs(numbers) do
    local c = (i - 1) % cols
    local nx, ny = x + c * (cw + 10), y + math.floor((i - 1) / cols) * 58
    panel(dl, nx, ny, cw, 50)
    dtext(dl, FONT.body, 11, nx + 10, ny + 7, DIM, n[1]:upper())
    dtext(dl, FONT.bold, 18, nx + 10, ny + 22, TEXT, n[2])
  end
  y = y + math.ceil(#numbers / cols) * 58 + 8

  -- The last fortnight, bars growing in when the page opens.
  y = sectionTitle(dl, x, y, "The last 14 days", "minutes of active music-making")
  local chartH = 120
  panel(dl, x, y, w, chartH + 30, DEEP)
  local most = 1
  local days = {}
  for i = 13, 0, -1 do
    local k = G.dayKey(ui.epoch - i * 86400)
    days[#days + 1] = { k = k, v = st.days[k] or 0 }
    most = math.max(most, st.days[k] or 0)
  end
  local grow = F.ease.outCubic((ui.tp - (ui.tabT or 0)) / 0.8)
  local bw = (w - 20) / 14
  for i, d in ipairs(days) do
    local bh = (d.v / most) * (chartH - 20) * grow
    local bx = x + 10 + (i - 1) * bw
    D.rect(dl, bx + 3, y + chartH - bh, bx + bw - 3, y + chartH, i == 14 and SELECTED or XP_COL, 3)
    if d.v > 0 then dtext(dl, FONT.body, 10, bx + bw / 2, y + chartH - bh - 13, DIM, tostring(math.floor(d.v / 60)), "center") end
    dtext(dl, FONT.body, 10, bx + bw / 2, y + chartH + 8, DIM, d.k:sub(9, 10), "center")
  end
  y = y + chartH + 42

  local function top(tbl, n)
    local list = {}
    for k, v in pairs(tbl) do list[#list + 1] = { k, v } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    while #list > n do table.remove(list) end
    return list
  end
  local half = (w >= 640) and (w - 12) / 2 or w
  local yTop = y
  y = sectionTitle(dl, x, y, "Most-worked projects")
  local tp = top(st.projects, 6)
  for _, p in ipairs(tp) do
    D.bar(dl, x, y + 16, half - 10, 5, p[2] / math.max(1, tp[1][2]), PASS_COL)
    dtext(dl, FONT.body, 13, x, y, TEXT, p[1])
    dtext(dl, FONT.body, 12, x + half - 10, y, DIM, fmtDur(p[2]), "right")
    y = y + 28
  end
  local px = (half < w) and (x + half + 12) or x
  local py = (half < w) and yTop or (y + 10)
  py = sectionTitle(dl, px, py, "Most-used plugins")
  local tpl = top(st.plugins, 6)
  for _, p in ipairs(tpl) do
    D.bar(dl, px, py + 16, half - 10, 5, p[2] / math.max(1, tpl[1][2]), RC(5))
    dtext(dl, FONT.body, 13, px, py, TEXT, p[1])
    dtext(dl, FONT.body, 12, px + half - 10, py, DIM, tostring(p[2]), "right")
    py = py + 28
  end
  y = math.max(y, py) + 12

  -- Settings.
  y = sectionTitle(dl, x, y, "Settings")
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.SetNextItemWidth(ctx, 220)
  local changed, name = ImGui.InputText(ctx, "Your name", ui.nameBuf or st.profile.name)
  if changed then
    ui.nameBuf = name
    if name:match("%S") then st.profile.name = name:sub(1, 32); saveSoon() end
  end
  ImGui.SetNextItemWidth(ctx, 220)
  local mins = math.floor(st.settings.idle / 60)
  local ch2, nm = ImGui.SliderInt(ctx, "Minutes before you count as away", mins, 1, 15)
  if ch2 then st.settings.idle = nm * 60; saveSoon() end
  tip("With nothing happening for this long, the clock stops until you're back. Playback gives you at least 8 minutes.")
  local on = W.autostartOn()
  local ch3, want = ImGui.Checkbox(ctx, "Start the battle pass when REAPER starts", on)
  if ch3 then
    if W.setAutostart(want, SCRIPT) then ui.status = want and "It will start with REAPER." or "It won't start with REAPER any more."
    else ui.status = "Could not change REAPER's startup script." end
  end
  if pick("Open my plugin list", false, 180) then
    local path = W.ensurePluginFile()
    if not W.open(path) then ImGui.SetClipboardText(ctx, path); ui.status = "The list is at " .. path .. " (path copied)" end
  end
  tip("Write the plugins you want quests about, one a line. Leave it empty to use everything installed.")
  ImGui.SameLine(ctx)
  if pick("Reload plugins", false, 140) then
    plugins, pluginSource = W.plugins()
    ui.status = "Quests now choose from " .. pluginSource .. ": " .. #plugins .. " plugins (new quests from tomorrow, or reroll one)."
  end
  dim("Plugin quests use " .. pluginSource .. " (" .. #plugins .. ").  Progress is saved in " .. W.dataDir())
  if ui.status ~= "" then dim(ui.status) end
  local _, endY = ImGui.GetCursorScreenPos(ctx)
  finish(x, endY)
end

local PAGES = { pass = pagePass, quests = pageQuests, shop = pageShop, gear = pageGear,
                loot = pageLoot, ideas = pageIdeas, trophies = pageTrophies, stats = pageStats }

------------------------------------------------------------------------------
-- The stage: rewards revealed one at a time over the page
------------------------------------------------------------------------------

local function closeModal()
  table.remove(ui.modals, 1)
  saveSoon()
end

local function bigTitle(dl, cx, y, text, col, t, size)
  local k = F.ease.outBack(t / 0.5)
  local sz = (size or 34) * (0.4 + 0.6 * k)
  dtext(dl, FONT.huge, sz, cx, y + (size or 34) * (1 - k) * 0.5, A(col, math.min(1, t * 3)), text, "center")
end

local TIER_TITLES = { small = "TIER %d UNLOCKED", big = "HOUR COMPLETE!  TIER %d", milestone = "MILESTONE  TIER %d",
                      legendary = "LEGENDARY TIER %d", finale = "SEASON PASS COMPLETE!" }

local function collect(m)
  for i, d in ipairs(m.drops or {}) do
    local p = m.pos and m.pos[i]
    if p and d.type == "coins" then F.coins(fx, p[1], p[2], math.min(30, 6 + math.floor(d.amount / 8)), ui.coinPos[1], ui.coinPos[2]) end
    if p and d.type == "xp" then F.floater(fx, "+" .. d.amount .. " XP", p[1], p[2], XP_COL, true) end
  end
  closeModal()
end

local function modalReward(m, dl, x, y, w, h)
  local t = m.t
  local cx = x + w / 2
  local best = 1
  for _, d in ipairs(m.drops) do best = math.max(best, d.rarity) end
  if m.crate then best = math.max(best, m.crate) end
  local col = RC(best)
  D.rect(dl, x, y, x + w, y + h, A(DEEP, math.min(1, t * 4) * 0.95), 8)

  if m.crate and m.phase ~= "open" then
    local cc = RC(m.crate)
    local cy = y + h * 0.45
    D.rays(dl, cx, cy, math.max(w, h), 16, t * 0.3, A(cc, 0.09))
    D.halo(dl, cx, cy, 120, cc, 0.3)
    local ang, s = 0, 130
    if m.phase == "closed" then
      cy = cy + math.sin(t * 2.5) * 6
      bigTitle(dl, cx, y + 24, L.RARITY[m.crate].name:upper() .. " CRATE", cc, t, 34)
      dtext(dl, FONT.bold, 15, cx, y + h - 70, A(TEXT, 0.6 + 0.4 * math.sin(t * 4)), "Click the crate to open it", "center")
      ImGui.SetCursorScreenPos(ctx, cx - s * 0.6, cy - s * 0.5)
      if ImGui.InvisibleButton(ctx, "crate", s * 1.2, s) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
        m.phase, m.t = "shake", 0
      end
      if ImGui.IsItemHovered(ctx) then s = s * 1.05 end
    else
      local k = math.min(1, t / 1.1)
      ang = math.sin(t * 46) * 0.13 * k
      s = 130 * (1 + 0.1 * k)
      bigTitle(dl, cx, y + 24, L.RARITY[m.crate].name:upper() .. " CRATE", cc, 1, 34)
      if fx.rnd() < 0.3 + k then
        F.burst(fx, cx + (fx.rnd() - 0.5) * s, cy + (fx.rnd() - 0.5) * s * 0.6, 1, { col = cc, speed = 160 + 200 * k, life = 0.6 })
      end
      F.shake(fx, 3 * k)
      if t >= 1.1 then
        m.phase, m.t = "open", 0
        F.flash(fx, 0.9, cc)
        F.ring(fx, cx, cy, cc, 260, 0.8)
        F.ring(fx, cx, cy, BRIGHT, 180, 0.5)
        F.burst(fx, cx, cy, 90, { cols = { cc, BRIGHT, shade(cc, 0.4) }, speed = 520, life = 1.2, size = 4 })
        if m.crate >= L.EPIC then F.confetti(fx, cx, cy, 120, 520) end
        F.shake(fx, 14)
      end
    end
    D.crate(dl, cx, cy, s, cc, ang, 0)
    return
  end

  local title
  if m.crate then title = "YOUR " .. L.RARITY[m.crate].name:upper() .. " CRATE HELD..."
  else title = string.format(TIER_TITLES[m.tierKind] or TIER_TITLES.small, m.tier) end
  bigTitle(dl, cx, y + 18, title, m.tierKind and m.tierKind ~= "small" and PASS_COL or TEXT, t, 30)
  if m.tier then
    dtext(dl, FONT.body, 13, cx, y + 58, DIM, L.seasonName(st.pass.season) .. "  /  " ..
          (m.tierKind == "small" and "fifteen more minutes of music" or "a whole hour of music"), "center")
  end

  local n = #m.drops
  local gap = 14
  local cw = math.min(200, (w - 40 - (n - 1) * gap) / n)
  local ch = math.min(270, math.max(200, h - 170))
  local total = n * cw + (n - 1) * gap
  local cardsY = y + 86
  D.rays(dl, cx, cardsY + ch / 2, math.max(w, h), 18, t * 0.25, A(col, 0.07 + 0.03 * math.sin(t * 2)))
  m.shown, m.pos = m.shown or {}, m.pos or {}
  local lastAt = 0
  for i, d in ipairs(m.drops) do
    local at = 0.4 + (i - 1) * 0.38
    lastAt = at
    local kx = cx - total / 2 + (i - 1) * (cw + gap)
    local k = (t - at) / 0.45
    m.pos[i] = { kx + cw / 2, cardsY + ch / 2 }
    if k > 0 then
      if not m.shown[i] then
        m.shown[i] = true
        local dc = RC(d.rarity)
        F.burst(fx, kx + cw / 2, cardsY + ch / 2, 20 + d.rarity * 8, { cols = { dc, BRIGHT }, speed = 240 + d.rarity * 40 })
        F.ring(fx, kx + cw / 2, cardsY + ch / 2, dc, 90 + d.rarity * 10, 0.6)
        if d.rarity >= L.LEGENDARY then F.flash(fx, 0.5, dc); F.confetti(fx, kx + cw / 2, cardsY + 20, 60, 380) end
        if d.rarity >= L.MYTHIC then F.shake(fx, 16) end
      end
      dropCard(dl, kx, cardsY, cw, ch, d, t, F.ease.outBack(k))
      if mouseIn(kx, cardsY, kx + cw, cardsY + ch) then
        if d.type == "gear" then ImGui.SetTooltip(ctx, table.concat(gearLines(d, st.gear.equipped[d.slot]), "\n"))
        elseif d.type == "idea" then ImGui.SetTooltip(ctx, d.text .. "\n" .. (d.sub or "") .. "\n\nIt's in your Idea vault.") end
      end
    else
      -- Face down until its turn.
      D.rect(dl, kx, cardsY, kx + cw, cardsY + ch, GROUND, 8)
      D.frame(dl, kx, cardsY, kx + cw, cardsY + ch, RULE, 8, 1.5)
      dtext(dl, FONT.huge, 40, kx + cw / 2, cardsY + ch / 2 - 22, RULE, "?", "center")
    end
  end
  local ready = t > lastAt + 0.5
  if ready then
    if pickAt(cx - 70, cardsY + ch + 18, "Collect", true, 140) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then collect(m) end
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then m.t = lastAt + 0.5 end
end

local function modalLevel(m, dl, x, y, w, h)
  local t = m.t
  local cx, cy = x + w / 2, y + h * 0.38
  if not m.started then
    m.started = true
    F.ring(fx, cx, cy, XP_COL, 300, 0.9)
    F.ring(fx, cx, cy, BRIGHT, 200, 0.6)
    F.confetti(fx, cx, cy, 110, 480)
    F.flash(fx, 0.6, XP_COL)
  end
  D.rect(dl, x, y, x + w, y + h, A(DEEP, math.min(1, t * 4) * 0.95), 8)
  D.rays(dl, cx, cy, math.max(w, h), 20, t * 0.35, A(XP_COL, 0.10))
  D.halo(dl, cx, cy, 110, XP_COL, 0.35)
  local k = F.ease.outBack(t / 0.6)
  dtext(dl, FONT.huge, 52 * (2 - k), cx, y + 20, A(TEXT, math.min(1, t * 3)), "LEVEL UP!", "center")
  local kn = F.ease.outElastic(math.max(0, t - 0.25) / 0.9)
  if kn > 0 then dtext(dl, FONT.huge, 96 * kn, cx, cy - 48 * kn, BRIGHT, tostring(m.level), "center") end
  if t > 0.9 then
    local cc = RC(m.crate)
    D.crate(dl, cx, cy + 110 + math.sin(t * 3) * 4, 60, cc, math.sin(t * 2) * 0.05)
    dtext(dl, FONT.bold, 15, cx, cy + 150, cc, "+ " .. L.RARITY[m.crate].name .. " Crate", "center")
  end
  if t > 1.2 then
    if pickAt(cx - 150, cy + 186, "Open it now", true, 140) then
      closeModal()
      G.openCrate(st, ss, m.crate)
      handleNotices()
      -- Bring the crate to the front of the queue.
      local last = table.remove(ui.modals)
      table.insert(ui.modals, 1, last)
    end
    if pickAt(cx + 10, cy + 186, "Later", false, 140) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then closeModal() end
  end
end

local function modalCheckin(m, dl, x, y, w, h)
  local t = m.t
  local cx = x + w / 2
  D.rect(dl, x, y, x + w, y + h, A(DEEP, math.min(1, t * 4) * 0.95), 8)
  bigTitle(dl, cx, y + 20, "DAILY CHECK-IN", SELECTED, m.got and 1 or t, 32)
  local day = m.got and m.got.day or G.checkinPreview(st, ui.epoch)
  local bw = math.min(90, (w - 60) / 7)
  local bx0 = cx - (7 * bw + 6 * 8) / 2
  local by = y + 90
  for i = 1, 7 do
    local bx = bx0 + (i - 1) * (bw + 8)
    local r = G.CHECKIN[i]
    D.rect(dl, bx, by, bx + bw, by + 96, i < day and GROUND or SUNKEN, 6)
    dtext(dl, FONT.body, 11, bx + bw / 2, by + 6, i == day and SELECTED or DIM, "DAY " .. i, "center")
    if r.crate then D.crate(dl, bx + bw / 2, by + 44, 32, RC(r.crate))
    elseif r.token then icon(dl, "dice", bx + bw / 2, by + 44, 12, RC(3))
    else ICON.coin(dl, bx + bw / 2, by + 44, 13) end
    dtext(dl, FONT.body, 11, bx + bw / 2, by + 70, DIM, r.coins and tostring(r.coins) or (r.crate and "crate" or "reroll"), "center")
    local stamped = i < day or (m.got and i == day and t > 0.55)
    if i == day and m.got then
      local k = math.min(1, math.max(0, (t - 0.2) / 0.35))
      if k > 0 then
        local s = 2.4 - 1.4 * F.ease.outBack(k)
        local sx, sy = bx + bw / 2, by + 48
        D.circle(dl, sx, sy, 22 * s, A(PASS_COL, math.min(1, k * 2)))
        D.check(dl, sx, sy, 22 * s, A(INK, math.min(1, k * 2)))
        if k >= 1 and not m.landed then
          m.landed = true
          F.flash(fx, 0.35, PASS_COL)
          F.ring(fx, sx, sy, PASS_COL, 90, 0.6)
          F.confetti(fx, sx, sy, 70, 360)
          F.shake(fx, 8)
        end
      end
    elseif stamped then
      D.circle(dl, bx + bw - 12, by + 12, 9, PASS_COL)
      D.check(dl, bx + bw - 12, by + 12, 9, INK)
    end
  end
  local ty = by + 116
  if not m.got then
    dtext(dl, FONT.body, 14, cx, ty, DIM, "Check in every day to keep your streak. Day 7 holds an Epic Crate.", "center")
    if pickAt(cx - 80, ty + 34, "Check in", true, 160) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      m.got, m.t = G.checkin(st, ss, ui.epoch), 0
      if not m.got then closeModal() end
      saveSoon()
    end
    if pickAt(cx - 50, ty + 70, "Not now", false, 100) then closeModal() end
    return
  end
  if t > 0.7 then
    local g = m.got
    ICON.flame(dl, cx - 70, ty + 12, 13, PASS_COL)
    dtext(dl, FONT.bold, 22, cx - 50, ty, TEXT, g.streak .. " day streak")
    local parts = {}
    if g.coins then parts[#parts + 1] = fmtNum(g.coins) .. " coins" end
    if g.xp then parts[#parts + 1] = math.floor(g.xp) .. " XP" end
    if g.token then parts[#parts + 1] = L.TOKENS[g.token].name end
    if g.crate then parts[#parts + 1] = L.RARITY[g.crate].name .. " Crate" end
    dtext(dl, FONT.body, 14, cx, ty + 34, TEXT, table.concat(parts, "  +  "), "center")
    if g.freezes and g.freezes > 0 then dtext(dl, FONT.body, 12, cx, ty + 54, RC(4), "A Streak Freeze kept your streak alive", "center")
    elseif g.broke then dtext(dl, FONT.body, 12, cx, ty + 54, DIM, "Your streak starts again today", "center") end
  end
  if t > 1.0 and (pickAt(cx - 70, ty + 80, "Collect", true, 140) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter)) then
    if m.got.coins then F.coins(fx, cx, ty + 40, 14, ui.coinPos[1], ui.coinPos[2]) end
    closeModal()
  end
end

local function modalRedeem(m, dl, x, y, w, h)
  local t = m.t
  local cx, cy = x + w / 2, y + h * 0.4
  D.rect(dl, x, y, x + w, y + h, A(DEEP, math.min(1, t * 4) * 0.95), 8)
  D.rays(dl, cx, cy, math.max(w, h), 16, t * 0.3, A(SELECTED, 0.07))
  -- The ticket drops in, then tears in two.
  local drop = F.ease.outBack(t / 0.5)
  local tear = F.ease.inOut((t - 0.8) / 0.7)
  local tw, th = 260, 120
  local ty = cy - 160 * (1 - drop)
  local halves = { { -1, cx - tw / 4 }, { 1, cx + tw / 4 } }
  for _, hv in ipairs(halves) do
    local side, hx = hv[1], hv[2]
    local ox = side * tear * 60
    local oy = tear * tear * 120
    D.box(dl, hx + ox, ty + oy, tw / 2, th, side * tear * 0.4, A(CONTROL, 1 - tear * 0.8))
  end
  if tear <= 0 then
    D.circle(dl, cx - tw / 2, ty, 16, DEEP)
    D.circle(dl, cx + tw / 2, ty, 16, DEEP)
    icon(dl, m.icon, cx, ty - 10, 26, INK, CONTROL)
    dtext(dl, FONT.bold, 15, cx, ty + 30, INK, m.name:upper(), "center")
    for i = 0, 10 do D.rect(dl, cx - 1, ty - th / 2 + 6 + i * 10, cx + 1, ty - th / 2 + 11 + i * 10, INK) end
  elseif not m.burst then
    m.burst = true
    F.confetti(fx, cx, ty, 140, 520)
    F.ring(fx, cx, ty, SELECTED, 220, 0.7)
    F.flash(fx, 0.4, SELECTED)
  end
  if t > 1.3 then
    local what = m.name:gsub(" Pass$", ""):lower()
    bigTitle(dl, cx, cy + 40, "ENJOY YOUR " .. what:upper() .. "!", SELECTED, t - 1.3, 30)
    dtext(dl, FONT.body, 14, cx, cy + 90, DIM, "You earned this one. Guilt-free.", "center")
    if pickAt(cx - 70, cy + 130, "Done", true, 140) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then closeModal() end
  end
end

local function modalSeason(m, dl, x, y, w, h)
  local t = m.t
  local cx, cy = x + w / 2, y + h * 0.4
  if not m.started then m.started = true; F.confetti(fx, cx, cy, 150, 600); F.flash(fx, 0.6, PASS_COL) end
  D.rect(dl, x, y, x + w, y + h, A(DEEP, math.min(1, t * 4) * 0.95), 8)
  D.rays(dl, cx, cy, math.max(w, h), 24, t * 0.2, A(PASS_COL, 0.10))
  bigTitle(dl, cx, cy - 90, "SEASON " .. m.season, PASS_COL, t, 28)
  bigTitle(dl, cx, cy - 40, m.name:upper(), TEXT, t - 0.3, 52)
  if t > 1 then
    dtext(dl, FONT.body, 14, cx, cy + 40, DIM, "A new battle pass: " .. L.SEASON_TIERS .. " tiers, a Mythic finale, and bonus tiers forever after.", "center")
    if pickAt(cx - 70, cy + 80, "Let's go", true, 140) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then closeModal() end
  end
end

local WELCOME = {
  "Keep this window open while you make music. Dock it anywhere: right-click its title bar.",
  "Every 15 minutes of active music-making unlocks a tier of the season's battle pass. Every hour is a big one.",
  "It pauses by itself when you're away, and carries your progress across every project.",
  "Everything you do earns XP. Every level gives a loot crate.",
  "Spend coins in the Shop on passes - a takeaway, a movie, a gaming session - then redeem them when you've earned the break.",
  "Ideas you win (chords, drums, melodies, titles...) wait in the Idea vault, ready to drop into your project.",
}

local function modalWelcome(m, dl, x, y, w, h)
  local t = m.t
  local cx = x + w / 2
  D.rect(dl, x, y, x + w, y + h, A(DEEP, 0.95), 8)
  D.rays(dl, cx, y + 70, math.max(w, h), 18, t * 0.2, A(SELECTED, 0.05))
  bigTitle(dl, cx, y + 26, "DAW BATTLE PASS", SELECTED, t, 40)
  local ty = y + 96
  local tw = math.min(560, w - 60)
  for i, line in ipairs(WELCOME) do
    local k = math.min(1, math.max(0, (t - 0.3 - i * 0.15) * 3))
    ty = ty + wrapText(dl, FONT.body, 14, cx - tw / 2, ty, tw, A(TEXT, k), line) + 10
  end
  if t > 1.4 then
    dtext(dl, FONT.bold, 14, cx, ty + 4, RC(4), "Here's a Rare Crate to get you started.", "center")
    if pickAt(cx - 70, ty + 36, "Let's go", true, 140) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      st.settings.welcome = true
      st.inv.crates[4] = st.inv.crates[4] + 1
      closeModal()
    end
  end
end

local MODALS = { reward = modalReward, level = modalLevel, checkin = modalCheckin, redeem = modalRedeem,
                 season = modalSeason, welcome = modalWelcome }

------------------------------------------------------------------------------
-- Over everything: particles, floating numbers, toasts, the flash
------------------------------------------------------------------------------

local function drawOverlay()
  local dl = ImGui.GetForegroundDrawList(ctx)
  for _, p in ipairs(fx.particles) do
    local a = math.max(0, math.min(1, p.life / p.max))
    if p.kind == "spark" then D.circle(dl, p.x, p.y, math.max(0.5, p.size * a), A(p.col, a))
    elseif p.kind == "confetti" then D.box(dl, p.x, p.y, p.size * 1.6, p.size * 0.8 * math.abs(math.cos(p.rot)), p.rot, A(p.col, math.min(1, a * 2)))
    elseif p.kind == "coin" then ICON.coin(dl, p.x, p.y, p.size)
    elseif p.kind == "ring" then D.ring(dl, p.x, p.y, p.size * (1 - a) + 4, A(p.col, a), 3)
    elseif p.kind == "star" then D.star(dl, p.x, p.y, p.size * a, A(p.col, a)) end
  end
  for _, f in ipairs(fx.floaters) do
    local a = math.min(1, f.life / f.max * 2)
    dtext(dl, FONT.bold, f.big and 22 or 15, f.x, f.y, A(f.col, a), f.text, "center")
  end
  if fx.flash > 0 then D.rect(dl, ui.winX, ui.winY, ui.winX + ui.winW, ui.winY + ui.winH, A(fx.flashCol, fx.flash * 0.45)) end

  local ty = ui.winY + 120
  for i = #fx.toasts, 1, -1 do
    local t = fx.toasts[i]
    local slide = F.ease.outBack(t.age / 0.35)
    local out = math.min(1, (t.max - t.age) / 0.4)
    local a = math.max(0, out)
    local col = RC(t.rarity or 3)
    if t.ach then
      local tw, th = math.min(460, ui.winW - 40), 76
      local tx = ui.winX + (ui.winW - tw) / 2
      local yy = ui.winY + 100 - (1 - slide) * 120
      D.glow(dl, tx, yy, tx + tw, yy + th, col, 8, a)
      D.rect(dl, tx, yy, tx + tw, yy + th, A(0x1B1F25FF, a), 8)
      D.frame(dl, tx, yy, tx + tw, yy + th, A(col, a), 8, 2)
      -- A shine sweeping across.
      local sh = ((t.age * 0.8) % 1.4) / 1.0
      if sh < 1 then
        local sx = tx + sh * (tw + 80) - 40
        ImGui.DrawList_PushClipRect(dl, tx, yy, tx + tw, yy + th, true)
        D.quad(dl, { sx, yy }, { sx + 30, yy }, { sx, yy + th }, { sx - 30, yy + th }, A(BRIGHT, 0.12 * a))
        ImGui.DrawList_PopClipRect(dl)
      end
      icon(dl, "trophy", tx + 38, yy + th / 2, 18, A(col, a))
      dtext(dl, FONT.body, 11, tx + 70, yy + 9, A(col, a), "ACHIEVEMENT UNLOCKED")
      dtext(dl, FONT.bold, 17, tx + 70, yy + 23, A(TEXT, a), t.text)
      dtext(dl, FONT.body, 12, tx + 70, yy + 46, A(DIM, a), t.sub .. "   +" .. (t.coins or 0) .. " coins  +" .. (t.xp or 0) .. " XP")
    else
      local tw, th = math.min(330, ui.winW - 32), 54
      local tx = ui.winX + ui.winW - 16 - tw * slide
      D.rect(dl, tx, ty, tx + tw, ty + th, A(0x1B1F25FF, a), 6)
      D.rect(dl, tx, ty, tx + 4, ty + th, A(col, a), 2)
      D.frame(dl, tx, ty, tx + tw, ty + th, A(RULE, a), 6, 1)
      icon(dl, t.icon, tx + 26, ty + th / 2, 11, A(t.icon == "coin" and COIN or col, a), 0x1B1F25FF)
      dtext(dl, FONT.bold, 14, tx + 46, ty + 9, A(TEXT, a), t.text)
      local sub = t.sub or ""
      if measure(FONT.body, 12, sub) > tw - 56 then
        while #sub > 4 and measure(FONT.body, 12, sub .. "...") > tw - 56 do sub = sub:sub(1, -2) end
        sub = sub .. "..."
      end
      dtext(dl, FONT.body, 12, tx + 46, ty + 29, A(DIM, a), sub)
      D.rect(dl, tx + 4, ty + th - 2, tx + 4 + (tw - 8) * (1 - t.age / t.max), ty + th, A(col, a * 0.6))
      ty = ty + th + 8
    end
  end
end

------------------------------------------------------------------------------
-- A frame
------------------------------------------------------------------------------

local function frame()
  drawHeader()
  drawTabs()
  ImGui.Dummy(ctx, 0, 2)
  local m = ui.modals[1]
  if m then
    m.t = m.t + ui.dt
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local w, h = ImGui.GetContentRegionAvail(ctx)
    w, h = math.max(320, w), math.max(360, h)
    local sx, sy = F.shakeOffset(fx)
    MODALS[m.type](m, ImGui.GetWindowDrawList(ctx), x + sx, y + sy, w, h)
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) and ui.modals[1] == m and m.type ~= "welcome" then
      if m.type == "reward" then
        if m.phase == "closed" or m.phase == "shake" then m.phase, m.t = "open", 0 else collect(m) end
      else closeModal() end
    end
    ImGui.SetCursorScreenPos(ctx, x, y + h - 4)
    ImGui.Dummy(ctx, 1, 1)
  else
    if ImGui.BeginChild(ctx, "page", 0, 0) then
      PAGES[ui.tab]()
      ImGui.EndChild(ctx)
    end
  end
  drawOverlay()
end

local function update()
  local tp, epoch = reaper.time_precise(), os.time()
  ui.dt = math.max(0, math.min(0.1, tp - (ui.tp > 0 and ui.tp or tp)))
  ui.tp, ui.epoch = tp, epoch
  local sig = W.signals(watcher, tp, ui.own)
  for _, e in ipairs(W.scan(watcher, tp)) do G.event(st, ss, e[1], e[2], e[3]) end
  G.tick(st, ss, tp, epoch, sig)
  if tp >= ui.nextSlow then
    ui.nextSlow = tp + 2
    G.refresh(st, ss, epoch, plugins)
    G.checkAchievements(st, ss)
  end
  handleNotices()
  F.update(fx, ui.dt)
  ui.disp.level = F.approach(ui.disp.level, st.level + st.xp / G.levelNeed(st.level), ui.dt, 4)
  ui.disp.coins = F.approach(ui.disp.coins, st.coins, ui.dt, 5)
  if (ui.saveSoon and tp >= ui.saveSoon) or tp >= ui.nextSave then save() end
end

------------------------------------------------------------------------------
-- Running
------------------------------------------------------------------------------

local sectionID, cmdID

local function loop()
  update()
  ImGui.SetNextWindowSize(ctx, 920, 780, ImGui.Cond_FirstUseEver)
  ImGui.SetNextWindowBgAlpha(ctx, 1.0)
  pushTheme()
  local visible, open = ImGui.Begin(ctx, TITLE, true)
  if visible then
    ui.winX, ui.winY = ImGui.GetWindowPos(ctx)
    ui.winW, ui.winH = ImGui.GetWindowSize(ctx)
    -- Moving the mouse over this window counts as being here.
    local mx, my = ImGui.GetMousePos(ctx)
    local inside = mx >= ui.winX and my >= ui.winY and mx < ui.winX + ui.winW and my < ui.winY + ui.winH
    ui.own = inside and (mx ~= ui.lastMouse[1] or my ~= ui.lastMouse[2])
    ui.lastMouse = { mx, my }
    frame()
    ImGui.End(ctx)
  end
  popTheme()   -- outside the visible test: a push always needs its pop
  if open then reaper.defer(loop) end
end

local function shutdown()
  save()
  if sectionID then
    reaper.SetToggleCommandState(sectionID, cmdID, 0)
    reaper.RefreshToolbar2(sectionID, cmdID)
  end
end

local function main()
  local tp, epoch = reaper.time_precise(), os.time()
  ui.tp, ui.epoch = tp, epoch
  local loaded = W.loadState(G)
  st = G.clampState(loaded or G.newState(epoch), epoch)
  ss = G.newSession(st, tp, epoch)
  fx = F.new()
  watcher = W.new()
  plugins, pluginSource = W.plugins()
  G.refresh(st, ss, epoch, plugins)
  W.signals(watcher, tp, false)
  W.scan(watcher, tp, true)
  ss.notices = {}
  ui.disp.level = st.level + st.xp / G.levelNeed(st.level)
  ui.disp.coins = st.coins
  ui.winX, ui.winY, ui.winW, ui.winH = 0, 0, 920, 780
  if not st.settings.welcome then pushModal({ type = "welcome" }) end
  if G.checkinAvailable(st, epoch) then pushModal({ type = "checkin" }) end
  ui.nextSave = tp + 20

  local _, _, sid, cid = reaper.get_action_context()
  sectionID, cmdID = sid, cid
  reaper.SetToggleCommandState(sectionID, cmdID, 1)
  reaper.RefreshToolbar2(sectionID, cmdID)
  reaper.atexit(shutdown)
  reaper.set_action_options(1)
  ctx = ImGui.CreateContext(TITLE)
  FONT = {
    body = { f = ImGui.CreateFont("sans-serif", 14), size = 14 },
    bold = { f = ImGui.CreateFont("sans-serif", 16, ImGui.FontFlags_Bold), size = 16 },
    big  = { f = ImGui.CreateFont("sans-serif", 28, ImGui.FontFlags_Bold), size = 28 },
    huge = { f = ImGui.CreateFont("sans-serif", 64, ImGui.FontFlags_Bold), size = 64 },
  }
  for _, f in pairs(FONT) do ImGui.Attach(ctx, f.f) end
  reaper.defer(loop)
end

main()
