--[[ The whole script, headless.

     ReaImGui only exists inside REAPER, so a mock stands in its place and
     the real "DAW Battle Pass.lua" is run against it and the mocked REAPER.
     It cannot say the window looks right. It can say that nothing raises,
     that no call reaches a ReaImGui function that does not exist or hands it
     a nonsense number, that every push is popped, that every button wears
     the dark ink, and that clicking every button on every page, opening
     crates, checking in, playing for an hour and restarting leaves the
     script working and the progress saved.

       lua5.4 tests/test_ui.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local C = dofile(HERE .. "/check.lua")
local ok, eq = C.ok, C.eq
local P = dofile(HERE .. "/reaper_mock.lua")
local SCRIPT = C.SCRIPTS .. "DAW Battle Pass.lua"
local INK = 0x14171CFF

------------------------------------------------------------------------------
-- A ReaImGui that records
------------------------------------------------------------------------------

local g = { keys = {}, mouse = { 100, 100 }, fonts = {}, clipboard = nil, draws = 0 }
local function resetFrame()
  g.idDepth, g.colDepth, g.colStack, g.fontDepth, g.disabled = 0, 0, {}, 0, 0
  g.windowDepth, g.childDepth = 0, 0
  g.buttons, g.ink, g.texts, g.tooltips, g.headings = {}, {}, {}, {}, {}
  g.cx, g.cy, g.lastX, g.lastY, g.lastW, g.lastH = 0, 0, 0, 0, 0, 0
end
resetFrame()

local ImGui = {}
local consts = { "Col_Text", "Col_TextDisabled", "Col_WindowBg", "Col_ChildBg", "Col_PopupBg", "Col_Border",
  "Col_FrameBg", "Col_FrameBgHovered", "Col_FrameBgActive", "Col_TitleBg", "Col_TitleBgActive",
  "Col_TitleBgCollapsed", "Col_Button", "Col_ButtonHovered", "Col_ButtonActive", "Col_CheckMark",
  "Col_SliderGrab", "Col_SliderGrabActive", "Col_Separator", "Col_ScrollbarBg", "Col_ScrollbarGrab",
  "Col_ScrollbarGrabHovered", "Col_ScrollbarGrabActive", "Cond_FirstUseEver", "Key_Escape", "Key_Enter",
  "FontFlags_Bold" }
for i, k in ipairs(consts) do ImGui[k] = i end

local function num(v, what)
  if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
    error(what .. " is " .. tostring(v))
  end
end
local function colour(c, what)
  num(c, what)
  if c < 0 or c > 0xFFFFFFFF or math.floor(c) ~= c then error(what .. " is not a 0xRRGGBBAA colour: " .. tostring(c)) end
end
local function effective(idx)
  for i = #g.colStack, 1, -1 do if g.colStack[i].idx == idx then return g.colStack[i].col end end
end

-- The cursor: items go down the page; SameLine puts the next one beside.
local function item(w, h)
  g.lastX, g.lastY, g.lastW, g.lastH = g.cx, g.cy, w, h
  g.cy = g.cy + h + 4
  g.lineX = g.lineX or 0
  g.cx = g.lineX
end

function ImGui.CreateContext(name) return { name = name } end
function ImGui.CreateFont(family, size, flags)
  if type(family) ~= "string" then error("CreateFont needs a family") end
  num(size, "font size")
  local f = { font = true, size = size }
  g.fonts[#g.fonts + 1] = f
  return f
end
function ImGui.Attach(_, obj) obj.attached = true end
function ImGui.PushFont(_, f)
  if type(f) ~= "table" or not f.font then error("PushFont with something that is not a font") end
  if not f.attached then error("PushFont with a font that was never attached") end
  g.fontDepth = g.fontDepth + 1
end
function ImGui.PopFont()
  g.fontDepth = g.fontDepth - 1
  if g.fontDepth < 0 then error("PopFont without a push") end
end
function ImGui.SetNextWindowSize(_, w, h, cond) num(w, "window width"); num(h, "window height") end
function ImGui.SetNextWindowBgAlpha(_, a)
  if type(a) ~= "number" or a < 0 or a > 1 then error("window alpha " .. tostring(a)) end
  g.bgAlpha = a
end
function ImGui.Begin(_, name, open)
  g.windowDepth = g.windowDepth + 1
  g.windowBg = effective(ImGui.Col_WindowBg)
  g.cx, g.cy, g.lineX = 10, 30, 10
  return true, not g.closeWindow
end
function ImGui.End()
  g.windowDepth = g.windowDepth - 1
  if g.windowDepth ~= 0 then error("End without Begin") end
end
function ImGui.BeginChild(_, id, w, h)
  if type(id) ~= "string" then error("BeginChild needs a string id") end
  g.childDepth = g.childDepth + 1
  return true
end
function ImGui.EndChild()
  g.childDepth = g.childDepth - 1
  if g.childDepth < 0 then error("EndChild without BeginChild") end
end
function ImGui.BeginDisabled(_, d) g.disabled = g.disabled + 1 end
function ImGui.EndDisabled()
  g.disabled = g.disabled - 1
  if g.disabled < 0 then error("EndDisabled without BeginDisabled") end
end
function ImGui.IsKeyPressed(_, key) return g.keys[key] == true end
function ImGui.SeparatorText(_, s)
  if type(s) ~= "string" then error("SeparatorText got a " .. type(s)) end
  g.headings[#g.headings + 1] = s
  item(400, 16)
end
function ImGui.Text(_, s)
  if type(s) ~= "string" then error("Text got a " .. type(s)) end
  g.texts[#g.texts + 1] = s
  item(#s * 7, 13)
end
function ImGui.SameLine()
  g.cx = g.lastX + g.lastW + 8
  g.cy = g.lastY
end
function ImGui.Dummy(_, w, h) num(w, "Dummy width"); num(h, "Dummy height"); item(w, h) end
function ImGui.PushID(_, v)
  if v == nil then error("PushID with nil") end
  g.idDepth = g.idDepth + 1
end
function ImGui.PopID()
  g.idDepth = g.idDepth - 1
  if g.idDepth < 0 then error("PopID without a push") end
end
function ImGui.PushStyleColor(_, idx, col)
  if type(idx) ~= "number" then error("PushStyleColor with a " .. type(idx) .. " index") end
  colour(col, "style colour")
  if col % 256 == 0 then error("style colour must be opaque") end
  g.colStack[#g.colStack + 1] = { idx = idx, col = col }
  g.colDepth = g.colDepth + 1
end
function ImGui.PopStyleColor(_, n)
  for _ = 1, (n or 1) do g.colStack[#g.colStack] = nil end
  g.colDepth = g.colDepth - (n or 1)
  if g.colDepth < 0 then error("PopStyleColor without a push") end
end
local function press(label, w, h, invisible)
  g.buttons[#g.buttons + 1] = label
  g.ink[#g.buttons] = { bg = effective(ImGui.Col_Button), text = effective(ImGui.Col_Text), invisible = invisible,
                        disabled = g.disabled > 0 }
  item(w > 0 and w or #label * 7 + 16, h > 0 and h or 20)
  if g.clickTarget == #g.buttons then
    g.clicked = label
    return g.disabled == 0
  end
  return false
end
function ImGui.Button(_, label, w, h)
  if type(label) ~= "string" then error("Button label is a " .. type(label)) end
  if w ~= nil then num(w, "Button width") end
  return press(label, w or 0, h or 0, false)
end
function ImGui.InvisibleButton(_, id, w, h)
  if type(id) ~= "string" then error("InvisibleButton id is a " .. type(id)) end
  num(w, "InvisibleButton width"); num(h, "InvisibleButton height")
  if w <= 0 or h <= 0 then error("InvisibleButton needs a size: " .. w .. "x" .. h) end
  return press("##" .. id, w, h, true)
end
function ImGui.Checkbox(_, label, v)
  if type(v) ~= "boolean" then error("Checkbox value is a " .. type(v)) end
  item(100, 20)
  if g.toggle then return true, not v end
  return false, v
end
function ImGui.SliderInt(_, label, v, lo, hi)
  num(v, "slider value"); num(lo, "slider min"); num(hi, "slider max")
  item(200, 20)
  if g.toggle then return true, hi end
  return false, v
end
function ImGui.InputText(_, label, buf)
  if type(buf) ~= "string" then error("InputText buffer is a " .. type(buf)) end
  item(200, 20)
  if g.typeName then return true, g.typeName end
  return false, buf
end
function ImGui.SetNextItemWidth(_, w) num(w, "item width") end
function ImGui.IsItemHovered() return g.hover == true end
function ImGui.IsWindowHovered() return true end
function ImGui.SetTooltip(_, s)
  if type(s) ~= "string" then error("tooltip is a " .. type(s)) end
  g.tooltips[#g.tooltips + 1] = s
end
function ImGui.GetItemRectMin() return g.lastX, g.lastY end
function ImGui.GetItemRectMax() return g.lastX + g.lastW, g.lastY + g.lastH end
function ImGui.CalcTextSize(_, s)
  if type(s) ~= "string" then error("CalcTextSize got a " .. type(s)) end
  return #s * 7, 13
end
function ImGui.GetContentRegionAvail() return 900, 620 end
function ImGui.GetCursorScreenPos() return g.cx, g.cy end
function ImGui.SetCursorScreenPos(_, x, y)
  num(x, "cursor x"); num(y, "cursor y")
  g.cx, g.cy = x, y
  g.lineX = x
end
function ImGui.GetMousePos() return g.mouse[1], g.mouse[2] end
function ImGui.GetWindowPos() return 0, 0 end
function ImGui.GetWindowSize() return 920, 780 end
function ImGui.SetClipboardText(_, s)
  if type(s) ~= "string" then error("clipboard text is a " .. type(s)) end
  g.clipboard = s
end
local DL = { drawlist = true }
function ImGui.GetWindowDrawList() return DL end
function ImGui.GetForegroundDrawList() return DL end

-- Every draw call: a draw list first, numbers that are numbers, colours that
-- are colours.
local function drawCall(name, nNums, colAt, extra)
  ImGui[name] = function(dl, ...)
    if dl ~= DL then error(name .. " without a draw list") end
    local args = { ... }
    for i = 1, nNums do num(args[i], name .. " argument " .. i) end
    if colAt then colour(args[colAt], name .. " colour") end
    if extra then extra(args) end
    g.draws = g.draws + 1
  end
end
drawCall("DrawList_AddRectFilled", 4, 5, function(a)
  if a[3] < a[1] - 0.5 or a[4] < a[2] - 0.5 then error("rect is inside out") end
  if a[6] ~= nil then num(a[6], "rounding") end
end)
drawCall("DrawList_AddRect", 4, 5, function(a)
  if a[6] ~= nil then num(a[6], "rounding") end
  if a[8] ~= nil then num(a[8], "thickness") end
end)
drawCall("DrawList_AddRectFilledMultiColor", 4, nil, function(a) for i = 5, 8 do colour(a[i], "corner colour") end end)
drawCall("DrawList_AddLine", 4, 5)
drawCall("DrawList_AddCircle", 3, 4, function(a) if a[3] < 0 then error("negative radius") end end)
drawCall("DrawList_AddCircleFilled", 3, 4, function(a) if a[3] < 0 then error("negative radius") end end)
drawCall("DrawList_AddTriangleFilled", 6, 7)
drawCall("DrawList_AddQuadFilled", 8, 9)
drawCall("DrawList_PathClear", 0)
drawCall("DrawList_PathArcTo", 5)
drawCall("DrawList_PathStroke", 0, 1, function(a) num(a[3], "path thickness") end)
drawCall("DrawList_PathFillConvex", 0, 1)
drawCall("DrawList_PushClipRect", 4)
drawCall("DrawList_PopClipRect", 0)
ImGui.DrawList_AddTextEx = function(dl, font, size, x, y, col, text)
  if dl ~= DL then error("AddTextEx without a draw list") end
  if type(font) ~= "table" or not font.font or not font.attached then error("AddTextEx with a font that isn't attached") end
  num(size, "text size"); num(x, "text x"); num(y, "text y"); colour(col, "text colour")
  if size <= 0 then error("text size " .. size) end
  if type(text) ~= "string" then error("AddTextEx text is a " .. type(text)) end
  g.texts[#g.texts + 1] = text
  g.draws = g.draws + 1
end
setmetatable(ImGui, { __index = function(_, k)
  error("the script called ImGui." .. tostring(k) .. ", which the mock does not have")
end })

------------------------------------------------------------------------------
-- REAPER, the clock, and running the script
------------------------------------------------------------------------------

local tmp = os.tmpname()
os.remove(tmp)
os.execute('mkdir -p "' .. tmp .. '"')
local shim = assert(io.open(tmp .. "/imgui.lua", "w"))
shim:write("return function(version) return _G.__MOCK_IMGUI end\n")
shim:close()
_G.__MOCK_IMGUI = ImGui

P.install()
local deferred, atexitFn
local function absolute(path)
  if path:match("^/") then return path end
  return (os.getenv("PWD") or ".") .. "/" .. path
end
reaper.ImGui_GetBuiltinPath = function() return tmp end
reaper.MB = function(msg) error("the script gave up: " .. tostring(msg)) end
reaper.get_action_context = function() return true, absolute(SCRIPT), 0, 1, 0, 0, 0 end
reaper.defer = function(f) deferred = f end
reaper.atexit = function(f) atexitFn = f end

-- The wall clock, under the test's control: Thursday 8 October 2026, 8pm.
local realTime = os.time
local EPOCH = realTime({ year = 2026, month = 10, day = 8, hour = 20 })
local clock = { epoch = EPOCH }
os.time = function(t) if t then return realTime(t) end return math.floor(clock.epoch) end

local function start()
  deferred, atexitFn = nil, nil
  dofile(SCRIPT)
end

-- One frame, optionally clicking the n-th button drawn in it. `dt` seconds
-- pass first (a tenth by default; the script caps a frame's step there).
local function frame(clickAt, dt)
  dt = dt or 0.1
  P.now = P.now + dt
  clock.epoch = clock.epoch + dt
  resetFrame()
  g.clickTarget, g.clicked = clickAt, nil
  local f = deferred
  deferred = nil
  if not f then error("the script stopped deferring") end
  f()
  g.keys = {}
  if g.idDepth ~= 0 then error("PushID left unbalanced: " .. g.idDepth) end
  if g.colDepth ~= 0 then error("PushStyleColor left unbalanced: " .. g.colDepth) end
  if g.fontDepth ~= 0 then error("PushFont left unbalanced: " .. g.fontDepth) end
  if g.disabled ~= 0 then error("BeginDisabled left unbalanced") end
  if g.childDepth ~= 0 then error("BeginChild left unbalanced") end
  if g.windowDepth ~= 0 then error("Begin left unbalanced") end
  return g.clicked
end

local function frames(n, dt) for _ = 1, n do frame(nil, dt) end end

local function has(list, text)
  for _, t in ipairs(list) do if t:find(text, 1, true) then return true end end
  return false
end
-- The n-th button called `label`; failing that, the n-th starting with it
-- ("1,200 coins", "Set tempo 97").
local function buttonIndex(label, nth)
  for _, exact in ipairs({ true, false }) do
    local seen = 0
    for i, b in ipairs(g.buttons) do
      if b == label or (not exact and b:find(label, 1, true) == 1) then
        seen = seen + 1
        if seen == (nth or 1) then return i end
      end
    end
  end
end
local function click(label, nth)
  frame()
  local i = buttonIndex(label, nth)
  if not i then error("no button called " .. label .. " among: " .. table.concat(g.buttons, ", ")) end
  frame(i)
  frame()
end
local function present(label) frame(); return buttonIndex(label) ~= nil end

-- Every button on screen wears the dark ink, chosen or not.
local inkFails = 0
local function checkInk(where)
  for i, b in ipairs(g.buttons) do
    local k = g.ink[i]
    if not k.invisible and k.text ~= INK then
      inkFails = inkFails + 1
      if inkFails < 4 then ok(false, "the " .. b .. " button wears the dark ink (" .. where .. ")") end
    end
  end
end

-- Escape until no modal is left (the welcome modal has its own button).
local function closeModals()
  for _ = 1, 30 do
    g.keys[ImGui.Key_Escape] = true
    frame(nil, 0.5)
  end
end

local function fresh()
  P.reset()
  P.resource = tmp .. "/resource"
  os.execute('rm -rf "' .. P.resource .. '"')
  clock.epoch = EPOCH
  local tr = P.track("Track 1")
  P.selTracks = { tr }
  start()
  frame()
  return tr
end

-- Past the welcome (it waits until its text has faded in) and the check-in.
local function welcomed()
  frames(20)
  click("Let's go")
  frames(3)
  closeModals()
end

------------------------------------------------------------------------------
-- It starts with a welcome, a starter crate and the check-in
------------------------------------------------------------------------------

fresh()
eq(g.bgAlpha, 1.0, "the window is solid")
eq(g.windowBg, 0x23272EFF, "on the house ground")
for _, tab in ipairs({ "Pass", "Quests", "Shop", "Gear", "Loot", "Ideas", "Trophies", "Stats" }) do
  ok(buttonIndex(tab) ~= nil, "the " .. tab .. " tab is there")
end
ok(has(g.texts, "DAW BATTLE PASS"), "a new player is welcomed")
frames(20)
ok(present("Let's go"), "the welcome ends with a button")
click("Let's go")
frames(5)
ok(present("Check in"), "then the daily check-in")
click("Check in")
frames(15)
ok(has(g.texts, "1 day streak"), "checking in starts a streak")
click("Collect")
frames(3)
ok(not present("Collect"), "and the modals are gone")
checkInk("start")

------------------------------------------------------------------------------
-- Every page, every button
------------------------------------------------------------------------------

-- Give the player things to look at: coins, crates, gear, ideas.
local function richState()
  click("Loot")
  -- The starter Rare crate from the welcome.
  ok(present("Open"), "the Loot page offers to open the starter crate")
  local i = buttonIndex("Open", 3)
  frame(i)
  frames(2)
  ok(buttonIndex("##crate") ~= nil, "opening a crate shows it, waiting to be clicked")
  frame(buttonIndex("##crate"))
  frames(35)
  ok(present("Collect"), "the crate bursts open and its rewards are revealed")
  click("Collect")
  frames(30)
end
richState()

local TAB_NAMES = { "Pass", "Quests", "Shop", "Gear", "Loot", "Ideas", "Trophies", "Stats" }
for _, tab in ipairs(TAB_NAMES) do
  click(tab)
  frames(2)
  checkInk(tab)
  ok(g.draws > 50, "the " .. tab .. " page draws")
  -- Click each of its buttons in turn, coming back to the page each time.
  local n = #g.buttons
  for i = 1, n do
    click(tab)
    frame()
    local label = g.buttons[i]
    if label and label ~= tab then
      frame(i)
      frames(3)
      closeModals()
    end
  end
end
ok(true, "every button on every page was clicked without an error")
checkInk("after clicking everything")

------------------------------------------------------------------------------
-- Hovering shows tooltips
------------------------------------------------------------------------------

g.hover = true
click("Pass")
frames(2)
g.hover = false
click("Gear")
ok(true, "hovering everything raises nothing")

------------------------------------------------------------------------------
-- An hour of music
------------------------------------------------------------------------------

fresh()
welcomed()
local tiers = 0
for second = 1, 3700 do
  if second % 20 == 0 then P.mouse = { second % 500, 7 } end
  frame(nil, 1)
  if buttonIndex("Collect") then
    tiers = tiers + 1
    frame(buttonIndex("Collect"))
  elseif buttonIndex("Later") then
    frame(buttonIndex("Later"))
  end
end
closeModals()
ok(tiers >= 4, "an hour brings four rewards to collect (" .. tiers .. ")")

click("Pass")
ok(has(g.texts, "Tier 4 / 100"), "the pass is at tier 4")

-- Then nothing: the clock stops.
click("Stats")
for _ = 1, 1200 do frame(nil, 1) end
closeModals()
ok(true, "twenty idle minutes run without trouble")

------------------------------------------------------------------------------
-- A player with everything: ideas of every kind, gear, crates, coins
------------------------------------------------------------------------------

local T = dofile(C.SCRIPTS .. "bp_theory.lua")
local L = dofile(C.SCRIPTS .. "bp_loot.lua").init(T)
local G = dofile(C.SCRIPTS .. "bp_game.lua").init(L)

local function seedRichSave()
  local st = G.clampState(G.newState(EPOCH), EPOCH)
  st.settings.welcome = true
  st.checkin.last = G.dayKey(EPOCH)
  st.coins = 100000
  for r = 2, 7 do st.inv.crates[r] = 2 end
  st.inv.tokens = { reroll = 3, freeze = 1, boost = 2 }
  local rnd = L.random(77)
  for _, def in ipairs(L.IDEAS) do
    local d = L.makeIdea(rnd, def.id, 6)
    d.uid, d.t = st.nextId, EPOCH
    st.nextId = st.nextId + 1
    st.vault[#st.vault + 1] = d
  end
  for r = 1, 7 do
    local it = L.makeGear(rnd, r, 10)
    it.uid = st.nextId
    st.nextId = st.nextId + 1
    st.gear.stash[#st.gear.stash + 1] = it
  end
  st.cos.titles[1] = { text = "Groove Wizard", rarity = 4 }
  st.cos.banners[1] = L.makeBanner(rnd, 7)
  os.execute('mkdir -p "' .. P.resource .. '/Data/DAW Battle Pass"')
  local f = assert(io.open(P.resource .. "/Data/DAW Battle Pass/progress.lua", "wb"))
  f:write(G.serialize(st))
  f:close()
end

P.reset()
P.resource = tmp .. "/resource"
os.execute('rm -rf "' .. P.resource .. '"')
clock.epoch = EPOCH
seedRichSave()
P.selTracks = {}
start()
frame()
closeModals()

click("Ideas")
frames(2)
ok(has(g.texts, "Idea vault"), "the vault page draws")
click("Chord Progression")
ok(buttonIndex("Insert MIDI") ~= nil, "filtered to chords, a MIDI idea offers to go into the project")
click("Copy")
ok(g.clipboard ~= nil and #g.clipboard > 0, "Copy puts the idea on the clipboard")
local before = #P.tracks
click("Insert MIDI")
eq(#P.tracks, before + 1, "with no track selected, Insert MIDI makes one")
ok(#P.tracks[#P.tracks].items[1].take.notes > 0, "and fills it with notes")
eq(P.undoDepth, 0, "as a closed undo step")
click("All")
click("Add regions")
ok(#P.markers > 3, "an arrangement adds its regions")
click("Set tempo")
ok(P.bpmSet ~= nil, "a seed sets the tempo")
click("Star")
ok(buttonIndex("Starred") ~= nil, "an idea can be starred")
click("Song Title")
eq(buttonIndex("Delete") ~= nil, true, "the one song title is shown")
click("Delete")
ok(buttonIndex("Sure?") ~= nil, "deleting asks first")
click("Sure?")
frame()
eq(buttonIndex("Delete"), nil, "and then deletes")
click("All")

click("Shop")
frames(2)
local buyAt = buttonIndex("1,200 coins")
ok(buyAt ~= nil, "the takeaway pass is in the shop")
frame(buyAt)
frame()
click("Sure?")
frames(10)
closeModals()   -- the purchase's achievement may have levelled us up
click("Loot")
ok(buttonIndex("Redeem") ~= nil, "the takeaway pass is in the inventory")
click("Redeem")
click("Sure?")
frames(20)
ok(has(g.texts, "ENJOY YOUR TAKEAWAY!"), "redeeming a takeaway pass is celebrated")
click("Done")
frames(3)

click("Gear")
frames(2)
local stashAt
for i, b in ipairs(g.buttons) do if b:find("^##stash") then stashAt = i; break end end
ok(stashAt ~= nil, "the stash shows its gear")
frame(stashAt)
frame()
ok(buttonIndex("Equip") ~= nil, "a chosen item can be equipped")
click("Equip")
frames(3)

-- Every button again, in the rich state.
for _, tab in ipairs(TAB_NAMES) do
  click(tab)
  frames(2)
  checkInk("rich " .. tab)
  local n = #g.buttons
  for i = 1, n do
    click(tab)
    frame()
    if g.buttons[i] and g.buttons[i] ~= tab then
      frame(i)
      frames(3)
      closeModals()
    end
  end
end
ok(true, "every button on every page, with a full inventory, without an error")

-- Typing a name, toggling the settings.
click("Stats")
g.typeName = "Kallum"
frame()
g.typeName = nil
g.toggle = true
frame()
g.toggle = false
frames(2)
ok(has(g.texts, "Kallum"), "the name typed is the name shown")
local startup = io.open(P.resource .. "/Scripts/__startup.lua", "rb")
ok(startup ~= nil, "ticking Start with REAPER writes REAPER's startup script")
if startup then startup:close() end

------------------------------------------------------------------------------
-- Saving, closing and coming back
------------------------------------------------------------------------------

fresh()
welcomed()
for second = 1, 950 do
  if second % 20 == 0 then P.mouse = { second, 3 } end
  frame(nil, 1)
  if buttonIndex("Collect") then frame(buttonIndex("Collect"))
  elseif buttonIndex("Later") then frame(buttonIndex("Later")) end
end
closeModals()
atexitFn()
local f = io.open(P.resource .. "/Data/DAW Battle Pass/progress.lua", "rb")
ok(f ~= nil, "closing saves the progress")
local saved = f and f:read("a") or ""
if f then f:close() end
ok(saved:find("tier=1", 1, true) ~= nil, "including the pass tier")

-- Start again: the progress is still there, and no welcome this time.
start()
frame()
ok(not has(g.texts, "DAW BATTLE PASS"), "a returning player isn't welcomed again")
closeModals()
click("Pass")
ok(has(g.texts, "Tier 1 / 100"), "the pass tier came back")

-- A damaged save doesn't stop it starting.
atexitFn()
local w = io.open(P.resource .. "/Data/DAW Battle Pass/progress.lua", "wb")
w:write("{ this is not a save")
w:close()
start()
frame()
closeModals()
click("Pass")
ok(has(g.texts, "Tier 1 / 100"), "a damaged save falls back to the backup")

-- Closing the window stops the script.
g.closeWindow = true
frame()
ok(deferred == nil, "closing the window stops the script")
g.closeWindow = false

os.time = realTime
os.execute('rm -rf "' .. tmp .. '"')
C.done()
