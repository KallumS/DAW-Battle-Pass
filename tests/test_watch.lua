--[[ Watching REAPER and putting rewards into it, against a mocked REAPER.

     The mock (tests/reaper_mock.lua) is written from the API documentation's
     signatures and raises on anything it does not have, so a call REAPER does
     not have fails here rather than in REAPER.

       lua5.4 tests/test_watch.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local C = dofile(HERE .. "/check.lua")
local ok, eq = C.ok, C.eq
local P = dofile(HERE .. "/reaper_mock.lua")
P.install()
local T = dofile(C.SCRIPTS .. "bp_theory.lua")
local L = dofile(C.SCRIPTS .. "bp_loot.lua").init(T)
local G = dofile(C.SCRIPTS .. "bp_game.lua").init(L)
local W = dofile(C.SCRIPTS .. "bp_watch.lua").init(G)

local function find(events, kind)
  for _, e in ipairs(events) do if e[1] == kind then return e end end
end

------------------------------------------------------------------------------
-- Is anyone there?
------------------------------------------------------------------------------

P.reset()
local w = W.new()
local s = W.signals(w, P.now, false)
ok(not s.input, "the first look sees nothing happen")
eq(s.project, "(unsaved project)", "an unsaved project has a name")
P.projName = "My Song.RPP"
s = W.signals(w, P.now, false)
eq(s.project, "My Song", "a project is named without its extension")
P.scc = 1
ok(W.signals(w, P.now, false).input, "an edit is activity")
ok(not W.signals(w, P.now, false).input, "nothing new, no activity")
P.mouse = { 10, 20 }
ok(W.signals(w, P.now, false).input, "moving the mouse is activity")
P.cursor = 3
ok(W.signals(w, P.now, false).input, "moving the edit cursor is activity")
P.play = 1
s = W.signals(w, P.now, false)
ok(s.input and s.playing, "pressing play is activity, and playing")
P.play = 5
s = W.signals(w, P.now, false)
ok(s.recording, "recording is seen")
P.play = 0
W.signals(w, P.now, false)
ok(W.signals(w, P.now, true).input, "using the battle pass window is activity")

-- With js_ReaScriptAPI: the mouse only counts while REAPER is in front.
P.extensions.JS_Window_GetForeground = function() return "browser" end
P.extensions.JS_Window_GetParent = function(h) return nil end
P.extensions.JS_Window_GetTitle = function(h) return "Some Web Page - Browser" end
P.mouse = { 50, 60 }
ok(not W.signals(w, P.now, false).input, "moving the mouse in another app is not activity")
P.extensions.JS_Window_GetForeground = function() return "fxwin" end
P.extensions.JS_Window_GetParent = function(h) if h == "fxwin" then return "main" end end
P.mouse = { 70, 80 }
ok(W.signals(w, P.now, false).input, "moving it in a window REAPER owns is")
P.extensions.JS_VKeys_GetState = function(cut) return "\0\0\1\0" end
P.now = P.now + 1
ok(W.signals(w, P.now, false).input, "a key pressed is activity")
P.extensions = {}

------------------------------------------------------------------------------
-- What changed?
------------------------------------------------------------------------------

P.reset()
local tr = P.track("Drums")
P.addFx(tr, "VST3: Pro-Q 3 (FabFilter)")
P.item(tr, 0, 4, { { start = 0, len = 1, pitch = 36 } })
w = W.new()
local ev = W.scan(w, P.now, true)
eq(#ev, 0, "the first look at a project counts nothing already in it")

local tr2 = P.track("Synth")
P.addFx(tr2, "VST3i: Serum (Xfer Records)", "VST3i: Serum (Xfer Records)")
P.scc = P.scc + 1
P.now = P.now + 1
ev = W.scan(w, P.now)
eq(find(ev, "track")[2], 1, "a new track is seen")
local f = find(ev, "fx")
ok(f and f[3].name == "VST3i: Serum (Xfer Records)", "a new plugin is seen with its name")
ok(find(ev, "edit") ~= nil, "a change is an edit")

-- Renamed by the user: the original name is what counts.
P.addFx(tr2, "My Lovely Reverb", "VST: ValhallaVintageVerb (Valhalla DSP, LLC)")
P.scc = P.scc + 1
P.now = P.now + 1
ev = W.scan(w, P.now)
eq(find(ev, "fx")[3].name, "VST: ValhallaVintageVerb (Valhalla DSP, LLC)", "a renamed plugin goes by its real name")

-- Undo and redo: the same GUIDs come back, and nothing is counted twice.
local saved = table.remove(P.tracks)
P.scc = P.scc + 1
P.now = P.now + 1
W.scan(w, P.now)
P.tracks[#P.tracks + 1] = saved
P.scc = P.scc + 1
P.now = P.now + 1
ev = W.scan(w, P.now)
eq(find(ev, "track"), nil, "a track undone and redone is not new")
eq(find(ev, "fx"), nil, "nor are its plugins")

-- Items, notes, takes, markers.
P.item(tr, 4, 4, { { start = 0, len = 1, pitch = 38 }, { start = 1, len = 1, pitch = 38 } })
P.scc = P.scc + 1
P.now = P.now + 1
ev = W.scan(w, P.now)
eq(find(ev, "item")[2], 1, "a new item")
eq(find(ev, "notes")[2], 2, "with its notes")
eq(find(ev, "take"), nil, "not recorded, so not a take")
P.play = 5
W.signals(w, P.now, false)
P.item(tr, 8, 4, {}, false)
P.scc = P.scc + 1
P.now = P.now + 1
ev = W.scan(w, P.now)
ok(find(ev, "take") ~= nil, "an item made while recording is a take")
P.play = 0
P.markers[#P.markers + 1] = { isrgn = false, pos = 1 }
P.scc = P.scc + 1
P.now = P.now + 1
ev = W.scan(w, P.now)
eq(find(ev, "marker")[2], 1, "a new marker")

-- Looking is rationed: nothing changed, no look until five seconds pass.
P.now = P.now + 1
ev = W.scan(w, P.now)
eq(#ev, 0, "nothing changed, nothing seen")

-- A different project: everything in it is a baseline, not new.
P.proj = { kind = "project" }
P.track("Another")
P.now = P.now + 6
ev = W.scan(w, P.now)
eq(#ev, 0, "switching projects counts nothing")

------------------------------------------------------------------------------
-- Rewards into the project
------------------------------------------------------------------------------

P.reset()
local block = { name = "Chords: Am F C G", beats = 16, notes = {
  { start = 0, len = 4, pitch = 57, vel = 90 }, { start = 4, len = 4, pitch = 53, vel = 90 } } }
eq(W.insert({ name = "x", beats = 4, notes = {} }), W.NOTHING, "an empty block is nothing")
local res, made = W.insert(block)
eq(res, W.OK, "with no track selected, the idea still goes in")
ok(made, "on a new track")
eq(#P.tracks, 1, "one new track")
eq(P.tracks[1].name, "Chords", "named for the idea")
local item = P.tracks[1].items[1]
eq(#item.take.notes, 2, "with every note")
eq(item.take.name, block.name, "the take named for the idea")
ok(item.take.sorted, "sorted once")
for _, n in ipairs(item.take.notes) do ok(n.noSort, "each note inserted with noSort") end
eq(P.undoDepth, 0, "the undo block is closed")
eq(P.refreshDepth, 0, "and the UI refresh released")
ok(P.undoNames[1]:find("^Battle Pass: "), "the undo step is named")

local sel = P.track("Keys")
P.selTracks = { sel }
P.cursor = 2
res, made = W.insert(block)
ok(res == W.OK and not made, "with a track selected, it goes there")
eq(sel.items[1].pos, 2, "at the edit cursor")
eq(sel.items[1].take.notes[2].sp, 4 * 960, "note times measured from the item's start")

P.reset()
P.cursor = 0
eq(W.addRegions({ { "Intro", 8 }, { "Verse", 16 } }), W.OK, "an arrangement becomes regions")
eq(#P.markers, 2, "one per section")
ok(P.markers[1].isrgn and P.markers[1].name == "Intro", "named for the section")
eq(P.markers[2].pos, P.markers[1].rgnend, "end to end")
eq(P.markers[1].rgnend - P.markers[1].pos, 8 * 2, "eight bars of 4/4 at 120 is sixteen seconds")
eq(P.undoDepth, 0, "the undo block is closed")
P.num, P.den = 6, 8
P.markers = {}
W.addRegions({ { "A", 4 } })
eq(P.markers[1].rgnend - P.markers[1].pos, 4 * 1.5, "a bar is the project's bar: four bars of 6/8")
eq(W.setTempo(97), W.OK, "a seed sets the tempo")
eq(P.bpmSet, 97, "to its tempo")

------------------------------------------------------------------------------
-- Plugins
------------------------------------------------------------------------------

P.reset()
local list = W.parsePluginList("# comment\n\nSerum\n  Pro-Q 3  \nSerum\nVST3i: Diva (u-he)\n")
eq(#list, 3, "the user's list: names, no comments, blanks or repeats")
eq(list[1].norm, "serum", "names are matched plainly")
eq(list[3].display, "Diva", "a pasted REAPER name is tidied")
ok(list[3].instrument, "and keeps knowing it's an instrument")

P.installed = { "VST3: Pro-Q 3 (FabFilter)", "VST: Pro-Q 3 (FabFilter)", "JS: Utility/volume", "VSTi: Serum (Xfer Records)",
                "Video processor", "CLAP: Surge XT (Surge Synth Team)" }
local inst = W.installedPlugins()
eq(#inst, 3, "installed plugins: once each, no JSFX or video")
local plugins, source = W.plugins()
eq(source, "everything installed", "with no list of your own, everything installed")
W.ensurePluginFile()
local f2 = io.open(W.pluginListPath(), "a")
f2:write("Serum\n")
f2:close()
plugins, source = W.plugins()
eq(source, "your list", "a list of your own wins")
eq(#plugins, 1, "with what's in it")
os.remove(W.pluginListPath())

------------------------------------------------------------------------------
-- Saving and starting
------------------------------------------------------------------------------

P.reset()
os.execute('rm -rf "' .. P.resource .. '"')
local st, how = W.loadState(G)
eq(st, nil, "no save yet")
eq(how, "new", "is a new player")
local state = G.newState(1)
state.coins = 123
ok(W.writeAtomic(W.savePath(), G.serialize(state)), "a save is written")
st, how = W.loadState(G)
eq(st.coins, 123, "and read back")
state.coins = 456
W.writeAtomic(W.savePath(), G.serialize(state))
local f3 = io.open(W.savePath(), "wb")
f3:write("{ broken")
f3:close()
st, how = W.loadState(G)
eq(how, "backup", "a damaged save falls back to the last good one")
eq(st.coins, 123, "which is the one before")
local damaged = false
local p = io.popen('ls "' .. W.dataDir() .. '"')
for name in p:lines() do if name:find("damaged") then damaged = true end end
p:close()
ok(damaged, "and the damaged file is kept aside, not lost")

os.execute('mkdir -p "' .. P.resource .. '/Scripts"')
local f4 = io.open(W.startupPath(), "wb")
f4:write("-- my own startup line\nreaper.ShowConsoleMsg('hi')\n")
f4:close()
ok(not W.autostartOn(), "not starting with REAPER at first")
ok(W.setAutostart(true, "/scripts/DAW Battle Pass.lua"), "turning it on works")
ok(W.autostartOn(), "and shows as on")
local body = W.readFile(W.startupPath())
ok(body:find("my own startup line", 1, true) and body:find("_RS0123456789abcdef", 1, true), "the user's lines kept, ours added")
W.setAutostart(true, "/scripts/DAW Battle Pass.lua")
local _, count = W.readFile(W.startupPath()):gsub("DAW Battle Pass: start with REAPER", "")
eq(count, 1, "turning it on twice adds it once")
ok(W.setAutostart(false), "turning it off works")
ok(not W.autostartOn(), "and shows as off")
ok(W.readFile(W.startupPath()):find("my own startup line", 1, true), "leaving the user's lines alone")
ok(not W.open("/x"), "without SWS, nothing is opened")

C.done()
