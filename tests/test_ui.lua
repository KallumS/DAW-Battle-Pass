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
  g.textCols, g.circles = {}, 0
  g.right, g.rightWhat, g.clips = 0, nil, {}
  g.cx, g.cy, g.lastX, g.lastY, g.lastW, g.lastH = 0, 0, 0, 0, 0, 0
end
resetFrame()

local ImGui = {}
local consts = { "Col_Text", "Col_TextDisabled", "Col_WindowBg", "Col_ChildBg", "Col_PopupBg", "Col_Border",
  "Col_FrameBg", "Col_FrameBgHovered", "Col_FrameBgActive", "Col_TitleBg", "Col_TitleBgActive",
  "Col_TitleBgCollapsed", "Col_Button", "Col_ButtonHovered", "Col_ButtonActive", "Col_CheckMark",
  "Col_SliderGrab", "Col_SliderGrabActive", "Col_Separator", "Col_ScrollbarBg", "Col_ScrollbarGrab",
  "Col_ScrollbarGrabHovered", "Col_ScrollbarGrabActive", "Cond_FirstUseEver", "Key_Escape", "Key_Enter",
  "FontFlags_Bold", "Col_NavHighlight", "Col_MenuBarBg", "Col_Header", "Col_HeaderHovered",
  "Col_HeaderActive", "Col_ResizeGrip", "Col_ResizeGripHovered", "Col_ResizeGripActive", "Col_Tab",
  "Col_TabHovered", "StyleVar_FrameBorderSize" }
for i, k in ipairs(consts) do ImGui[k] = i end
ImGui.ConfigFlags_NavEnableKeyboard = 1   -- a bit, as in ReaImGui

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

-- ImGui_Context ctx = CreateContext(string label, optional integer config_flags)
function ImGui.CreateContext(name, flags) g.configFlags = flags; return { name = name } end
-- bool IsMouseClicked(ctx, integer button, optional bool repeat)
function ImGui.IsMouseClicked(_, b) num(b, "mouse button"); return g.mouseClicked == true end
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
  g.title = name
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
  if idx == ImGui.Col_NavHighlight then g.navRing = col end
