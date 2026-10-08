--[[ DAW Battle Pass - watching REAPER, and putting rewards into it.

     Everything here talks to REAPER, and nothing here touches ImGui, so
     tests/test_watch.lua can run it against a mocked reaper. The mock is
     written from the API documentation's signatures, not from this file.

     Three jobs:

       - Is anyone there? `signals` reads the mouse, the project's change
         count, the transport and the edit cursor, and says whether anything
         happened. With the js_ReaScriptAPI extension it also checks that
         REAPER is the app in front, and reads the keyboard; without it, it
         still works, a little more trusting.
       - What changed? `scan` compares the project with what it saw last time
         and reports new tracks, items, plugins, MIDI notes, recorded takes and
         markers. Things are known by their GUIDs, so undo and redo, or
         switching project tabs, never count the same track twice.
       - Rewards into the project: an idea's MIDI at the edit cursor, an
         arrangement as regions, a seed's tempo.

     A REAPER extension the user may not have (js_ReaScriptAPI, SWS) is only
     ever reached through `ext`, which asks rather than assumes.
]]

local W = {}

W.OK, W.NOTHING, W.NO_TRACK = 0, 1, 2

local SEP = package.config:sub(1, 1)

-- An extension's function, or nil if it is not installed. Looked up with
-- rawget-style care: reaper is a plain table in REAPER, and the test mock
-- answers nil for these names only.
local function ext(name) return reaper[name] end
W.ext = ext

function W.init(G) W.G = G; return W end

------------------------------------------------------------------------------
-- Files
------------------------------------------------------------------------------

function W.dataDir() return reaper.GetResourcePath() .. SEP .. "Data" .. SEP .. "DAW Battle Pass" end
function W.savePath() return W.dataDir() .. SEP .. "progress.lua" end
function W.pluginListPath() return W.dataDir() .. SEP .. "My Plugins.txt" end

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end
W.readFile = readFile

-- Written beside the old file and swapped in, with the last good save kept
-- as .bak, so a crash mid-write never costs progress.
function W.writeAtomic(path, data)
  reaper.RecursiveCreateDirectory(W.dataDir(), 0)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "wb")
  if not f then return false end
  f:write(data)
  f:close()
  os.remove(path .. ".bak")
  os.rename(path, path .. ".bak")
  if not os.rename(tmp, path) then
    f = io.open(path, "wb")
    if not f then return false end
    f:write(data)
    f:close()
    os.remove(tmp)
  end
  return true
end

-- The saved state, the backup if the save is damaged, or nil. A damaged file
-- is copied aside rather than overwritten, so nothing is ever lost silently.
function W.loadState(G)
  local main = readFile(W.savePath())
  local st = G.deserialize(main)
  if st then return st, "loaded" end
  local bak = G.deserialize(readFile(W.savePath() .. ".bak"))
  if main and main ~= "" then
    local f = io.open(W.savePath() .. ".damaged-" .. os.time(), "wb")
    if f then f:write(main); f:close() end
  end
  if bak then return bak, "backup" end
  return nil, main and "damaged" or "new"
end

------------------------------------------------------------------------------
-- Plugins
------------------------------------------------------------------------------

local PLUGIN_FILE_HELP = [[
# DAW Battle Pass - your plugins
#
# Quests can ask you to use particular plugins. By default the battle pass
# picks them from every plugin REAPER knows about. To choose for yourself,
# write one plugin name per line below (just the name, e.g. Serum or
# Pro-Q 3) and save this file. Lines starting with # are ignored.
# Leave it with no names to go back to using everything installed.

]]

function W.ensurePluginFile()
  local path = W.pluginListPath()
  if not reaper.file_exists(path) then
    reaper.RecursiveCreateDirectory(W.dataDir(), 0)
    local f = io.open(path, "wb")
    if f then f:write(PLUGIN_FILE_HELP); f:close() end
  end
  return path
end

