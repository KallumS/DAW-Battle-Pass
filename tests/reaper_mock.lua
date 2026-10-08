--[[ A REAPER that records instead of doing, for test_watch and test_ui.

     Written from the API documentation's signatures, not from what the
     scripts expect: a mock shaped by the code agrees with the code's bugs.
     (Starting Blocks learned that the hard way, with a TimeMap_GetTimeSigAtTime
     mock that had the same wrong return shape as the code that called it.)

     Anything the scripts call that is not here raises, so a call to a
     function REAPER does not have fails in the test, not in REAPER. The one
     exception is an optional extension's function (js_ReaScriptAPI, SWS):
     those answer nil unless a test installs them in P.extensions, which is
     what REAPER does when the extension is missing.

     The project: tracks in a list, each with FX (name and GUID) and items;
     items with a take that may be MIDI with notes; markers and regions; one
     tempo (120 unless set) and one time signature. Notes are in PPQ at 960
     a quarter.

     Midi Catalogue's mock (itself Midi Suggester's) is where this started;
     the track, take, MIDI, undo and time functions are its, unchanged in
     shape. Added for the battle pass, each from its documented signature:
     EnumProjects, GetProjectStateChangeCount, GetMousePosition,
     GetProjectName, GetMasterTrack, GetTrackGUID, TrackFX_GetFXGUID,
     TrackFX_GetFXName, TrackFX_GetNamedConfigParm, CountMediaItems,
     GetMediaItem, GetSetMediaItemInfo_String, CountProjectMarkers,
     EnumInstalledFX, AddProjectMarker2, ColorToNative, SetCurrentBPM,
     file_exists, AddRemoveReaScript, ReverseNamedCommandLookup, GetMainHwnd,
     get_action_context, defer, atexit, set_action_options,
     SetToggleCommandState, RefreshToolbar2, MB.
]]

local P = {
  tracks = {}, master = nil, selTracks = {}, lastTouched = nil,
  now = 1000.0, resource = "/tmp/daw-battle-pass-test-resource",
  tempo = 120, num = 4, den = 4, cursor = 0, play = 0, mouse = { 0, 0 },
  scc = 0, projName = "", proj = { kind = "project" },
  undoDepth = 0, undoNames = {}, refreshDepth = 0, markers = {}, installed = {},
  scripts = {}, bpmSet = nil, extensions = {}, nextGuid = 1,
}

local PPQ = 960
local function qnPerSec() return P.tempo / 60 end

local OPTIONAL = { JS_Window_GetForeground = true, JS_Window_GetParent = true,
                   JS_Window_GetTitle = true, JS_VKeys_GetState = true, CF_ShellExecute = true }

local function guid()
  P.nextGuid = P.nextGuid + 1
  return string.format("{%08X-0000-0000-0000-000000000000}", P.nextGuid)
end

local function newTrack(name)
  return { kind = "track", name = name or "", items = {}, fx = {}, alive = true, guid = guid() }
end