end
function ImGui.PopStyleColor(_, n)
  for _ = 1, (n or 1) do g.colStack[#g.colStack] = nil end
  g.colDepth = g.colDepth - (n or 1)
  if g.colDepth < 0 then error("PopStyleColor without a push") end
end
-- How far right anything reached this frame, and what (the no-overflow check).
local function reach(x2, what)
  if x2 > g.right then g.right, g.rightWhat = x2, what end
end
local function press(label, w, h, invisible)
  g.buttons[#g.buttons + 1] = label
  g.ink[#g.buttons] = { bg = effective(ImGui.Col_Button), text = effective(ImGui.Col_Text), invisible = invisible,
                        disabled = g.disabled > 0 }
  item(w > 0 and w or #label * 7 + 16, h > 0 and h or 20)
  if not invisible then reach(g.lastX + g.lastW, "the " .. label .. " button") end
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
  if g.toggle or g.toggleOnly == label then return true, not v end
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
-- The window is 920 wide (10 either side) unless a test narrows it (g.avail).
function ImGui.GetContentRegionAvail() return g.avail or 900, 620 end
function ImGui.GetCursorScreenPos() return g.cx, g.cy end
function ImGui.SetCursorScreenPos(_, x, y)
  num(x, "cursor x"); num(y, "cursor y")
  g.cx, g.cy = x, y
  g.lineX = x
end
function ImGui.GetMousePos() return g.mouse[1], g.mouse[2] end
function ImGui.GetWindowPos() return 0, 0 end
function ImGui.GetWindowSize() return (g.avail or 900) + 20, 780 end
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
drawCall("DrawList_AddCircleFilled", 3, 4, function(a)
  if a[3] < 0 then error("negative radius") end
  g.circles = g.circles + 1
end)
drawCall("DrawList_AddTriangleFilled", 6, 7)
drawCall("DrawList_AddQuadFilled", 8, 9)
drawCall("DrawList_PathClear", 0)
drawCall("DrawList_PathArcTo", 5)
drawCall("DrawList_PathStroke", 0, 1, function(a) num(a[3], "path thickness") end)
drawCall("DrawList_PathFillConvex", 0, 1)
-- A clip rect: what is drawn past its right edge is not seen (the pass's
-- track scrolls sideways inside one).
drawCall("DrawList_PushClipRect", 4, nil, function(a) g.clips[#g.clips + 1] = a[3] end)
drawCall("DrawList_PopClipRect", 0, nil, function()
  if #g.clips == 0 then error("PopClipRect without a push") end
  g.clips[#g.clips] = nil
end)
ImGui.DrawList_AddTextEx = function(dl, font, size, x, y, col, text)
  if dl ~= DL then error("AddTextEx without a draw list") end
  if type(font) ~= "table" or not font.font or not font.attached then error("AddTextEx with a font that isn't attached") end
  num(size, "text size"); num(x, "text x"); num(y, "text y"); colour(col, "text colour")
  if size <= 0 then error("text size " .. size) end
  if type(text) ~= "string" then error("AddTextEx text is a " .. type(text)) end
  g.texts[#g.texts + 1] = text
  g.textCols[#g.texts] = col
  g.draws = g.draws + 1
  -- As the HIG mock's CalcTextSize measures: about half the size a letter.
  local x2, clip = x + #text * size * 0.55, g.clips[#g.clips]
  if clip then x2 = math.min(x2, clip) end
  if not clip or x < clip then reach(x2, '"' .. text .. '"') end
end
-- 1.2: the window's size, the text size's style variables and the keyboard.
ImGui.WindowFlags_HorizontalScrollbar = 2048
-- void SetNextWindowSizeConstraints(ctx, number size_min_w, number size_min_h,
--   number size_max_w, number size_max_h, optional ImGui_Function custom_callback)
function ImGui.SetNextWindowSizeConstraints(_, w1, h1, w2, h2)
  num(w1, "min width"); num(h1, "min height"); num(w2, "max width"); num(h2, "max height")
  g.minW, g.minH = w1, h1
end
-- void PushStyleVar(ctx, integer var_idx, number val1, optional number val2)
function ImGui.PushStyleVar(_, idx, a, b)
  num(idx, "style var"); num(a, "style var value")
  if b ~= nil then num(b, "style var value") end
  g.varDepth = (g.varDepth or 0) + 1
end
-- void PopStyleVar(ctx, optional integer count)
function ImGui.PopStyleVar(_, n)
  g.varDepth = (g.varDepth or 0) - (n or 1)
  if g.varDepth < 0 then error("PopStyleVar without a push") end
end
-- bool IsPopupOpen(ctx, string str_id, optional integer flags)
ImGui.PopupFlags_AnyPopupId = 1024
function ImGui.IsPopupOpen(_, id, flags)
  if type(id) ~= "string" then error("IsPopupOpen needs a string id") end
  return g.popupOpen == true
end
-- bool IsItemFocused(ctx); bool IsAnyItemFocused(ctx)
function ImGui.IsItemFocused() return g.focused == true end
function ImGui.IsAnyItemFocused() return g.focused == true end
-- void TextWrapped(ctx, string text)
function ImGui.TextWrapped(_, s)
  if type(s) ~= "string" then error("TextWrapped got a " .. type(s)) end
  g.texts[#g.texts + 1] = s
  item(#s * 7, 13)
end

-- Apple's Human Interface Guidelines: the family's shared checks (0018).
local HIG = dofile(HERE .. "/hig_mock.lua")(ImGui)

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
-- ("Buy for 2,500 Coins", "Set tempo 97").
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
  click("Let's Go")
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
ok(present("Let's Go"), "the welcome ends with a button")
click("Let's Go")
frames(5)
ok(present("Check In"), "then the daily check-in")
click("Check In")
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
click("Add Regions")
ok(#P.markers > 3, "an arrangement adds its regions")
click("Set Tempo")
ok(P.bpmSet ~= nil, "a seed sets the tempo")
click("Star")
ok(buttonIndex("Starred") ~= nil, "an idea can be starred")
click("Song Title")
eq(buttonIndex("Delete") ~= nil, true, "the one song title is shown")
click("Delete")
ok(buttonIndex("Click Again to") ~= nil, "deleting asks first")
click("Click Again to")
frame()
eq(buttonIndex("Delete"), nil, "and then deletes")
click("All")

click("Shop")
frames(2)
local buyAt = buttonIndex("Buy for 2,500 Coins")
ok(buyAt ~= nil, "the takeaway pass is in the shop")
frame(buyAt)
frame()
click("Click Again to")
frames(10)
closeModals()   -- the purchase's achievement may have levelled us up
click("Loot")
ok(buttonIndex("Redeem") ~= nil, "the takeaway pass is in the inventory")
click("Redeem")
click("Click Again to")
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

-- A toast stays until it is dismissed (decision 0018): Apple asks for nothing
-- that goes away on a timer.
-- "Equipped" is the Gear page's heading too; the toast is the second.
local function equippedShown()
  local n = 0
  for _, t in ipairs(g.texts) do if t == "Equipped" then n = n + 1 end end
  return n
end
eq(equippedShown(), 2, "equipping says so")
frames(600, 0.1)
eq(equippedShown(), 2, "and the toast is still there a minute later")
-- The toast's place: the window's top right, 120 down (the mock's window is
-- 920 wide at 0, 0).
g.mouse, g.mouseClicked = { 700, 140 }, true
frame()
g.mouseClicked = false
g.mouse = { 100, 100 }
frame()
eq(equippedShown(), 1, "a click on it takes it away")
frame(stashAt)
frame()
click("Equip")
frames(3)
eq(equippedShown(), 2, "equipping again says so again")
g.keys[ImGui.Key_Escape] = true
frame()
frame()
eq(equippedShown(), 1, "and Esc takes it away too")

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

------------------------------------------------------------------------------
-- Apple's Human Interface Guidelines (decision 0018)
------------------------------------------------------------------------------

local function startOver()
  fresh()
  welcomed()
end

local function luminance(col)
  local function ch(v)
    v = v / 255
    return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * ch(math.floor(col / 16777216) % 256) + 0.7152 * ch(math.floor(col / 65536) % 256)
         + 0.0722 * ch(math.floor(col / 256) % 256)
end
local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

do
  startOver()
  ok(g.configFlags and g.configFlags & ImGui.ConfigFlags_NavEnableKeyboard ~= 0,
     "the keyboard alone can move through the window: keyboard navigation is on")
  ok(g.navRing and g.navRing ~= 0xFFF200FF and contrast(g.navRing, 0x23272EFF) >= 3,
     "the focus ring has its own colour, not the accent, 3:1 on the ground")

  -- Every opaque word on every page is 7:1 on the ground (INK is on buttons).
  local worst, which = 99, nil
  for _, tab in ipairs(TAB_NAMES) do
    click(tab)
    frames(2)
    for i, text in ipairs(g.texts) do
      local col = g.textCols[i]
      if col and col % 256 == 255 and col ~= INK then
        local c = contrast(col, 0x23272EFF)
        if c < worst then worst, which = c, ("%s on %s (%08X)"):format(text, tab, col) end
      end
    end
  end
  ok(worst >= 7, ("every word is 7:1 on the ground (lowest %.2f: %s)"):format(worst, tostring(which)))
end

-- Reduce Motion: opening the same crate makes no sparks.
local function crateCircles(calm)
  startOver()
  if calm then
    click("Stats")
    g.toggleOnly = "Reduce Motion"
    frame()
    g.toggleOnly = nil
    frame()
  end
  click("Loot")
  frame(buttonIndex("Open", 3))
  frames(2)
  frame(buttonIndex("##crate"))
  local most = 0
  for _ = 1, 35 do frame(); most = math.max(most, g.circles) end
  return most
end
do
  local moving, still = crateCircles(false), crateCircles(true)
  ok(moving > 60, "a crate bursts in sparks: " .. moving .. " circles at most in a frame")
  ok(still < 30, "with Reduce Motion, none: " .. still)
  atexitFn()
  local saved = io.open(P.resource .. "/Data/DAW Battle Pass/progress.lua"):read("a")
  ok(saved:find("reduceMotion=true", 1, true) ~= nil, "Reduce Motion is saved")
end

------------------------------------------------------------------------------
-- The final sweep of Apple's Foundations (0018, 21 October 2026)
------------------------------------------------------------------------------

local SAVE = function() return P.resource .. "/Data/DAW Battle Pass/progress.lua" end
local function readSave()
  local f = io.open(SAVE(), "rb")
  if not f then return "" end
  local t = f:read("a")
  f:close()
  return t
end

-- The family's checks: 13-point text, 28-point controls 12 apart, the ring,
-- every word 7:1, the ink bar, and Text Size from the View menu and the keys,
-- remembered and clamped. The setting is saved inside the progress file.
HIG.check({
  ok = ok, eq = eq, frame = function() frame() end,
  loaded = function() startOver(); click("Stats"); frame() end,
  quit = function() atexitFn() end,
  restart = function() start(); frame() end,
  saved = function() return readSave() end,
  setSaved = function(v)
    if v == "" then return end
    local t = readSave():gsub("textSize=%d+", v)
    local f = io.open(SAVE(), "wb"); f:write(t); f:close()
  end,
  sizeKey = "textSize",
})
local function textSize(label) HIG.menuFrame({ frame = function() frame() end }, label) end

do
  startOver()
  click("Quests")
  ok(g.title:find("^DAW Battle Pass \u{2014} Quests###") ~= nil, "the title names the page: " .. g.title)
  click("Loot")
  frame(buttonIndex("Open", 3))
  frames(2)
  ok(g.title:find("Reward###", 1, true) ~= nil, "or the celebration in front of it: " .. g.title)
  closeModals()
  eq(g.minW, 420, "the window can be made no narrower than its tabs need")
  textSize("Text Size 200%")
  eq(g.minW, 840, "and that grows with the text")
  textSize("Text Size 100%")
end

local function rich()
  P.reset()
  P.resource = tmp .. "/resource"
  os.execute('rm -rf "' .. P.resource .. '"')
  clock.epoch = EPOCH
  seedRichSave()
  start()
  frame()
  closeModals()
end

-- Nothing runs off the window's edge: every page, the welcome and a crate
-- opening, at 100% and 200%, in a roomy window and the smallest one.
do
  local function noOverflow(where)
    ok(g.right <= 10 + (g.avail or 900) + 1,
       ("nothing past the window's edge (%s): %s reaches %.0f of %d"):format(where, tostring(g.rightWhat),
         g.right, 10 + (g.avail or 900)))
  end
  for _, size in ipairs({ 100, 200 }) do
    local k = size / 100
    for _, width in ipairs({ 900, 420 * k - 20 }) do
      fresh()
      textSize("Text Size " .. size .. "%")
      g.avail = width
      frames(20)
      noOverflow(size .. "%, " .. width .. " wide, the welcome")
      click("Let's Go")
      frames(3)
      closeModals()
      atexitFn()
      g.avail = nil
      rich()
      textSize("Text Size " .. size .. "%")
      g.avail = width
      for _, tab in ipairs(TAB_NAMES) do
        click(tab)
        frames(2)
        noOverflow(size .. "%, " .. width .. " wide, " .. tab)
      end
      ok(HIG.font and HIG.font.size == 13 * k, "the pages were drawn at " .. size .. "%")
      click("Loot")
      frame(buttonIndex("Open", 3))
      frames(2)
      frame(buttonIndex("##crate"))
      for _ = 1, 40 do frame() end
      noOverflow(size .. "%, " .. width .. " wide, a crate opened")
      closeModals()
      g.avail = nil
      textSize("Text Size 100%")
      atexitFn()
    end
  end
end

-- "Click Again to ..." waits for the second click as long as it takes: no
-- timer (it used to give up after three seconds).
do
  rich()
  click("Shop")
  frames(2)
  frame(buttonIndex("Buy for 2,500 Coins"))
  frames(600, 0.1)
  ok(buttonIndex("Click Again to Buy") ~= nil, "a minute later the button still asks")
  -- Esc lets go of the keyboard's place, or a menu, before anything else.
  g.focused = true
  g.keys[ImGui.Key_Escape] = true
  frames(2)
  g.focused = false
  ok(buttonIndex("Click Again to Buy") ~= nil, "Esc with a control focused lets go of it, and the button still asks")
  g.popupOpen = true
  g.keys[ImGui.Key_Escape] = true
  frames(2)
  g.popupOpen = false
  ok(buttonIndex("Click Again to Buy") ~= nil, "Esc with a menu open closes only the menu")
  g.keys[ImGui.Key_Escape] = true
  frames(2)
  ok(buttonIndex("Click Again to Buy") == nil, "until Esc lets it go")
end

-- Every colour the theme pushes is a blue-shifted grey (R < G < B) but the
-- accent; and the menus are a step lighter than the window, keys 7:1 on them.
do
  local src = io.open(SCRIPT, "rb"):read("a")
  local theme = src:match("local THEME = (%b{})")
  local bad
  for name, hex in theme:gmatch('"(Col_[%w_]+)",%s*0x(%x%x%x%x%x%x)') do
    local r, gg, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    if hex ~= "FFF200" and not (r < gg and gg < b) then bad = bad or (name .. " #" .. hex) end
  end
  ok(theme and not bad, "every theme colour is a blue-shifted grey, R < G < B: " .. tostring(bad))
  local function themed(name) return tonumber(theme:match('"' .. name .. '",%s*0x(%x+)'), 16) end
  eq(themed("Col_PopupBg"), 0x2A2F37FF, "menus and tooltips are a step lighter than the window")
  ok(contrast(themed("Col_TextDisabled"), themed("Col_PopupBg")) >= 7, "the menu's keys are 7:1 on it")
  ok(contrast(themed("Col_ScrollbarGrab"), themed("Col_ScrollbarBg")) >= 3, "the scrollbar's grab is 3:1 on its track")
end

-- Closing the window stops the script.
g.closeWindow = true
frame()
ok(deferred == nil, "closing the window stops the script")
g.closeWindow = false

os.time = realTime
os.execute('rm -rf "' .. tmp .. '"')
C.done()
