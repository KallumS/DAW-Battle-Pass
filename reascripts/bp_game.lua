--[[ DAW Battle Pass - the rules of the game.

     Pure Lua. Nothing in this file touches REAPER or ImGui. Every function
     takes the saved state (`st`), the session (`ss`, what lives only while
     the script runs) and the time it is, and changes them; what the window
     should celebrate is pushed onto `ss.notices` for it to animate.

     The time is always passed in, twice over:
       - `tp`, REAPER's time_precise(), a clock in seconds for idle and dt;
       - `epoch`, os.time(), for days, weeks and seasons.
     So the tests can run a week in a second.

     The shape of it:

       - Active time fills the SEASON PASS: a tier every fifteen active
         minutes, every fourth (each hour) a big one. A season is a calendar
         month with a 100-tier track, then endless bonus tiers.
       - Everything you do earns XP, which fills the LEVEL bar; every level
         gives a loot crate.
       - Daily CHECK-IN on a seven-day calendar, a streak, Streak Freezes.
       - Three DAILY and four WEEKLY QUESTS, some naming your own plugins.
       - COINS buy passes (permission slips: a takeaway, a movie...),
         tokens and crates in the SHOP, and a rotating set of Daily Deals.
       - GEAR in the manner of Diablo: six slots, affixes that boost XP,
         coins, loot and more, Legendary powers. Salvage what you don't want.
       - ACHIEVEMENTS in series, each with tiers.

     Loaded with dofile(...).init(L), handed the loot.
]]

local G = {}

G.VERSION = 1
G.TIER_SECONDS = 15 * 60         -- active time per pass tier
G.IDLE_SECONDS = 180             -- no activity for this long and you are idle
G.IDLE_PLAYING = 480             -- ...unless the project is playing back
G.DAY_START_HOUR = 4             -- a day (quests, check-in) starts at 4am
G.ACTION_XP_CAP = 120            -- base XP a minute from editing actions
G.STASH_MAX = 60
G.VAULT_MAX = 400
G.BOOST_SECONDS = 30 * 60

-- Base XP for each thing you do, before gear and boosts.
G.XP = { minute = 4, edit = 1, track = 10, item = 3, fx = 6, discover = 20,
         note = 0.5, take = 15, marker = 3, idea = 25, wind = 30 }

------------------------------------------------------------------------------
-- The coin shop. Prices in coins; edit freely. A focused hour earns very
-- roughly 400-600 coins, all told, so a takeaway is about five hours of music.
--   kind "pass":  a permission slip, redeemed from Loot
--   kind "token": a gameplay token
--   kind "crate": a loot crate of a rarity (1 Poor ... 7 Mythic)
------------------------------------------------------------------------------

G.SHOP = {
  { id = "coffee",   kind = "pass",  name = "Coffee Run Pass",    price = 300,  icon = "coffee",
    desc = "Permission to go and get a fancy coffee." },
  { id = "snack",    kind = "pass",  name = "Snack Pass",         price = 450,  icon = "cookie",
    desc = "Permission for a guilt-free snack break." },
  { id = "youtube",  kind = "pass",  name = "Video Break Pass",   price = 600,  icon = "tv",
    desc = "Thirty minutes of guilt-free videos." },
  { id = "lie_in",   kind = "pass",  name = "Lie-In Pass",        price = 1200,  icon = "moon",
    desc = "Permission to sleep in tomorrow. No alarms." },
  { id = "movie",    kind = "pass",  name = "Movie Pass",         price = 1600,  icon = "film",
    desc = "Permission to watch a whole movie." },
  { id = "gaming",   kind = "pass",  name = "Gaming Pass",        price = 1800, icon = "gamepad",
    desc = "Permission for a two hour gaming session." },
  { id = "takeaway", kind = "pass",  name = "Takeaway Pass",      price = 2500, icon = "pizza",
    desc = "Permission to order a takeaway. You earned it." },
  { id = "day_off",  kind = "pass",  name = "Day Off Pass",       price = 6000, icon = "calendar",
    desc = "A whole day off music, with zero guilt." },
  { id = "plugin",   kind = "pass",  name = "New Plugin Pass",    price = 12000, icon = "plug",
    desc = "Permission to buy one new plugin or sample pack." },
  { id = "reroll",   kind = "token", name = "Quest Reroll",       price = 120,  icon = "dice",  token = "reroll",
    desc = "Swap a quest you don't fancy for a new one." },
  { id = "freeze",   kind = "token", name = "Streak Freeze",      price = 300,  icon = "snow",  token = "freeze",
    desc = "Keeps your check-in streak if you miss a day." },
  { id = "boost",    kind = "token", name = "XP Boost",           price = 250,  icon = "bolt",  token = "boost",
    desc = "Double XP for thirty minutes of active time." },
  { id = "crate4",   kind = "crate", name = "Rare Crate",         price = 450,  icon = "crate", rarity = 4,
    desc = "Three items, one Rare or better." },
  { id = "crate5",   kind = "crate", name = "Epic Crate",         price = 1100, icon = "crate", rarity = 5,
    desc = "Three items, one Epic or better." },
}
for _, s in ipairs(G.SHOP) do G.SHOP[s.id] = s end

G.DEAL_PRICE = { [4] = 350, [5] = 800, [6] = 1800, [7] = 4000 }

------------------------------------------------------------------------------
-- Dates. A day starts at G.DAY_START_HOUR, so a session past midnight
-- counts for the day it began.
------------------------------------------------------------------------------

local function shifted(t) return t - G.DAY_START_HOUR * 3600 end

function G.dayKey(t) return os.date("%Y-%m-%d", shifted(t)) end

-- A week is named for its Monday.
function G.weekKey(t)
  local s = shifted(t)
  local since = (os.date("*t", s).wday - 2) % 7
  return os.date("%Y-%m-%d", s - since * 86400)
end

local function keyTime(k)
  local y, m, d = tostring(k):match("(%d+)-(%d+)-(%d+)")
  if not y then return nil end
  return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

function G.daysBetween(a, b)
  local ta, tb = keyTime(a), keyTime(b)
  if not ta or not tb then return math.huge end
  return math.floor((tb - ta) / 86400 + 0.5)
end

function G.secsToNextDay(t)
  local d = os.date("*t", shifted(t))
  local nxt = os.time({ year = d.year, month = d.month, day = d.day + 1, hour = G.DAY_START_HOUR, min = 0, sec = 0 })
  return math.max(0, nxt - t)
end

function G.secsToNextWeek(t)
  local d = os.date("*t", shifted(t))
  local left = 7 - (d.wday - 2) % 7
  local nxt = os.time({ year = d.year, month = d.month, day = d.day + left, hour = G.DAY_START_HOUR, min = 0, sec = 0 })
  return math.max(0, nxt - t)
end

function G.seasonOf(t)
  local d = os.date("*t", shifted(t))
  return G.L.seasonId(d.year, d.month)
end