-- The user's own list: one name a line, # for comments.
function W.parsePluginList(text)
  local G = W.G
  local out, seen = {}, {}
  for line in (text or ""):gmatch("[^\r\n]+") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local norm, display, instrument = G.normFx(line)
      if norm ~= "" and not seen[norm] then
        seen[norm] = true
        out[#out + 1] = { norm = norm, display = display, instrument = instrument }
      end
    end
  end
  return out
end

-- Everything REAPER has scanned, bar JSFX and video processors (hundreds of
-- utilities nobody wants a quest about), each name once however many formats
-- it comes in.
function W.installedPlugins()
  local G = W.G
  local out, seen = {}, {}
  if not reaper.EnumInstalledFX then return out end
  local i = 0
  while i < 20000 do
    local ok, name = reaper.EnumInstalledFX(i)
    if not ok then break end
    local prefix = name:match("^(%u+%d?i?):")
    if prefix and prefix ~= "JS" and not name:find("^Video processor") then
      local norm, display, instrument = G.normFx(name)
      if norm ~= "" and not seen[norm] then
        seen[norm] = true
        out[#out + 1] = { norm = norm, display = display, instrument = instrument }
      end
    end
    i = i + 1
  end
  return out
end

-- The user's list when it has any names in it, everything installed when not.
function W.plugins()
  local own = W.parsePluginList(readFile(W.pluginListPath()))
  if #own > 0 then return own, "your list" end
  return W.installedPlugins(), "everything installed"
end

------------------------------------------------------------------------------
-- Is anyone there?
------------------------------------------------------------------------------

function W.new()
  return { proj = nil, scc = nil, play = nil, mx = nil, my = nil, cursor = nil,
           tracks = {}, fx = {}, items = {}, notes = 0, markers = 0,
           nextScan = 0, scannedScc = nil, recUntil = 0, keysAt = 0 }
end

-- With js_ReaScriptAPI: is the window in front REAPER's (its main window, or
-- anything it owns - FX windows, the MIDI editor, this script's own window)?
-- Without it, nil: we cannot tell, so the mouse is trusted.
function W.reaperInFront()
  local fg, parent = ext("JS_Window_GetForeground"), ext("JS_Window_GetParent")
  if not fg or not parent then return nil end
  local main = reaper.GetMainHwnd()
  local w = fg()
  for _ = 1, 12 do
    if not w then break end
    if w == main then return true end
    w = parent(w)
  end
  local title = fg() and ext("JS_Window_GetTitle") and ext("JS_Window_GetTitle")(fg()) or ""
  if title:find("REAPER") or title:find("Battle Pass") then return true end
  return false
end

-- { input, playing, recording, project } for the game's clock.
-- `own` is true when the mouse is busy in the battle pass's own window.
function W.signals(w, tp, own)
  local input = own and true or false
  local proj = reaper.EnumProjects(-1)
  local scc = reaper.GetProjectStateChangeCount(proj)
  if w.scc and scc ~= w.scc then input = true end
  w.scc = scc

  local play = reaper.GetPlayState()
  if w.play and play ~= w.play then input = true end
  w.play = play
  local recording = play & 4 == 4
  if recording then w.recUntil = tp + 3 end

  local cursor = reaper.GetCursorPosition()
  if w.cursor and cursor ~= w.cursor then input = true end
  w.cursor = cursor

  local front = W.reaperInFront()
  local mx, my = reaper.GetMousePosition()
  if w.mx and (mx ~= w.mx or my ~= w.my) and front ~= false then input = true end
  w.mx, w.my = mx, my

  local keys = ext("JS_VKeys_GetState")
  if keys and front ~= false and tp >= w.keysAt then
    w.keysAt = tp + 0.25
    local state = keys(tp - 1)
    if type(state) == "string" and state:find("\1") then input = true end
  end

  return { input = input, playing = play & 1 == 1, recording = recording, project = W.projectName(proj) }
end

function W.projectName(proj)
  local name = reaper.GetProjectName(proj, "")
  if not name or name == "" then return "(unsaved project)" end
  return (name:gsub("%.[Rr][Pp][Pp]$", ""))
end

------------------------------------------------------------------------------
-- What changed?
------------------------------------------------------------------------------

local function fxName(track, i)
  local _, orig = reaper.TrackFX_GetNamedConfigParm(track, i, "fx_name")
  if orig and orig ~= "" then return orig end
  local _, name = reaper.TrackFX_GetFXName(track, i, "")
  return name or ""
end

-- Everything in the project now: track GUIDs, FX GUIDs (with names), item
-- GUIDs, the MIDI note count and the marker count.
local function survey(proj)
  local now = { tracks = {}, fx = {}, items = {}, notes = 0, markers = 0 }
  local function trackFx(tr)
    for i = 0, reaper.TrackFX_GetCount(tr) - 1 do
      local g = reaper.TrackFX_GetFXGUID(tr, i)
      if g then now.fx[g] = { track = tr, index = i } end
    end
  end
  trackFx(reaper.GetMasterTrack(proj))
  for t = 0, reaper.CountTracks(proj) - 1 do
    local tr = reaper.GetTrack(proj, t)
    now.tracks[reaper.GetTrackGUID(tr)] = true
    trackFx(tr)
  end
  for i = 0, reaper.CountMediaItems(proj) - 1 do
    local item = reaper.GetMediaItem(proj, i)
    local _, g = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
    now.items[g] = true
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local _, notes = reaper.MIDI_CountEvts(take)
      now.notes = now.notes + (notes or 0)
    end
  end
  local _, m, r = reaper.CountProjectMarkers(proj)
  now.markers = (m or 0) + (r or 0)
  return now
end

-- The project as it is, remembered without counting anything: on the first
-- look and whenever the project tab changes.
local function baseline(w, proj, now)
  w.proj = proj
  w.tracks, w.items = now.tracks, now.items
  w.fx = {}
  for g in pairs(now.fx) do w.fx[g] = true end
  w.notes, w.markers = now.notes, now.markers
end

-- Events since the last look, as { kind, n, info }. Looks when the project
-- has changed (the change count moved), at most twice a second, and every
-- five seconds regardless.
function W.scan(w, tp, force)
  local proj = reaper.EnumProjects(-1)
  local scc = reaper.GetProjectStateChangeCount(proj)
  if not force and proj == w.proj and tp < w.nextScan and scc == w.scannedScc then return {} end
  if not force and proj == w.proj and scc ~= w.scannedScc and tp < (w.lastScan or 0) + 0.5 then return {} end
  w.lastScan, w.nextScan = tp, tp + 5
  local changed = w.scannedScc ~= nil and scc ~= w.scannedScc
  w.scannedScc = scc
  local now = survey(proj)
  if proj ~= w.proj then baseline(w, proj, now); return {} end

  local events = {}
  if changed then events[#events + 1] = { "edit", 1 } end
  local n = 0
  for g in pairs(now.tracks) do if not w.tracks[g] then n = n + 1; w.tracks[g] = true end end
  if n > 0 then events[#events + 1] = { "track", n } end
  n = 0
  for g in pairs(now.items) do if not w.items[g] then n = n + 1; w.items[g] = true end end
  if n > 0 then
    events[#events + 1] = { "item", n }
    if tp <= w.recUntil then events[#events + 1] = { "take", n } end
  end
  for g, where in pairs(now.fx) do
    if not w.fx[g] then
      w.fx[g] = true
      events[#events + 1] = { "fx", 1, { name = fxName(where.track, where.index) } }
    end
  end
  if now.notes > w.notes then events[#events + 1] = { "notes", now.notes - w.notes } end
  w.notes = now.notes
  if now.markers > w.markers then events[#events + 1] = { "marker", now.markers - w.markers } end
  w.markers = now.markers
  return events
end

------------------------------------------------------------------------------
-- Rewards into the project
------------------------------------------------------------------------------

-- The selected track, the last touched, or a new one at the end named for
-- the idea - a reward should always land somewhere.
function W.targetTrack(name)
  local tr = reaper.GetSelectedTrack(0, 0) or reaper.GetLastTouchedTrack()
  if tr then return tr, false end
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  return tr, true
end

-- A block ({ name, beats, notes = { start, len, pitch, vel } }, all in
-- quarter notes) as one MIDI item at the edit cursor, as one undo step.
function W.insert(block)
  if not block or not block.notes or #block.notes == 0 then return W.NOTHING end
  local time = reaper.GetCursorPosition()
  local startQN = reaper.TimeMap2_timeToQN(0, time)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local track, made = W.targetTrack(block.name:match("^([^:]+)") or "Battle Pass")
  local endTime = reaper.TimeMap2_QNToTime(0, startQN + block.beats)
  local item = reaper.CreateNewMIDIItemInProj(track, time, endTime, false)
  local ok = item ~= nil
  if item then
    local take = reaper.GetActiveTake(item)
    for _, nt in ipairs(block.notes) do
      local sp = reaper.MIDI_GetPPQPosFromProjQN(take, startQN + nt.start)
      local ep = reaper.MIDI_GetPPQPosFromProjQN(take, startQN + nt.start + nt.len)
      reaper.MIDI_InsertNote(take, false, false, sp, ep, 0, nt.pitch, nt.vel or 100, true)
    end
    reaper.MIDI_Sort(take)
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", block.name, true)
  end
  reaper.PreventUIRefresh(-1)
  if made then reaper.TrackList_AdjustWindows(false) end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Battle Pass: " .. block.name, -1)
  return ok and W.OK or W.NO_TRACK, made
end

-- An arrangement as regions from the edit cursor, a bar being the project's
-- bar there.
function W.addRegions(sections)
  if not sections or #sections == 0 then return W.NOTHING end
  local time = reaper.GetCursorPosition()
  local num, den = reaper.TimeMap_GetTimeSigAtTime(0, time)
  if not num or num <= 0 or not den or den <= 0 then num, den = 4, 4 end
  local barQN = num * 4 / den
  local qn = reaper.TimeMap2_timeToQN(0, time)
  reaper.Undo_BeginBlock()
  for i, s in ipairs(sections) do
    local a = reaper.TimeMap2_QNToTime(0, qn)
    qn = qn + s[2] * barQN
    local b = reaper.TimeMap2_QNToTime(0, qn)
    local shade = (i % 2 == 0) and reaper.ColorToNative(88, 95, 107) or reaper.ColorToNative(58, 64, 74)
    reaper.AddProjectMarker2(0, true, a, b, s[1], -1, shade | 0x1000000)
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Battle Pass: arrangement regions", -1)
  return W.OK
end

function W.setTempo(bpm)
  if not bpm or bpm <= 0 then return W.NOTHING end
  reaper.SetCurrentBPM(0, bpm, true)
  return W.OK
end

------------------------------------------------------------------------------
-- Starting with REAPER
--
-- REAPER runs Scripts/__startup.lua when it starts. Turning this on adds one
-- line there that runs the battle pass; turning it off takes that line out
-- and leaves everything else in the file alone.
------------------------------------------------------------------------------

local MARK = "-- DAW Battle Pass: start with REAPER"

function W.startupPath() return reaper.GetResourcePath() .. SEP .. "Scripts" .. SEP .. "__startup.lua" end

function W.autostartOn()
  local s = readFile(W.startupPath())
  return s ~= nil and s:find(MARK, 1, true) ~= nil
end

function W.setAutostart(on, scriptPath)
  local path = W.startupPath()
  local s = readFile(path) or ""
  local lines = {}
  for line in (s .. "\n"):gmatch("(.-)\r?\n") do
    if not line:find(MARK, 1, true) then lines[#lines + 1] = line end
  end
  while #lines > 0 and lines[#lines] == "" do lines[#lines] = nil end
  if on then
    local id = reaper.AddRemoveReaScript(true, 0, scriptPath, true)
    if not id or id == 0 then return false end
    local named = reaper.ReverseNamedCommandLookup(id)
    if not named or named == "" then return false end
    lines[#lines + 1] = 'reaper.Main_OnCommand(reaper.NamedCommandLookup("_' .. named .. '"), 0) ' .. MARK
  end
  reaper.RecursiveCreateDirectory(reaper.GetResourcePath() .. SEP .. "Scripts", 0)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
  f:close()
  return true
end

-- Opens a file in its usual app, if SWS is there to do it.
function W.open(path)
  local shell = ext("CF_ShellExecute")
  if shell then shell(path); return true end
  return false
end

return W