function P.track(name)
  local t = newTrack(name)
  P.tracks[#P.tracks + 1] = t
  return t
end

-- An FX on a track, as REAPER names it: "VST3i: Serum (Xfer Records)".
function P.addFx(track, name, original)
  track.fx[#track.fx + 1] = { name = name, original = original, guid = guid() }
end

-- An item of notes given in quarter notes from its own start.
function P.item(track, posQN, lenQN, notes, midi)
  local take = { kind = "take", midi = midi ~= false, notes = {}, name = "", sorted = true }
  local item = { kind = "item", track = track, pos = posQN / qnPerSec(), len = lenQN / qnPerSec(), take = take, guid = guid() }
  take.item = item
  for _, n in ipairs(notes or {}) do
    take.notes[#take.notes + 1] = { sp = n.start * PPQ, ep = (n.start + n.len) * PPQ, pitch = n.pitch,
                                    vel = n.vel or 100, muted = false, chan = 0 }
  end
  track.items[#track.items + 1] = item
  return item
end

local function indexOf(track)
  for i, t in ipairs(P.tracks) do if t == track then return i end end
end

local function allItems()
  local list = {}
  for _, t in ipairs(P.tracks) do for _, it in ipairs(t.items) do list[#list + 1] = it end end
  return list
end

local function takeStartQN(take) return take.item.pos * qnPerSec() end

local api = {
  -- Projects
  -- ReaProject retval, string projfn = reaper.EnumProjects(integer idx)
  EnumProjects = function(idx) return P.proj, "" end,
  -- integer reaper.GetProjectStateChangeCount(ReaProject proj)
  GetProjectStateChangeCount = function(_) return P.scc end,
  -- string buf = reaper.GetProjectName(ReaProject proj, string buf)
  GetProjectName = function(_, _) return P.projName end,

  -- Transport, cursor, mouse
  GetPlayState = function() return P.play end,
  GetCursorPosition = function() return P.cursor end,
  -- integer x, integer y = reaper.GetMousePosition()
  GetMousePosition = function() return P.mouse[1], P.mouse[2] end,
  time_precise = function() return P.now end,
  -- reaper.SetCurrentBPM(ReaProject __proj, number bpm, boolean wantUndo)
  SetCurrentBPM = function(_, bpm, wantUndo) P.bpmSet = bpm; P.tempo = bpm end,

  -- Tracks
  CountTracks = function(_) return #P.tracks end,
  GetTrack = function(_, i) return P.tracks[i + 1] end,
  GetMasterTrack = function(_)
    if not P.master then P.master = newTrack("MASTER") end
    return P.master
  end,
  -- string reaper.GetTrackGUID(MediaTrack tr)
  GetTrackGUID = function(tr) return tr.guid end,
  GetSelectedTrack = function(_, i) return P.selTracks[i + 1] end,
  GetLastTouchedTrack = function() return P.lastTouched end,
  InsertTrackAtIndex = function(idx, defaults)
    table.insert(P.tracks, math.min(idx, #P.tracks) + 1, newTrack(""))
  end,
  GetSetMediaTrackInfo_String = function(track, parm, value, set)
    if parm ~= "P_NAME" then error("mock has no track string " .. parm) end
    if set then track.name = value end
    return true, track.name
  end,
  TrackList_AdjustWindows = function(_) end,

  -- FX
  TrackFX_GetCount = function(track) return #track.fx end,
  -- string reaper.TrackFX_GetFXGUID(MediaTrack track, integer fx)
  TrackFX_GetFXGUID = function(track, i) local f = track.fx[i + 1]; return f and f.guid or nil end,
  -- boolean retval, string buf = reaper.TrackFX_GetFXName(MediaTrack track, integer fx, string buf)
  TrackFX_GetFXName = function(track, i, _)
    local f = track.fx[i + 1]
    if not f then return false, "" end
    return true, f.name
  end,
  -- boolean retval, string buf = reaper.TrackFX_GetNamedConfigParm(MediaTrack track, integer fx, string parmname)
  TrackFX_GetNamedConfigParm = function(track, i, parm)
    local f = track.fx[i + 1]
    if parm ~= "fx_name" or not f or not f.original then return false, "" end
    return true, f.original
  end,
  -- boolean retval, string name, string ident = reaper.EnumInstalledFX(integer index)
  EnumInstalledFX = function(i)
    local n = P.installed[i + 1]
    if not n then return false, "", "" end
    return true, n, n:lower()
  end,

  -- Items and takes
  CountMediaItems = function(_) return #allItems() end,
  GetMediaItem = function(_, i) return allItems()[i + 1] end,
  -- boolean retval, string stringNeedBig = reaper.GetSetMediaItemInfo_String(MediaItem item, string parmname, string stringNeedBig, boolean setNewValue)
  GetSetMediaItemInfo_String = function(item, parm, value, set)
    if parm ~= "GUID" then error("mock has no item string " .. parm) end
    if set then error("the scripts never set an item's GUID") end
    return true, item.guid
  end,
  GetActiveTake = function(item) return item.take end,
  TakeIsMIDI = function(take) return take.midi end,
  -- integer retval, integer notecnt, integer ccevtcnt, integer textsyxevtcnt
  MIDI_CountEvts = function(take) return 1, #take.notes, 0, 0 end,
  MIDI_GetPPQPosFromProjQN = function(take, qn) return (qn - takeStartQN(take)) * PPQ end,
  MIDI_InsertNote = function(take, sel, muted, sp, ep, chan, pitch, vel, noSort)
    take.notes[#take.notes + 1] = { sp = sp, ep = ep, pitch = pitch, vel = vel, chan = chan, muted = muted, noSort = noSort }
    take.sorted = false
    return true
  end,
  MIDI_Sort = function(take) take.sorted = true end,
  GetSetMediaItemTakeInfo_String = function(take, parm, value, set)
    if parm ~= "P_NAME" then error("mock has no take string " .. parm) end
    if set then take.name = value end
    return true, take.name
  end,
  CreateNewMIDIItemInProj = function(track, t0, t1, qnIn)
    if qnIn then error("the scripts pass seconds") end
    local take = { kind = "take", midi = true, notes = {}, name = "", sorted = true }
    local item = { kind = "item", track = track, pos = t0, len = t1 - t0, take = take, guid = guid() }
    take.item = item
    track.items[#track.items + 1] = item
    return item
  end,

  -- Markers
  -- integer retval, integer num_markers, integer num_regions = reaper.CountProjectMarkers(ReaProject proj)
  CountProjectMarkers = function(_)
    local m, r = 0, 0
    for _, mk in ipairs(P.markers) do if mk.isrgn then r = r + 1 else m = m + 1 end end
    return m + r, m, r
  end,
  -- integer reaper.AddProjectMarker2(ReaProject proj, boolean isrgn, number pos, number rgnend, string name, integer wantidx, integer color)
  AddProjectMarker2 = function(_, isrgn, pos, rgnend, name, wantidx, color)
    if type(isrgn) ~= "boolean" then error("isrgn must be a boolean") end
    P.markers[#P.markers + 1] = { isrgn = isrgn, pos = pos, rgnend = rgnend, name = name, color = color }
    return #P.markers
  end,
  -- integer reaper.ColorToNative(integer r, integer g, integer b)
  ColorToNative = function(r, g, b) return r + g * 256 + b * 65536 end,

  -- Time
  TimeMap2_timeToQN = function(_, t) return t * qnPerSec() end,
  TimeMap2_QNToTime = function(_, qn) return qn / qnPerSec() end,
  -- integer timesig_num, integer timesig_denom, number tempo: no retval first.
  TimeMap_GetTimeSigAtTime = function(_, _) return P.num, P.den, P.tempo end,

  -- Housekeeping
  Undo_BeginBlock = function() P.undoDepth = P.undoDepth + 1 end,
  Undo_EndBlock = function(name, flags)
    P.undoDepth = P.undoDepth - 1
    if P.undoDepth < 0 then error("Undo_EndBlock without a begin") end
    if type(name) ~= "string" or name == "" then error("an undo block needs a name") end
    P.undoNames[#P.undoNames + 1] = name
  end,
  PreventUIRefresh = function(n)
    P.refreshDepth = P.refreshDepth + n
    if P.refreshDepth < 0 then error("PreventUIRefresh went negative") end
  end,
  UpdateArrange = function() end,

  -- Files and actions
  GetResourcePath = function() return P.resource end,
  RecursiveCreateDirectory = function(path, _)
    os.execute('mkdir -p "' .. path .. '"')
    return 1
  end,
  -- boolean reaper.file_exists(string path)
  file_exists = function(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
  end,
  -- integer reaper.AddRemoveReaScript(boolean add, integer sectionID, string scriptfn, boolean commit)
  AddRemoveReaScript = function(add, section, fn, commit)
    P.scripts[#P.scripts + 1] = fn
    return 54321
  end,
  -- string reaper.ReverseNamedCommandLookup(integer command_id)
  ReverseNamedCommandLookup = function(id) return "RS0123456789abcdef" end,
  GetMainHwnd = function() return "main" end,
  get_action_context = function()
    return true, P.scriptPath or "/scripts/DAW Battle Pass.lua", 0, 777, -1, -1, -1, ""
  end,
  SetToggleCommandState = function(section, id, state) P.toggle = state end,
  RefreshToolbar2 = function(section, id) end,
  set_action_options = function(flags) P.actionOptions = flags end,
  MB = function(msg, title, kind) P.mb = msg; return 1 end,
}

function P.install()
  reaper = setmetatable({}, {
    __index = function(_, k)
      if OPTIONAL[k] then return P.extensions[k] end
      local f = api[k]
      if f == nil then error("the script called reaper." .. tostring(k) .. ", which the mock does not have") end
      return f
    end,
    __newindex = function(_, k, v) api[k] = v end,
  })
  return reaper
end

function P.reset()
  P.tracks, P.master, P.selTracks, P.lastTouched = {}, nil, {}, nil
  P.now, P.tempo, P.num, P.den, P.cursor, P.play = 1000.0, 120, 4, 4, 0, 0
  P.mouse, P.scc, P.projName, P.proj = { 0, 0 }, 0, "", { kind = "project" }
  P.undoDepth, P.undoNames, P.refreshDepth, P.markers = 0, {}, 0, {}
  P.installed, P.scripts, P.bpmSet, P.extensions = {}, {}, nil, {}
end

return P