function G.secsToNextSeason(t)
  local d = os.date("*t", shifted(t))
  local nxt = os.time({ year = d.year, month = d.month + 1, day = 1, hour = G.DAY_START_HOUR, min = 0, sec = 0 })
  return math.max(0, nxt - t)
end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

function G.newState(epoch)
  return {
    version = G.VERSION, created = epoch or 0,
    profile = { name = "Producer", title = 0, banner = 0 },
    coins = 0, level = 1, xp = 0, boost = 0, nextId = 1,
    pass = { season = 0, tier = 0, secs = 0 },
    seasons = {},
    stats = {
      active = 0, longest = 0, sessions = 0, maxDay = 0,
      edits = 0, tracks = 0, items = 0, fx = 0, notes = 0, takes = 0, markers = 0,
      crates = 0, dailies = 0, weeklies = 0, tiers = 0, seasonsDone = 0,
      coinsEarned = 0, coinsSpent = 0, purchases = 0, redeemed = 0,
      ideas = 0, ideasUsed = 0, legendaries = 0, mythics = 0, boosts = 0,
      night = 0, dawn = 0, weekend = 0, xpTotal = 0,
    },
    days = {}, projects = {}, plugins = {},
    daily = { key = "", quests = {}, bonus = false, fickle = false },
    weekly = { key = "", quests = {}, bonus = false },
    checkin = { last = "", streak = 0, best = 0, total = 0 },
    inv = { passes = {}, tokens = { reroll = 1, freeze = 0, boost = 0 }, crates = { 0, 0, 0, 0, 0, 0, 0 } },
    gear = { stash = {}, equipped = {} },
    vault = {},
    cos = { titles = {}, banners = {} },
    ach = {},
    log = {},
    recent = {},
    shop = { day = "", deals = {} },
    settings = { idle = G.IDLE_SECONDS, welcome = false, autostart = false },
  }
end

local function isList(t) return type(t) == "table" and t[1] ~= nil end

local function fill(dst, def)
  for k, v in pairs(def) do
    if dst[k] == nil or type(dst[k]) ~= type(v) then dst[k] = v
    elseif type(v) == "table" and not isList(v) and next(v) ~= nil then fill(dst[k], v) end
  end
end

-- Puts every field back inside what exists: missing ones from a fresh state,
-- the wrong type replaced, numbers made sane.
function G.clampState(st, epoch)
  if type(st) ~= "table" then st = {} end
  fill(st, G.newState(epoch))
  while #st.inv.crates < 7 do st.inv.crates[#st.inv.crates + 1] = 0 end
  st.level = math.max(1, math.floor(tonumber(st.level) or 1))
  st.coins = math.max(0, math.floor(tonumber(st.coins) or 0))
  st.xp = math.max(0, tonumber(st.xp) or 0)
  st.settings.idle = math.max(60, math.min(1800, math.floor(tonumber(st.settings.idle) or G.IDLE_SECONDS)))
  return st
end

------------------------------------------------------------------------------
-- Saving: the state as a Lua table literal, read back with no access to
-- anything (load in an empty environment), so a damaged file cannot run code.
------------------------------------------------------------------------------

local RESERVED = {}
for w in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+") do RESERVED[w] = true end

local function ser(v, out)
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "0"
    elseif math.type(v) == "integer" then out[#out + 1] = tostring(v)
    else out[#out + 1] = string.format("%.10g", v) end
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = tostring(v)
  elseif t == "table" then
    local keys = {}
    for k, val in pairs(v) do
      local tk, tv = type(k), type(val)
      if (tk == "number" or (tk == "string" and k:sub(1, 1) ~= "_"))
         and tv ~= "function" and tv ~= "userdata" and tv ~= "thread" then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    out[#out + 1] = "{"
    for i, k in ipairs(keys) do
      if type(k) == "string" and k:match("^[%a_][%w_]*$") and not RESERVED[k] then out[#out + 1] = k .. "="
      else out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]=" end
      ser(v[k], out)
      if i < #keys then out[#out + 1] = (#keys > 8) and ",\n" or "," end
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = "nil"
  end
end

function G.serialize(st)
  local out = {}
  ser(st, out)
  return table.concat(out)
end

function G.deserialize(s)
  if type(s) ~= "string" or s == "" then return nil end
  local fn = load("return " .. s, "progress", "t", {})
  if not fn then return nil end
  local ok, res = pcall(fn)
  if ok and type(res) == "table" then return res end
  return nil
end

------------------------------------------------------------------------------
-- The session: what lives only while the script runs.
------------------------------------------------------------------------------

function G.newSession(st, tp, epoch)
  st.stats.sessions = st.stats.sessions + 1
  return {
    start = tp, active = 0, idle = false, lastInput = tp, lastWind = -1e9,
    minuteAcc = 0, xpWin = { start = tp, amount = 0 },
    hour = tonumber(os.date("%H", epoch)) or 12, wday = tonumber(os.date("%w", epoch)) or 1,
    notices = {}, project = nil,
    rnd = G.L.random(G.L.seedOf("session", epoch, tp)),
  }
end

local function notice(ss, n) ss.notices[#ss.notices + 1] = n end
G.notice = notice

------------------------------------------------------------------------------
-- Gear bonuses
------------------------------------------------------------------------------

function G.bonus(st, stat)
  local total = 0
  for _, item in pairs(st.gear.equipped) do
    if item.implicit and item.implicit.id == stat then total = total + item.implicit.value end
    for _, a in ipairs(item.affixes or {}) do if a.id == stat then total = total + a.value end end
  end
  return total
end

function G.hasPower(st, id)
  for _, item in pairs(st.gear.equipped) do if item.power == id then return true end end
  return false
end

function G.gearScore(st)
  local s = 0
  for _, item in pairs(st.gear.equipped) do s = s + G.L.gearScore(item) end
  return s
end

function G.idleLimit(st, playing)
  local limit = st.settings.idle + G.bonus(st, "grace")
  if G.hasPower(st, "deep_focus") then limit = limit + 180 end
  if playing then limit = math.max(limit, G.IDLE_PLAYING) end
  return limit
end

------------------------------------------------------------------------------
-- XP, levels, coins
------------------------------------------------------------------------------

function G.levelNeed(level) return 200 + 50 * (level - 1) end

local CAPPED = { edit = true, item = true, notes = true, marker = true, track = true }
local SOURCE_STAT = { notes = "notes", take = "rec", fx = "fx", discover = "fx", track = "tracks", item = "tracks" }

local function levelCrate(rnd, level, luck)
  if level % 50 == 0 then return 7 end
  if level % 25 == 0 then return 6 end
  if level % 10 == 0 then return 5 end
  if level % 5 == 0 then return 4 end
  return G.L.rollRarity(rnd, 2, 3, luck)
end

-- Returns the XP actually given.
function G.addXp(st, ss, base, source)
  if base <= 0 then return 0 end
  if CAPPED[source] then
    local now = ss.now or ss.start
    if now - ss.xpWin.start >= 60 then ss.xpWin.start, ss.xpWin.amount = now, 0 end
    local room = G.ACTION_XP_CAP - ss.xpWin.amount
    if room <= 0 then return 0 end
    base = math.min(base, room)
    ss.xpWin.amount = ss.xpWin.amount + base
  end
  local pct = G.bonus(st, "xp")
  if SOURCE_STAT[source] then pct = pct + G.bonus(st, SOURCE_STAT[source]) end
  if ss.active >= 3600 then pct = pct + G.bonus(st, "endure") end
  if ss.active >= 7200 and G.hasPower(st, "marathon") then pct = pct + 50 end
  if ss.hour < 5 then pct = pct + G.bonus(st, "night") end
  if ss.hour >= 5 and ss.hour < 9 then pct = pct + G.bonus(st, "dawn") end
  local xp = base * (1 + pct / 100)
  if st.boost > 0 then xp = xp * 2 end
  st.xp = st.xp + xp
  st.stats.xpTotal = st.stats.xpTotal + xp
  ss.xpGained = (ss.xpGained or 0) + xp
  while st.xp >= G.levelNeed(st.level) do
    st.xp = st.xp - G.levelNeed(st.level)
    st.level = st.level + 1
    local r = levelCrate(ss.rnd, st.level, G.bonus(st, "luck"))
    st.inv.crates[r] = st.inv.crates[r] + 1
    notice(ss, { kind = "level", level = st.level, crate = r })
  end
  return xp
end

-- Coins found (not refunds or sales) get the coin bonus and Midas Touch.
function G.addCoins(st, ss, n, found)
  n = math.floor(n + 0.5)
  if n <= 0 then return 0 end
  if found then
    n = math.floor(n * (1 + G.bonus(st, "coins") / 100) + 0.5)
    if G.hasPower(st, "midas") and ss.rnd() < 0.10 then
      n = n * 2
      notice(ss, { kind = "toast", text = "Midas Touch!", sub = "Coins doubled", icon = "coin", rarity = 6 })
    end
  end
  st.coins = st.coins + n
  st.stats.coinsEarned = st.stats.coinsEarned + n
  notice(ss, { kind = "coins", amount = n })
  return n
end

------------------------------------------------------------------------------
-- Granting a drop
------------------------------------------------------------------------------

local function newId(st) local id = st.nextId; st.nextId = st.nextId + 1; return id end

local function remember(st, d)
  table.insert(st.recent, 1, { type = d.type, rarity = d.rarity, text = d.text, icon = d.icon, name = d.name })
  while #st.recent > 12 do table.remove(st.recent) end
end

local function stashGear(st, ss, item)
  item.uid = item.uid or newId(st)
  table.insert(st.gear.stash, 1, item)
  if #st.gear.stash > G.STASH_MAX then
    -- Full: sell the weakest thing in it.
    local worst, wi
    for i, it in ipairs(st.gear.stash) do
      local sc = G.L.gearScore(it) + it.rarity * 100
      if not worst or sc < worst then worst, wi = sc, i end
    end
    local sold = table.remove(st.gear.stash, wi)
    local v = G.L.sellValue(sold)
    st.coins = st.coins + v
    notice(ss, { kind = "toast", text = "Stash full", sub = "Sold " .. sold.name .. " for " .. v .. " coins", icon = "coin", rarity = sold.rarity })
  end
end

function G.grant(st, ss, d)
  local L = G.L
  if d.rarity >= L.LEGENDARY and d.type ~= "coins" and d.type ~= "xp" then st.stats.legendaries = st.stats.legendaries + 1 end
  if d.rarity >= L.MYTHIC and d.type ~= "coins" and d.type ~= "xp" then st.stats.mythics = st.stats.mythics + 1 end
  if d.type == "coins" then d.amount = G.addCoins(st, ss, d.amount, true); d.text = d.amount .. " coins"
  elseif d.type == "xp" then G.addXp(st, ss, d.amount, "drop")
  elseif d.type == "token" then st.inv.tokens[d.token] = (st.inv.tokens[d.token] or 0) + d.amount
  elseif d.type == "crate" then st.inv.crates[d.rarity] = st.inv.crates[d.rarity] + 1
  elseif d.type == "gear" then stashGear(st, ss, d)
  elseif d.type == "idea" then
    d.uid = newId(st)
    d.t = ss.epoch or 0
    st.vault[#st.vault + 1] = d
    st.stats.ideas = st.stats.ideas + 1
    if #st.vault > G.VAULT_MAX then
      for i, v in ipairs(st.vault) do
        if not v.fav then table.remove(st.vault, i); break end
      end
    end
  elseif d.type == "title" then st.cos.titles[#st.cos.titles + 1] = { text = d.text, rarity = d.rarity }
  elseif d.type == "banner" then st.cos.banners[#st.cos.banners + 1] = { text = d.text, rarity = d.rarity, data = d.data }
  end
  remember(st, d)
  return d
end

local function grantAll(st, ss, list)
  for _, d in ipairs(list) do G.grant(st, ss, d) end
  return list
end

------------------------------------------------------------------------------
-- Crates
------------------------------------------------------------------------------

function G.openCrate(st, ss, r)
  if (st.inv.crates[r] or 0) <= 0 then return nil end
  st.inv.crates[r] = st.inv.crates[r] - 1
  local extra = 0
  if G.hasPower(st, "hoarder") then extra = extra + 1 end
  if ss.rnd() * 100 < G.bonus(st, "crate") then extra = extra + 1 end
  local drops = G.L.crateContents(ss.rnd, r, G.bonus(st, "luck"), extra,
                                  { ilvl = st.level, collector = G.hasPower(st, "collector") })
  st.stats.crates = st.stats.crates + 1
  -- Announced before it is granted, so the crate opens before any level-up
  -- its contents cause.
  notice(ss, { kind = "crate", rarity = r, drops = drops })
  grantAll(st, ss, drops)
  G.progress(st, ss, "crates", 1)
  return drops
end

------------------------------------------------------------------------------
-- The season pass
------------------------------------------------------------------------------

-- A new month is a new season: the track starts again, and the minutes
-- towards the next tier carry over.
function G.checkSeason(st, ss, epoch)
  local id = G.seasonOf(epoch)
  if st.pass.season == id then return false end
  if st.pass.season ~= 0 then
    st.seasons[tostring(st.pass.season)] = st.pass.tier
    notice(ss, { kind = "season", season = id, name = G.L.seasonName(id) })
  end
  st.pass.season, st.pass.tier = id, 0
  return true
end

function G.unlockTier(st, ss)
  local L = G.L
  st.pass.tier = st.pass.tier + 1
  st.stats.tiers = st.stats.tiers + 1
  local drops, kind = L.tierRewards(st.pass.season, st.pass.tier, st.level, { collector = G.hasPower(st, "collector") })
  if kind ~= "small" and G.hasPower(st, "golden_hour") then
    drops[#drops + 1] = L.makeDrop(ss.rnd, L.rollRarity(ss.rnd, L.RARE, L.MYTHIC, G.bonus(st, "luck")), "crate", { ilvl = st.level })
  end
  notice(ss, { kind = "tier", tier = st.pass.tier, tierKind = kind, drops = drops })
  grantAll(st, ss, drops)
  if st.pass.tier == L.SEASON_TIERS then st.stats.seasonsDone = st.stats.seasonsDone + 1 end
  G.progress(st, ss, "tiers", 1)
  return drops
end

------------------------------------------------------------------------------
-- Time: the idle-aware clock
--
-- signals = { input = something happened, playing, recording, project = name }
------------------------------------------------------------------------------

function G.tick(st, ss, tp, epoch, signals)
  epoch = math.floor(epoch)
  local dt = math.max(0, math.min(1.0, tp - (ss.now or tp)))
  ss.now, ss.epoch = tp, epoch
  ss.hour = tonumber(os.date("%H", epoch)) or ss.hour
  ss.wday = tonumber(os.date("%w", epoch)) or ss.wday
  if signals.input or signals.recording then ss.lastInput = tp end
  local idle = (tp - ss.lastInput) > G.idleLimit(st, signals.playing)
  if idle ~= ss.idle then
    ss.idle = idle
    if idle then notice(ss, { kind = "idle" })
    else
      notice(ss, { kind = "active" })
      if G.hasPower(st, "second_wind") and tp - ss.lastWind >= 1800 then
        ss.lastWind = tp
        G.addXp(st, ss, G.XP.wind, "wind")
        notice(ss, { kind = "toast", text = "Second Wind", sub = "+" .. G.XP.wind .. " XP for coming back", icon = "bolt", rarity = 6 })
      end
    end
  end
  if signals.project and signals.project ~= ss.project then
    ss.project = signals.project
    G.progress(st, ss, "projects", 1, { name = signals.project })
  end
  if idle or dt <= 0 then return end

  local s = st.stats
  ss.active = ss.active + dt
  s.active = s.active + dt
  s.longest = math.max(s.longest, ss.active)
  local day = G.dayKey(epoch)
  st.days[day] = (st.days[day] or 0) + dt
  s.maxDay = math.max(s.maxDay, st.days[day])
  if ss.project then st.projects[ss.project] = (st.projects[ss.project] or 0) + dt end
  if ss.hour < 5 then s.night = s.night + dt elseif ss.hour < 9 then s.dawn = s.dawn + dt end
  if ss.wday == 0 or ss.wday == 6 then s.weekend = s.weekend + dt end
  if st.boost > 0 then st.boost = math.max(0, st.boost - dt) end

  ss.minuteAcc = ss.minuteAcc + dt
  while ss.minuteAcc >= 60 do
    ss.minuteAcc = ss.minuteAcc - 60
    G.addXp(st, ss, G.XP.minute, "time")
  end
  G.progress(st, ss, "minutes", dt)
  G.progress(st, ss, "session", 0)

  st.pass.secs = st.pass.secs + dt * (ss.speed or 1)
  while st.pass.secs >= G.TIER_SECONDS do
    st.pass.secs = st.pass.secs - G.TIER_SECONDS
    G.unlockTier(st, ss)
  end
end

------------------------------------------------------------------------------
-- What you do in REAPER: events from the watcher.
------------------------------------------------------------------------------

-- Plugin names as REAPER gives them - "VST3i: Serum (Xfer Records)" - made
-- into something two lists can be matched on: "serum". Also the display name
-- and whether it is an instrument.
function G.normFx(name)
  name = tostring(name or "")
  local prefix = name:match("^(%u+%d?i?):%s*")
  local instrument = prefix ~= nil and prefix:sub(-1) == "i"
  local display = name:gsub("^%u+%d?i?:%s*", "")
  for _ = 1, 3 do display = display:gsub("%s*%b()%s*$", "") end
  display = display:gsub("^%s+", ""):gsub("%s+$", "")
  return display:lower(), display, instrument
end

G.CATEGORIES = {
  { id = "eq",    name = "an EQ",                 keys = { "eq", "equali", "pro%-q", "pultec" } },
  { id = "comp",  name = "a compressor",          keys = { "comp", "1176", "la%-2a", "la2a", "opto", "glue", "pro%-c", "limit" } },
  { id = "verb",  name = "a reverb",              keys = { "verb", "hall", "plate", "valhalla", "room" } },
  { id = "delay", name = "a delay",               keys = { "delay", "echo", "dly" } },
  { id = "sat",   name = "a saturator or distortion", keys = { "satur", "distort", "drive", "tube", "decapitator", "crush", "fuzz", "tape", "clip" } },
  { id = "mod",   name = "a chorus, flanger or phaser", keys = { "chorus", "flang", "phas", "trem", "vibrato", "ensemble", "rotary" } },
  { id = "inst",  name = "a virtual instrument",  instrument = true },
}
for _, c in ipairs(G.CATEGORIES) do G.CATEGORIES[c.id] = c end

function G.inCategory(info, catId)
  local c = G.CATEGORIES[catId]
  if not c then return false end
  if c.instrument then return info.instrument == true end
  for _, k in ipairs(c.keys) do if info.norm:find(k) then return true end end
  return false
end

-- kind: edit, track, item, fx, notes, take, marker, idea. n: how many.
-- info for fx: { name, norm, instrument }.
function G.event(st, ss, kind, n, info)
  n = n or 1
  local s = st.stats
  if kind == "edit" then
    s.edits = s.edits + n
    G.addXp(st, ss, G.XP.edit * n, "edit")
    G.progress(st, ss, "edits", n)
  elseif kind == "track" then
    s.tracks = s.tracks + n
    G.addXp(st, ss, G.XP.track * n, "track")
    G.progress(st, ss, "tracks", n)
  elseif kind == "item" then
    s.items = s.items + n
    G.addXp(st, ss, G.XP.item * n, "item")
    G.progress(st, ss, "items", n)
  elseif kind == "notes" then
    s.notes = s.notes + n
    G.addXp(st, ss, G.XP.note * n, "notes")
    G.progress(st, ss, "notes", n)
  elseif kind == "take" then
    s.takes = s.takes + n
    G.addXp(st, ss, G.XP.take * n, "take")
    G.progress(st, ss, "takes", n)
  elseif kind == "marker" then
    s.markers = s.markers + n
    G.addXp(st, ss, G.XP.marker * n, "marker")
    G.progress(st, ss, "markers", n)
  elseif kind == "idea" then
    s.ideasUsed = s.ideasUsed + n
    G.addXp(st, ss, G.XP.idea, "idea")
    G.progress(st, ss, "ideas", n)
  elseif kind == "fx" then
    info = info or {}
    if not info.norm then info.norm, info.name, info.instrument = G.normFx(info.name) end
    s.fx = s.fx + 1
    info.first = st.plugins[info.norm] == nil
    st.plugins[info.norm] = (st.plugins[info.norm] or 0) + 1
    G.addXp(st, ss, G.XP.fx, "fx")
    if info.first then
      G.addXp(st, ss, G.XP.discover, "discover")
      notice(ss, { kind = "toast", text = "New plugin discovered", sub = info.name .. "  +" .. G.XP.discover .. " XP", icon = "plug", rarity = 4 })
    end
    G.progress(st, ss, "fx", 1, info)
  end
end

------------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------------

-- daily/weekly: { lowest, highest, step } targets. unit: what one counts in
-- seconds (minutes quests count seconds and show minutes).
G.QUESTS = {
  { kind = "minutes",  text = "Make music for %d minutes", unit = 60, daily = { 20, 60, 5 }, weekly = { 180, 420, 30 } },
  { kind = "session",  text = "Work for %d minutes in one sitting", unit = 60, daily = { 30, 60, 15 }, weekly = { 90, 180, 30 } },
  { kind = "tracks",   text = "Create %d new tracks", daily = { 2, 5, 1 }, weekly = { 10, 25, 5 } },
  { kind = "items",    text = "Create %d new media items", daily = { 5, 15, 5 }, weekly = { 30, 80, 10 } },
  { kind = "fx",       text = "Add %d plugins to tracks", daily = { 3, 8, 1 }, weekly = { 15, 40, 5 } },
  { kind = "plugin",   text = "Use %s", daily = { 1, 2, 1 }, weekly = { 3, 5, 1 }, plugins = true, weight = 3 },
  { kind = "category", text = "Use %s", daily = { 1, 3, 1 }, weekly = { 5, 10, 1 } },
  { kind = "discover", text = "Try %d plugins you've never used before", daily = { 1, 2, 1 }, weekly = { 3, 6, 1 } },
  { kind = "distinct", text = "Use %d different plugins", daily = { 3, 6, 1 }, weekly = { 10, 20, 2 } },
  { kind = "notes",    text = "Write %d MIDI notes", daily = { 50, 200, 25 }, weekly = { 500, 1500, 100 } },
  { kind = "takes",    text = "Record %d takes", daily = { 1, 4, 1 }, weekly = { 5, 15, 5 } },
  { kind = "markers",  text = "Add %d markers or regions", daily = { 2, 6, 1 }, weekly = { 10, 25, 5 } },
  { kind = "edits",    text = "Make %d edits", daily = { 50, 150, 25 }, weekly = { 400, 1000, 100 } },
  { kind = "tiers",    text = "Unlock %d battle pass tiers", daily = { 2, 4, 1 }, weekly = { 12, 24, 4 } },
  { kind = "crates",   text = "Open %d loot crates", daily = { 1, 2, 1 }, weekly = { 4, 8, 1 } },
  { kind = "ideas",    text = "Put %d reward ideas into a project", daily = { 1, 2, 1 }, weekly = { 3, 6, 1 } },
  { kind = "projects", text = "Work on %d different projects", weekly = { 2, 4, 1 } },
  { kind = "dailies",  text = "Complete %d daily quests", weekly = { 8, 15, 1 } },
  { kind = "checkins", text = "Check in on %d days", weekly = { 4, 6, 1 } },
}
for _, q in ipairs(G.QUESTS) do G.QUESTS[q.kind] = q end

local function makeQuest(rnd, tpl, scope, plugins)
  local L = G.L
  local spec = tpl[scope]
  local steps = math.floor((spec[2] - spec[1]) / spec[3])
  local target = spec[1] + math.floor(rnd() * (steps + 1)) * spec[3]
  local diff = steps > 0 and (target - spec[1]) / (spec[2] - spec[1]) or 0.5
  local q = { kind = tpl.kind, target = target * (tpl.unit or 1), progress = 0, done = false, claimed = false,
              scope = scope, seen = {} }
  if tpl.kind == "plugin" then
    local p = L.pickOne(rnd, plugins)
    q.param, q.match = p.display, p.norm
    q.text = (target > 1) and string.format("Use %s on %d tracks", p.display, target) or ("Use " .. p.display .. " on a track")
  elseif tpl.kind == "category" then
    local c = L.pickOne(rnd, G.CATEGORIES)
    q.param = c.id
    q.text = (target > 1) and string.format("Use %s %d times", c.name, target) or ("Use " .. c.name)
  else
    q.text = string.format(tpl.text, target)
  end
  if scope == "daily" then
    q.coins = math.floor(40 + diff * 50 + 0.5)
    q.xp = math.floor(80 + diff * 80 + 0.5)
    q.rarity = (diff > 0.66) and 4 or 3
  else
    q.coins = math.floor(250 + diff * 200 + 0.5)
    q.xp = math.floor(500 + diff * 400 + 0.5)
    q.crate = 4
    q.rarity = (diff > 0.66) and 6 or 5
  end
  return q
end

local function questPool(scope, plugins, exclude)
  local pool = {}
  for _, tpl in ipairs(G.QUESTS) do
    if tpl[scope] and not exclude[tpl.kind] and (not tpl.plugins or #plugins > 0) then
      pool[#pool + 1] = { tpl.weight or 1, tpl }
    end
  end
  return pool
end

function G.makeQuests(rnd, scope, plugins)
  plugins = plugins or {}
  local list, used = {}, {}
  list[1] = makeQuest(rnd, G.QUESTS.minutes, scope, plugins)
  used.minutes = true
  if scope == "weekly" then
    list[2] = makeQuest(rnd, G.QUESTS.dailies, scope, plugins)
    used.dailies = true
  end
  local want = (scope == "daily") and 3 or 4
  while #list < want do
    local pool = questPool(scope, plugins, used)
    if #pool == 0 then break end
    local tpl = G.L.weighted(rnd, pool)
    used[tpl.kind] = true
    list[#list + 1] = makeQuest(rnd, tpl, scope, plugins)
  end
  return list
end

local function claimQuestRewards(st, ss, q, silent)
  q.claimed = true
  local pct = G.bonus(st, "quest")
  local coins = G.addCoins(st, ss, q.coins * (1 + pct / 100), true)
  local xp = q.xp * (1 + pct / 100) * (G.hasPower(st, "scholar") and 1.5 or 1)
  G.addXp(st, ss, xp, "quest")
  if q.crate then st.inv.crates[q.crate] = st.inv.crates[q.crate] + 1 end
  if not silent then notice(ss, { kind = "claim", text = q.text, coins = coins, xp = math.floor(xp), crate = q.crate }) end
end

-- New quests when the day or week turns. Finished but unclaimed quests are
-- claimed for you first: nothing earned is lost to the clock.
function G.refresh(st, ss, epoch, plugins)
  G.checkSeason(st, ss, epoch)
  local day, week = G.dayKey(epoch), G.weekKey(epoch)
  if st.daily.key ~= day then
    for _, q in ipairs(st.daily.quests) do if q.done and not q.claimed then claimQuestRewards(st, ss, q, true) end end
    local rnd = G.L.random(G.L.seedOf("daily", day, epoch))
    local had = st.daily.key ~= ""
    st.daily = { key = day, quests = G.makeQuests(rnd, "daily", plugins), bonus = false, fickle = false }
    if had then notice(ss, { kind = "toast", text = "New daily quests", sub = "Three fresh quests are waiting", icon = "scroll", rarity = 3 }) end
    -- Prune old days from the history.
    for k in pairs(st.days) do if G.daysBetween(k, day) > 120 then st.days[k] = nil end end
  end
  if st.weekly.key ~= week then
    for _, q in ipairs(st.weekly.quests) do if q.done and not q.claimed then claimQuestRewards(st, ss, q, true) end end
    local rnd = G.L.random(G.L.seedOf("weekly", week, epoch))
    local had = st.weekly.key ~= ""
    st.weekly = { key = week, quests = G.makeQuests(rnd, "weekly", plugins), bonus = false }
    if had then notice(ss, { kind = "toast", text = "New weekly quests", sub = "Four big quests for the week", icon = "scroll", rarity = 5 }) end
  end
  if st.shop.day ~= day then G.makeDeals(st, day) end
end

local function questMatches(q, kind, n, info)
  local k = q.kind
  if k == kind then
    if k == "projects" then
      if q.seen[info.name] then return 0 end
      q.seen[info.name] = true
      return 1
    end
    return n
  end
  if kind ~= "fx" then return 0 end
  if k == "plugin" then
    if info.norm == q.match or info.norm:find(q.match, 1, true) then return 1 end
  elseif k == "category" then
    if G.inCategory(info, q.param) then return 1 end
  elseif k == "discover" then
    if info.first then return 1 end
  elseif k == "distinct" then
    if not q.seen[info.norm] then q.seen[info.norm] = true; return 1 end
  end
  return 0
end

-- Moves every quest a thing counts towards.
function G.progress(st, ss, kind, n, info)
  for _, scope in ipairs({ "daily", "weekly" }) do
    for _, q in ipairs(st[scope].quests) do
      if not q.done then
        if q.kind == "session" and kind == "session" then
          q.progress = math.min(q.target, math.max(q.progress, ss.active))
        else
          local add = questMatches(q, kind, n, info or {})
          if add > 0 then q.progress = math.min(q.target, q.progress + add) end
        end
        if q.progress >= q.target then
          q.done = true
          if scope == "daily" then
            st.stats.dailies = st.stats.dailies + 1
          else
            st.stats.weeklies = st.stats.weeklies + 1
          end
          notice(ss, { kind = "quest", text = q.text, scope = scope, rarity = q.rarity })
          if scope == "daily" then G.progress(st, ss, "dailies", 1) end
        end
      end
    end
  end
end

-- Claim a finished quest. Claiming the last of a set opens its bonus crate.
function G.claimQuest(st, ss, scope, i)
  local set = st[scope]
  local q = set.quests[i]
  if not q or not q.done or q.claimed then return false end
  claimQuestRewards(st, ss, q)
  local all = true
  for _, x in ipairs(set.quests) do if not x.claimed then all = false end end
  if all and not set.bonus then
    set.bonus = true
    local r = (scope == "daily") and 3 or 5
    st.inv.crates[r] = st.inv.crates[r] + 1
    notice(ss, { kind = "toast", text = "All " .. scope .. " quests done!", sub = G.L.RARITY[r].name .. " Crate added to Loot", icon = "crate", rarity = r })
  end
  return true
end

function G.canReroll(st, scope)
  if scope == "daily" and G.hasPower(st, "fickle") and not st.daily.fickle then return true end
  return (st.inv.tokens.reroll or 0) > 0
end

function G.reroll(st, ss, scope, i, plugins)
  local set = st[scope]
  local q = set.quests[i]
  if not q or q.done or not G.canReroll(st, scope) then return false end
  if scope == "daily" and G.hasPower(st, "fickle") and not st.daily.fickle then st.daily.fickle = true
  else st.inv.tokens.reroll = st.inv.tokens.reroll - 1 end
  local used = {}
  for _, x in ipairs(set.quests) do used[x.kind] = true end
  local pool = questPool(scope, plugins or {}, used)
  if #pool == 0 then pool = questPool(scope, plugins or {}, { minutes = true, dailies = true }) end
  set.quests[i] = makeQuest(ss.rnd, G.L.weighted(ss.rnd, pool), scope, plugins or {})
  notice(ss, { kind = "toast", text = "Quest rerolled", sub = set.quests[i].text, icon = "dice", rarity = 3 })
  return true
end

------------------------------------------------------------------------------
-- Daily check-in: a seven-day calendar, every fourth week's seventh day a
-- Legendary crate.
------------------------------------------------------------------------------

G.CHECKIN = {
  { coins = 25 },
  { coins = 35, xp = 50 },
  { crate = 3 },
  { coins = 60 },
  { token = "reroll" },
  { coins = 90, xp = 100 },
  { coins = 120, crate = 5 },
}

function G.checkinAvailable(st, epoch) return st.checkin.last ~= G.dayKey(epoch) end

-- The day of the cycle the next check-in lands on, and what the streak
-- would become (for the calendar).
function G.checkinPreview(st, epoch)
  local today = G.dayKey(epoch)
  local c = st.checkin
  if c.last == today then return (c.streak - 1) % 7 + 1, c.streak, 0 end
  local gap = G.daysBetween(c.last, today)
  local streak, freezes = 1, 0
  if c.last ~= "" and gap == 1 then streak = c.streak + 1
  elseif c.last ~= "" and gap > 1 and gap - 1 <= (st.inv.tokens.freeze or 0) then
    streak, freezes = c.streak + 1, gap - 1
  end
  return (streak - 1) % 7 + 1, streak, freezes
end

function G.checkin(st, ss, epoch)
  if not G.checkinAvailable(st, epoch) then return nil end
  local day, streak, freezes = G.checkinPreview(st, epoch)
  local c = st.checkin
  local broke = c.last ~= "" and streak == 1 and c.streak > 0
  if freezes > 0 then st.inv.tokens.freeze = st.inv.tokens.freeze - freezes end
  c.last, c.streak, c.total = G.dayKey(epoch), streak, c.total + 1
  c.best = math.max(c.best, streak)
  local reward = G.CHECKIN[day]
  local pct = G.bonus(st, "checkin")
  local got = { day = day, streak = streak, freezes = freezes, broke = broke }
  if reward.coins then got.coins = G.addCoins(st, ss, reward.coins * (1 + pct / 100), true) end
  if reward.xp then got.xp = G.addXp(st, ss, reward.xp * (1 + pct / 100), "checkin") end
  if reward.token then st.inv.tokens[reward.token] = st.inv.tokens[reward.token] + 1; got.token = reward.token end
  if reward.crate then
    local r = reward.crate
    if day == 7 and streak % 28 == 0 then r = 6 end
    st.inv.crates[r] = st.inv.crates[r] + 1
    got.crate = r
  end
  G.progress(st, ss, "checkins", 1)
  got.kind = "checkin"
  notice(ss, got)
  return got
end

------------------------------------------------------------------------------
-- The shop
------------------------------------------------------------------------------

-- Daily Deals: three items made for the day - gear, cosmetics, an idea -
-- Rare to Legendary, at a price by rarity. Made once a day and kept, so they
-- don't change as you level.
function G.makeDeals(st, day)
  local L = G.L
  local rnd = L.random(L.seedOf("deals", day))
  local deals = {}
  for i = 1, 3 do
    local r = L.rollRarity(rnd, L.RARE, L.LEGENDARY)
    local d = L.makeDrop(rnd, r, "deal", { ilvl = st.level })
    deals[i] = { drop = d, price = math.floor(G.DEAL_PRICE[r] * (d.type == "gear" and 1 or 0.6) + 0.5), bought = false }
  end
  st.shop = { day = day, deals = deals }
end

function G.buy(st, ss, id)
  local item = G.SHOP[id]
  if not item or st.coins < item.price then return false end
  st.coins = st.coins - item.price
  st.stats.coinsSpent = st.stats.coinsSpent + item.price
  st.stats.purchases = st.stats.purchases + 1
  if item.kind == "pass" then st.inv.passes[id] = (st.inv.passes[id] or 0) + 1
  elseif item.kind == "token" then st.inv.tokens[item.token] = (st.inv.tokens[item.token] or 0) + 1
  elseif item.kind == "crate" then st.inv.crates[item.rarity] = st.inv.crates[item.rarity] + 1 end
  notice(ss, { kind = "purchase", name = item.name, icon = item.icon, price = item.price })
  return true
end

function G.buyDeal(st, ss, i)
  local deal = st.shop.deals[i]
  if not deal or deal.bought or st.coins < deal.price then return false end
  st.coins = st.coins - deal.price
  st.stats.coinsSpent = st.stats.coinsSpent + deal.price
  st.stats.purchases = st.stats.purchases + 1
  deal.bought = true
  local d = {}
  for k, v in pairs(deal.drop) do d[k] = v end
  G.grant(st, ss, d)
  notice(ss, { kind = "purchase", name = d.text, icon = d.icon, price = deal.price, rarity = d.rarity })
  return true
end

function G.redeem(st, ss, id, epoch)
  local item = G.SHOP[id]
  if not item or (st.inv.passes[id] or 0) <= 0 then return false end
  st.inv.passes[id] = st.inv.passes[id] - 1
  st.stats.redeemed = st.stats.redeemed + 1
  table.insert(st.log, 1, { id = id, name = item.name, t = epoch or 0 })
  while #st.log > 50 do table.remove(st.log) end
  notice(ss, { kind = "redeem", id = id, name = item.name, icon = item.icon })
  return true
end

function G.useBoost(st, ss)
  if (st.inv.tokens.boost or 0) <= 0 then return false end
  st.inv.tokens.boost = st.inv.tokens.boost - 1
  local secs = G.BOOST_SECONDS * (G.hasPower(st, "overclock") and 2 or 1)
  st.boost = st.boost + secs
  st.stats.boosts = st.stats.boosts + 1
  notice(ss, { kind = "toast", text = "XP Boost active", sub = "Double XP for " .. math.floor(secs / 60) .. " active minutes", icon = "bolt", rarity = 5 })
  return true
end

------------------------------------------------------------------------------
-- Gear
------------------------------------------------------------------------------

local function findStash(st, uid)
  for i, it in ipairs(st.gear.stash) do if it.uid == uid then return i, it end end
end

function G.equip(st, ss, uid)
  local i, item = findStash(st, uid)
  if not item then return false end
  table.remove(st.gear.stash, i)
  local old = st.gear.equipped[item.slot]
  st.gear.equipped[item.slot] = item
  if old then table.insert(st.gear.stash, 1, old) end
  notice(ss, { kind = "equip", name = item.name, rarity = item.rarity })
  return true
end

function G.unequip(st, ss, slot)
  local item = st.gear.equipped[slot]
  if not item or #st.gear.stash >= G.STASH_MAX then return false end
  st.gear.equipped[slot] = nil
  table.insert(st.gear.stash, 1, item)
  return true
end

function G.salvage(st, ss, uid)
  local i, item = findStash(st, uid)
  if not item then return 0 end
  table.remove(st.gear.stash, i)
  local v = G.L.sellValue(item)
  st.coins = st.coins + v
  notice(ss, { kind = "coins", amount = v })
  return v
end

-- Sells everything in the stash at or under a rarity.
function G.salvageUpTo(st, ss, maxRarity)
  local total, n = 0, 0
  for i = #st.gear.stash, 1, -1 do
    local it = st.gear.stash[i]
    if it.rarity <= maxRarity then
      table.remove(st.gear.stash, i)
      total = total + G.L.sellValue(it)
      n = n + 1
    end
  end
  st.coins = st.coins + total
  if n > 0 then notice(ss, { kind = "coins", amount = total }) end
  return n, total
end

------------------------------------------------------------------------------
-- The vault of ideas
------------------------------------------------------------------------------

function G.findIdea(st, uid)
  for i, v in ipairs(st.vault) do if v.uid == uid then return i, v end end
end

function G.removeIdea(st, uid)
  local i = G.findIdea(st, uid)
  if i then table.remove(st.vault, i); return true end
  return false
end

function G.ideaUsed(st, ss, uid)
  local _, v = G.findIdea(st, uid)
  if v and not v.used then
    v.used = true
    G.event(st, ss, "idea", 1)
  end
end

------------------------------------------------------------------------------
-- Achievements: series of tiers. The last tier of a series also gives its
-- title to wear.
------------------------------------------------------------------------------

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

G.ACHIEVEMENTS = {
  { id = "hours", name = "Time in the Studio", fmt = "Make music for %s hours", title = "Studio Legend",
    value = function(st) return st.stats.active / 3600 end, goals = { 1, 5, 10, 25, 50, 100, 250, 500, 1000 } },
  { id = "session", name = "In the Zone", fmt = "Work for %s hours in one session", title = "The Unbreakable",
    value = function(st) return st.stats.longest / 3600 end, goals = { 1, 2, 3, 4, 6 } },
  { id = "day", name = "Full Shift", fmt = "Make music for %s hours in one day", title = "Overtime Hero",
    value = function(st) return st.stats.maxDay / 3600 end, goals = { 2, 4, 6, 8 } },
  { id = "level", name = "Level Up", fmt = "Reach level %s", title = "The Ascended",
    value = function(st) return st.level end, goals = { 5, 10, 20, 30, 50, 75, 100 } },
  { id = "tiers", name = "Battle Pass", fmt = "Unlock %s battle pass tiers", title = "Tier Crusher",
    value = function(st) return st.stats.tiers end, goals = { 1, 10, 50, 100, 250, 500, 1000 } },
  { id = "seasons", name = "Season Champion", fmt = "Finish %s season passes", title = "Champion of Seasons",
    value = function(st) return st.stats.seasonsDone end, goals = { 1, 3, 6, 12 } },
  { id = "streak", name = "On a Roll", fmt = "A check-in streak of %s days", title = "The Devoted",
    value = function(st) return st.checkin.best end, goals = { 3, 7, 14, 30, 60, 100, 365 } },
  { id = "loyal", name = "Regular", fmt = "Check in on %s days in total", title = "Part of the Furniture",
    value = function(st) return st.checkin.total end, goals = { 7, 30, 100, 365, 1000 } },
  { id = "tracks", name = "Track Builder", fmt = "Create %s tracks", title = "Architect of Tracks",
    value = function(st) return st.stats.tracks end, goals = { 10, 50, 250, 1000, 5000 } },
  { id = "items", name = "Item Maker", fmt = "Create %s media items", title = "Clip Collector",
    value = function(st) return st.stats.items end, goals = { 50, 250, 1000, 5000, 20000 } },
  { id = "notes", name = "Note Writer", fmt = "Write %s MIDI notes", title = "The Composer",
    value = function(st) return st.stats.notes end, goals = { 100, 1000, 10000, 50000, 250000 } },
  { id = "takes", name = "Tape Rolling", fmt = "Record %s takes", title = "One More Take",
    value = function(st) return st.stats.takes end, goals = { 1, 25, 100, 500 } },
  { id = "fx", name = "Plugin Stacker", fmt = "Add %s plugins to tracks", title = "Rack Master",
    value = function(st) return st.stats.fx end, goals = { 10, 100, 500, 2500 } },
  { id = "plugins", name = "Plugin Explorer", fmt = "Use %s different plugins", title = "Plugin Connoisseur",
    value = function(st) return count(st.plugins) end, goals = { 5, 15, 40, 100, 250 } },
  { id = "quests", name = "Quest Giver's Favourite", fmt = "Complete %s quests", title = "The Questor",
    value = function(st) return st.stats.dailies + st.stats.weeklies end, goals = { 1, 10, 50, 200, 1000 } },
  { id = "crates", name = "Crate Cracker", fmt = "Open %s loot crates", title = "Crate Goblin",
    value = function(st) return st.stats.crates end, goals = { 1, 10, 50, 250, 1000 } },
  { id = "coins", name = "Coin Hoarder", fmt = "Earn %s coins", title = "The Tycoon",
    value = function(st) return st.stats.coinsEarned end, goals = { 1000, 10000, 50000, 250000, 1000000 } },
  { id = "treats", name = "Treat Yourself", fmt = "Redeem %s passes", title = "Professional Relaxer",
    value = function(st) return st.stats.redeemed end, goals = { 1, 10, 50, 100 } },
  { id = "ideas", name = "Idea Collector", fmt = "Collect %s ideas", title = "Keeper of Ideas",
    value = function(st) return st.stats.ideas end, goals = { 10, 100, 500, 2000 } },
  { id = "used", name = "Ideas Into Music", fmt = "Put %s reward ideas into projects", title = "The Finisher",
    value = function(st) return st.stats.ideasUsed end, goals = { 1, 10, 50, 200 } },
  { id = "legend", name = "Legendary Luck", fmt = "Find %s Legendary or better items", title = "Touched by Fortune",
    value = function(st) return st.stats.legendaries end, goals = { 1, 10, 50, 200 } },
  { id = "mythic", name = "Myth Maker", fmt = "Find %s Mythic items", title = "The Mythic",
    value = function(st) return st.stats.mythics end, goals = { 1, 5, 25 } },
  { id = "gear", name = "Fully Kitted", fmt = "Reach a gear score of %s", title = "Gear Lord",
    value = function(st) return G.gearScore(st) end, goals = { 50, 150, 300, 500, 800 } },
  { id = "night", name = "Night Owl", fmt = "Make music for %s hours between midnight and 5am", title = "Creature of the Night",
    value = function(st) return st.stats.night / 3600 end, goals = { 1, 10, 50 } },
  { id = "dawn", name = "Early Bird", fmt = "Make music for %s hours between 5am and 9am", title = "Dawn Patrol",
    value = function(st) return st.stats.dawn / 3600 end, goals = { 1, 10, 50 } },
  { id = "weekend", name = "Weekend Warrior", fmt = "Make music for %s hours at weekends", title = "Weekend Warrior",
    value = function(st) return st.stats.weekend / 3600 end, goals = { 5, 25, 100 } },
  { id = "projects", name = "Project Hopper", fmt = "Work on %s different projects", title = "Many Hats",
    value = function(st) return count(st.projects) end, goals = { 3, 10, 50, 200 } },
  { id = "shopper", name = "Big Spender", fmt = "Spend %s coins", title = "Patron of the Shop",
    value = function(st) return st.stats.coinsSpent end, goals = { 500, 5000, 25000, 100000 } },
}
for _, a in ipairs(G.ACHIEVEMENTS) do G.ACHIEVEMENTS[a.id] = a end

function G.achievementTotals(st)
  local have, all = 0, 0
  for _, a in ipairs(G.ACHIEVEMENTS) do
    all = all + #a.goals
    have = have + (st.ach[a.id] or 0)
  end
  return have, all
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function G.roman(n) return ROMAN[n] or tostring(n) end

local function fmtGoal(g)
  if g >= 1000 and g % 1000 == 0 then return math.floor(g / 1000) .. ",000" end
  return tostring(g)
end
G.fmtGoal = fmtGoal

function G.checkAchievements(st, ss)
  for _, a in ipairs(G.ACHIEVEMENTS) do
    local have = st.ach[a.id] or 0
    local v = a.value(st)
    while have < #a.goals and v >= a.goals[have + 1] do
      have = have + 1
      st.ach[a.id] = have
      local coins = 40 * have
      local xp = 80 * have
      G.addCoins(st, ss, coins, false)
      G.addXp(st, ss, xp, "ach")
      local final = have == #a.goals
      if final then st.cos.titles[#st.cos.titles + 1] = { text = a.title, rarity = 6 } end
      notice(ss, { kind = "ach", name = a.name .. " " .. G.roman(have),
                   text = string.format(a.fmt, fmtGoal(a.goals[have])), coins = coins, xp = xp,
                   tier = have, final = final, title = final and a.title or nil })
    end
  end
end

------------------------------------------------------------------------------
-- For the window
------------------------------------------------------------------------------

function G.weekSeconds(st, epoch)
  local monday = G.weekKey(epoch)
  local total = 0
  for k, v in pairs(st.days) do
    local d = G.daysBetween(monday, k)
    if d >= 0 and d < 7 then total = total + v end
  end
  return total
end

function G.activeTitle(st)
  local t = st.cos.titles[st.profile.title]
  return t and t.text or ""
end

function G.activeBanner(st)
  return st.cos.banners[st.profile.banner]
end

function G.init(L)
  G.L = L
  return G
end

return G
