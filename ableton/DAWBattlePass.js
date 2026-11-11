/* DAW Battle Pass - built by ableton/kit/build.py from ableton/device.json. Do not edit; edit the sources and rebuild. */
var DEVICE = {"title": "DAW Battle Pass"};
DEVICE.files = {"battle-pass/bp_game.lua": "--[[ DAW Battle Pass - the rules of the game.\n\n     Pure Lua. Nothing in this file touches REAPER or ImGui. Every function\n     takes the saved state (`st`), the session (`ss`, what lives only while\n     the script runs) and the time it is, and changes them; what the window\n     should celebrate is pushed onto `ss.notices` for it to animate.\n\n     The time is always passed in, twice over:\n       - `tp`, REAPER's time_precise(), a clock in seconds for idle and dt;\n       - `epoch`, os.time(), for days, weeks and seasons.\n     So the tests can run a week in a second.\n\n     The shape of it:\n\n       - Active time fills the SEASON PASS: a tier every fifteen active\n         minutes, every fourth (each hour) a big one. A season is a calendar\n         month with a 100-tier track, then endless bonus tiers.\n       - Everything you do earns XP, which fills the LEVEL bar; every level\n         gives a loot crate.\n       - Daily CHECK-IN on a seven-day calendar, a streak, Streak Freezes.\n       - Three DAILY and four WEEKLY QUESTS, some naming your own plugins.\n       - COINS buy passes (permission slips: a takeaway, a movie...),\n         tokens and crates in the SHOP, and a rotating set of Daily Deals.\n       - GEAR in the manner of Diablo: six slots, affixes that boost XP,\n         coins, loot and more, Legendary powers. Salvage what you don't want.\n       - ACHIEVEMENTS in series, each with tiers.\n\n     Loaded with dofile(...).init(L), handed the loot.\n]]\n\nlocal G = {}\n\nG.VERSION = 1\nG.TIER_SECONDS = 15 * 60         -- active time per pass tier\nG.IDLE_SECONDS = 180             -- no activity for this long and you are idle\nG.IDLE_PLAYING = 480             -- ...unless the project is playing back\nG.DAY_START_HOUR = 4             -- a day (quests, check-in) starts at 4am\nG.ACTION_XP_CAP = 120            -- base XP a minute from editing actions\nG.STASH_MAX = 60\nG.VAULT_MAX = 400\nG.BOOST_SECONDS = 30 * 60\n\n-- Base XP for each thing you do, before gear and boosts.\nG.XP = { minute = 4, edit = 1, track = 10, item = 3, fx = 6, discover = 20,\n         note = 0.5, take = 15, marker = 3, idea = 25, wind = 30 }\n\n------------------------------------------------------------------------------\n-- The coin shop. Prices in coins; edit freely. A focused hour earns very\n-- roughly 400-600 coins, all told, so a takeaway is about five hours of music.\n--   kind \"pass\":  a permission slip, redeemed from Loot\n--   kind \"token\": a gameplay token\n--   kind \"crate\": a loot crate of a rarity (1 Poor ... 7 Mythic)\n------------------------------------------------------------------------------\n\nG.SHOP = {\n  { id = \"coffee\",   kind = \"pass\",  name = \"Coffee Run Pass\",    price = 300,  icon = \"coffee\",\n    desc = \"Permission to go and get a fancy coffee.\" },\n  { id = \"snack\",    kind = \"pass\",  name = \"Snack Pass\",         price = 450,  icon = \"cookie\",\n    desc = \"Permission for a guilt-free snack break.\" },\n  { id = \"youtube\",  kind = \"pass\",  name = \"Video Break Pass\",   price = 600,  icon = \"tv\",\n    desc = \"Thirty minutes of guilt-free videos.\" },\n  { id = \"lie_in\",   kind = \"pass\",  name = \"Lie-In Pass\",        price = 1200,  icon = \"moon\",\n    desc = \"Permission to sleep in tomorrow. No alarms.\" },\n  { id = \"movie\",    kind = \"pass\",  name = \"Movie Pass\",         price = 1600,  icon = \"film\",\n    desc = \"Permission to watch a whole movie.\" },\n  { id = \"gaming\",   kind = \"pass\",  name = \"Gaming Pass\",        price = 1800, icon = \"gamepad\",\n    desc = \"Permission for a two hour gaming session.\" },\n  { id = \"takeaway\", kind = \"pass\",  name = \"Takeaway Pass\",      price = 2500, icon = \"pizza\",\n    desc = \"Permission to order a takeaway. You earned it.\" },\n  { id = \"day_off\",  kind = \"pass\",  name = \"Day Off Pass\",       price = 6000, icon = \"calendar\",\n    desc = \"A whole day off music, with zero guilt.\" },\n  { id = \"plugin\",   kind = \"pass\",  name = \"New Plugin Pass\",    price = 12000, icon = \"plug\",\n    desc = \"Permission to buy one new plugin or sample pack.\" },\n  { id = \"reroll\",   kind = \"token\", name = \"Quest Reroll\",       price = 120,  icon = \"dice\",  token = \"reroll\",\n    desc = \"Swap a quest you don't fancy for a new one.\" },\n  { id = \"freeze\",   kind = \"token\", name = \"Streak Freeze\",      price = 300,  icon = \"snow\",  token = \"freeze\",\n    desc = \"Keeps your check-in streak if you miss a day.\" },\n  { id = \"boost\",    kind = \"token\", name = \"XP Boost\",           price = 250,  icon = \"bolt\",  token = \"boost\",\n    desc = \"Double XP for thirty minutes of active time.\" },\n  { id = \"crate4\",   kind = \"crate\", name = \"Rare Crate\",         price = 450,  icon = \"crate\", rarity = 4,\n    desc = \"Three items, one Rare or better.\" },\n  { id = \"crate5\",   kind = \"crate\", name = \"Epic Crate\",         price = 1100, icon = \"crate\", rarity = 5,\n    desc = \"Three items, one Epic or better.\" },\n}\nfor _, s in ipairs(G.SHOP) do G.SHOP[s.id] = s end\n\nG.DEAL_PRICE = { [4] = 350, [5] = 800, [6] = 1800, [7] = 4000 }\n\n------------------------------------------------------------------------------\n-- Dates. A day starts at G.DAY_START_HOUR, so a session past midnight\n-- counts for the day it began.\n------------------------------------------------------------------------------\n\nlocal function shifted(t) return t - G.DAY_START_HOUR * 3600 end\n\nfunction G.dayKey(t) return os.date(\"%Y-%m-%d\", shifted(t)) end\n\n-- A week is named for its Monday.\nfunction G.weekKey(t)\n  local s = shifted(t)\n  local since = (os.date(\"*t\", s).wday - 2) % 7\n  return os.date(\"%Y-%m-%d\", s - since * 86400)\nend\n\nlocal function keyTime(k)\n  local y, m, d = tostring(k):match(\"(%d+)-(%d+)-(%d+)\")\n  if not y then return nil end\n  return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })\nend\n\nfunction G.daysBetween(a, b)\n  local ta, tb = keyTime(a), keyTime(b)\n  if not ta or not tb then return math.huge end\n  return math.floor((tb - ta) / 86400 + 0.5)\nend\n\nfunction G.secsToNextDay(t)\n  local d = os.date(\"*t\", shifted(t))\n  local nxt = os.time({ year = d.year, month = d.month, day = d.day + 1, hour = G.DAY_START_HOUR, min = 0, sec = 0 })\n  return math.max(0, nxt - t)\nend\n\nfunction G.secsToNextWeek(t)\n  local d = os.date(\"*t\", shifted(t))\n  local left = 7 - (d.wday - 2) % 7\n  local nxt = os.time({ year = d.year, month = d.month, day = d.day + left, hour = G.DAY_START_HOUR, min = 0, sec = 0 })\n  return math.max(0, nxt - t)\nend\n\nfunction G.seasonOf(t)\n  local d = os.date(\"*t\", shifted(t))\n  return G.L.seasonId(d.year, d.month)\nend\n\nfunction G.secsToNextSeason(t)\n  local d = os.date(\"*t\", shifted(t))\n  local nxt = os.time({ year = d.year, month = d.month + 1, day = 1, hour = G.DAY_START_HOUR, min = 0, sec = 0 })\n  return math.max(0, nxt - t)\nend\n\n------------------------------------------------------------------------------\n-- State\n------------------------------------------------------------------------------\n\nfunction G.newState(epoch)\n  return {\n    version = G.VERSION, created = epoch or 0,\n    profile = { name = \"Producer\", title = 0, banner = 0 },\n    coins = 0, level = 1, xp = 0, boost = 0, nextId = 1,\n    pass = { season = 0, tier = 0, secs = 0 },\n    seasons = {},\n    stats = {\n      active = 0, longest = 0, sessions = 0, maxDay = 0,\n      edits = 0, tracks = 0, items = 0, fx = 0, notes = 0, takes = 0, markers = 0,\n      crates = 0, dailies = 0, weeklies = 0, tiers = 0, seasonsDone = 0,\n      coinsEarned = 0, coinsSpent = 0, purchases = 0, redeemed = 0,\n      ideas = 0, ideasUsed = 0, legendaries = 0, mythics = 0, boosts = 0,\n      night = 0, dawn = 0, weekend = 0, xpTotal = 0,\n    },\n    days = {}, projects = {}, plugins = {},\n    daily = { key = \"\", quests = {}, bonus = false, fickle = false },\n    weekly = { key = \"\", quests = {}, bonus = false },\n    checkin = { last = \"\", streak = 0, best = 0, total = 0 },\n    inv = { passes = {}, tokens = { reroll = 1, freeze = 0, boost = 0 }, crates = { 0, 0, 0, 0, 0, 0, 0 } },\n    gear = { stash = {}, equipped = {} },\n    vault = {},\n    cos = { titles = {}, banners = {} },\n    ach = {},\n    log = {},\n    recent = {},\n    shop = { day = \"\", deals = {} },\n    -- reduceMotion: Apple's Reduce Motion, chosen here because a script\n    -- cannot read the system's (decision 0018).\n    settings = { idle = G.IDLE_SECONDS, welcome = false, autostart = false, reduceMotion = false,\n                 textSize = 1 },   -- 1-4: 100, 125, 150, 200% (the window clamps it)\n  }\nend\n\nlocal function isList(t) return type(t) == \"table\" and t[1] ~= nil end\n\nlocal function fill(dst, def)\n  for k, v in pairs(def) do\n    if dst[k] == nil or type(dst[k]) ~= type(v) then dst[k] = v\n    elseif type(v) == \"table\" and not isList(v) and next(v) ~= nil then fill(dst[k], v) end\n  end\nend\n\n-- Puts every field back inside what exists: missing ones from a fresh state,\n-- the wrong type replaced, numbers made sane.\nfunction G.clampState(st, epoch)\n  if type(st) ~= \"table\" then st = {} end\n  fill(st, G.newState(epoch))\n  while #st.inv.crates < 7 do st.inv.crates[#st.inv.crates + 1] = 0 end\n  st.level = math.max(1, math.floor(tonumber(st.level) or 1))\n  st.coins = math.max(0, math.floor(tonumber(st.coins) or 0))\n  st.xp = math.max(0, tonumber(st.xp) or 0)\n  st.settings.idle = math.max(60, math.min(1800, math.floor(tonumber(st.settings.idle) or G.IDLE_SECONDS)))\n  return st\nend\n\n------------------------------------------------------------------------------\n-- Saving: the state as a Lua table literal, read back with no access to\n-- anything (load in an empty environment), so a damaged file cannot run code.\n------------------------------------------------------------------------------\n\nlocal RESERVED = {}\nfor w in (\"and break do else elseif end false for function goto if in local nil not or repeat return then true until while\"):gmatch(\"%a+\") do RESERVED[w] = true end\n\nlocal function ser(v, out)\n  local t = type(v)\n  if t == \"number\" then\n    if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = \"0\"\n    elseif math.type(v) == \"integer\" then out[#out + 1] = tostring(v)\n    else out[#out + 1] = string.format(\"%.10g\", v) end\n  elseif t == \"string\" then out[#out + 1] = string.format(\"%q\", v)\n  elseif t == \"boolean\" then out[#out + 1] = tostring(v)\n  elseif t == \"table\" then\n    local keys = {}\n    for k, val in pairs(v) do\n      local tk, tv = type(k), type(val)\n      if (tk == \"number\" or (tk == \"string\" and k:sub(1, 1) ~= \"_\"))\n         and tv ~= \"function\" and tv ~= \"userdata\" and tv ~= \"thread\" then keys[#keys + 1] = k end\n    end\n    table.sort(keys, function(a, b)\n      local ta, tb = type(a), type(b)\n      if ta ~= tb then return ta < tb end\n      return a < b\n    end)\n    out[#out + 1] = \"{\"\n    for i, k in ipairs(keys) do\n      if type(k) == \"string\" and k:match(\"^[%a_][%w_]*$\") and not RESERVED[k] then out[#out + 1] = k .. \"=\"\n      else out[#out + 1] = \"[\"; ser(k, out); out[#out + 1] = \"]=\" end\n      ser(v[k], out)\n      if i < #keys then out[#out + 1] = (#keys > 8) and \",\\n\" or \",\" end\n    end\n    out[#out + 1] = \"}\"\n  else\n    out[#out + 1] = \"nil\"\n  end\nend\n\nfunction G.serialize(st)\n  local out = {}\n  ser(st, out)\n  return table.concat(out)\nend\n\nfunction G.deserialize(s)\n  if type(s) ~= \"string\" or s == \"\" then return nil end\n  local fn = load(\"return \" .. s, \"progress\", \"t\", {})\n  if not fn then return nil end\n  local ok, res = pcall(fn)\n  if ok and type(res) == \"table\" then return res end\n  return nil\nend\n\n------------------------------------------------------------------------------\n-- The session: what lives only while the script runs.\n------------------------------------------------------------------------------\n\nfunction G.newSession(st, tp, epoch)\n  st.stats.sessions = st.stats.sessions + 1\n  return {\n    start = tp, active = 0, idle = false, lastInput = tp, lastWind = -1e9,\n    minuteAcc = 0, xpWin = { start = tp, amount = 0 },\n    hour = tonumber(os.date(\"%H\", epoch)) or 12, wday = tonumber(os.date(\"%w\", epoch)) or 1,\n    notices = {}, project = nil,\n    rnd = G.L.random(G.L.seedOf(\"session\", epoch, tp)),\n  }\nend\n\nlocal function notice(ss, n) ss.notices[#ss.notices + 1] = n end\nG.notice = notice\n\n------------------------------------------------------------------------------\n-- Gear bonuses\n------------------------------------------------------------------------------\n\nfunction G.bonus(st, stat)\n  local total = 0\n  for _, item in pairs(st.gear.equipped) do\n    if item.implicit and item.implicit.id == stat then total = total + item.implicit.value end\n    for _, a in ipairs(item.affixes or {}) do if a.id == stat then total = total + a.value end end\n  end\n  return total\nend\n\nfunction G.hasPower(st, id)\n  for _, item in pairs(st.gear.equipped) do if item.power == id then return true end end\n  return false\nend\n\nfunction G.gearScore(st)\n  local s = 0\n  for _, item in pairs(st.gear.equipped) do s = s + G.L.gearScore(item) end\n  return s\nend\n\nfunction G.idleLimit(st, playing)\n  local limit = st.settings.idle + G.bonus(st, \"grace\")\n  if G.hasPower(st, \"deep_focus\") then limit = limit + 180 end\n  if playing then limit = math.max(limit, G.IDLE_PLAYING) end\n  return limit\nend\n\n------------------------------------------------------------------------------\n-- XP, levels, coins\n------------------------------------------------------------------------------\n\nfunction G.levelNeed(level) return 200 + 50 * (level - 1) end\n\nlocal CAPPED = { edit = true, item = true, notes = true, marker = true, track = true }\nlocal SOURCE_STAT = { notes = \"notes\", take = \"rec\", fx = \"fx\", discover = \"fx\", track = \"tracks\", item = \"tracks\" }\n\nlocal function levelCrate(rnd, level, luck)\n  if level % 50 == 0 then return 7 end\n  if level % 25 == 0 then return 6 end\n  if level % 10 == 0 then return 5 end\n  if level % 5 == 0 then return 4 end\n  return G.L.rollRarity(rnd, 2, 3, luck)\nend\n\n-- Returns the XP actually given.\nfunction G.addXp(st, ss, base, source)\n  if base <= 0 then return 0 end\n  if CAPPED[source] then\n    local now = ss.now or ss.start\n    if now - ss.xpWin.start >= 60 then ss.xpWin.start, ss.xpWin.amount = now, 0 end\n    local room = G.ACTION_XP_CAP - ss.xpWin.amount\n    if room <= 0 then return 0 end\n    base = math.min(base, room)\n    ss.xpWin.amount = ss.xpWin.amount + base\n  end\n  local pct = G.bonus(st, \"xp\")\n  if SOURCE_STAT[source] then pct = pct + G.bonus(st, SOURCE_STAT[source]) end\n  if ss.active >= 3600 then pct = pct + G.bonus(st, \"endure\") end\n  if ss.active >= 7200 and G.hasPower(st, \"marathon\") then pct = pct + 50 end\n  if ss.hour < 5 then pct = pct + G.bonus(st, \"night\") end\n  if ss.hour >= 5 and ss.hour < 9 then pct = pct + G.bonus(st, \"dawn\") end\n  local xp = base * (1 + pct / 100)\n  if st.boost > 0 then xp = xp * 2 end\n  st.xp = st.xp + xp\n  st.stats.xpTotal = st.stats.xpTotal + xp\n  ss.xpGained = (ss.xpGained or 0) + xp\n  while st.xp >= G.levelNeed(st.level) do\n    st.xp = st.xp - G.levelNeed(st.level)\n    st.level = st.level + 1\n    local r = levelCrate(ss.rnd, st.level, G.bonus(st, \"luck\"))\n    st.inv.crates[r] = st.inv.crates[r] + 1\n    notice(ss, { kind = \"level\", level = st.level, crate = r })\n  end\n  return xp\nend\n\n-- Coins found (not refunds or sales) get the coin bonus and Midas Touch.\nfunction G.addCoins(st, ss, n, found)\n  n = math.floor(n + 0.5)\n  if n <= 0 then return 0 end\n  if found then\n    n = math.floor(n * (1 + G.bonus(st, \"coins\") / 100) + 0.5)\n    if G.hasPower(st, \"midas\") and ss.rnd() < 0.10 then\n      n = n * 2\n      notice(ss, { kind = \"toast\", text = \"Midas Touch!\", sub = \"Coins doubled\", icon = \"coin\", rarity = 6 })\n    end\n  end\n  st.coins = st.coins + n\n  st.stats.coinsEarned = st.stats.coinsEarned + n\n  notice(ss, { kind = \"coins\", amount = n })\n  return n\nend\n\n------------------------------------------------------------------------------\n-- Granting a drop\n------------------------------------------------------------------------------\n\nlocal function newId(st) local id = st.nextId; st.nextId = st.nextId + 1; return id end\n\nlocal function remember(st, d)\n  table.insert(st.recent, 1, { type = d.type, rarity = d.rarity, text = d.text, icon = d.icon, name = d.name })\n  while #st.recent > 12 do table.remove(st.recent) end\nend\n\nlocal function stashGear(st, ss, item)\n  item.uid = item.uid or newId(st)\n  table.insert(st.gear.stash, 1, item)\n  if #st.gear.stash > G.STASH_MAX then\n    -- Full: sell the weakest thing in it.\n    local worst, wi\n    for i, it in ipairs(st.gear.stash) do\n      local sc = G.L.gearScore(it) + it.rarity * 100\n      if not worst or sc < worst then worst, wi = sc, i end\n    end\n    local sold = table.remove(st.gear.stash, wi)\n    local v = G.L.sellValue(sold)\n    st.coins = st.coins + v\n    notice(ss, { kind = \"toast\", text = \"Stash full\", sub = \"Sold \" .. sold.name .. \" for \" .. v .. \" coins\", icon = \"coin\", rarity = sold.rarity })\n  end\nend\n\nfunction G.grant(st, ss, d)\n  local L = G.L\n  if d.rarity >= L.LEGENDARY and d.type ~= \"coins\" and d.type ~= \"xp\" then st.stats.legendaries = st.stats.legendaries + 1 end\n  if d.rarity >= L.MYTHIC and d.type ~= \"coins\" and d.type ~= \"xp\" then st.stats.mythics = st.stats.mythics + 1 end\n  if d.type == \"coins\" then d.amount = G.addCoins(st, ss, d.amount, true); d.text = d.amount .. \" coins\"\n  elseif d.type == \"xp\" then G.addXp(st, ss, d.amount, \"drop\")\n  elseif d.type == \"token\" then st.inv.tokens[d.token] = (st.inv.tokens[d.token] or 0) + d.amount\n  elseif d.type == \"crate\" then st.inv.crates[d.rarity] = st.inv.crates[d.rarity] + 1\n  elseif d.type == \"gear\" then stashGear(st, ss, d)\n  elseif d.type == \"idea\" then\n    d.uid = newId(st)\n    d.t = ss.epoch or 0\n    st.vault[#st.vault + 1] = d\n    st.stats.ideas = st.stats.ideas + 1\n    if #st.vault > G.VAULT_MAX then\n      for i, v in ipairs(st.vault) do\n        if not v.fav then table.remove(st.vault, i); break end\n      end\n    end\n  elseif d.type == \"title\" then st.cos.titles[#st.cos.titles + 1] = { text = d.text, rarity = d.rarity }\n  elseif d.type == \"banner\" then st.cos.banners[#st.cos.banners + 1] = { text = d.text, rarity = d.rarity, data = d.data }\n  end\n  remember(st, d)\n  return d\nend\n\nlocal function grantAll(st, ss, list)\n  for _, d in ipairs(list) do G.grant(st, ss, d) end\n  return list\nend\n\n------------------------------------------------------------------------------\n-- Crates\n------------------------------------------------------------------------------\n\nfunction G.openCrate(st, ss, r)\n  if (st.inv.crates[r] or 0) <= 0 then return nil end\n  st.inv.crates[r] = st.inv.crates[r] - 1\n  local extra = 0\n  if G.hasPower(st, \"hoarder\") then extra = extra + 1 end\n  if ss.rnd() * 100 < G.bonus(st, \"crate\") then extra = extra + 1 end\n  local drops = G.L.crateContents(ss.rnd, r, G.bonus(st, \"luck\"), extra,\n                                  { ilvl = st.level, collector = G.hasPower(st, \"collector\") })\n  st.stats.crates = st.stats.crates + 1\n  -- Announced before it is granted, so the crate opens before any level-up\n  -- its contents cause.\n  notice(ss, { kind = \"crate\", rarity = r, drops = drops })\n  grantAll(st, ss, drops)\n  G.progress(st, ss, \"crates\", 1)\n  return drops\nend\n\n------------------------------------------------------------------------------\n-- The season pass\n------------------------------------------------------------------------------\n\n-- A new month is a new season: the track starts again, and the minutes\n-- towards the next tier carry over.\nfunction G.checkSeason(st, ss, epoch)\n  local id = G.seasonOf(epoch)\n  if st.pass.season == id then return false end\n  if st.pass.season ~= 0 then\n    st.seasons[tostring(st.pass.season)] = st.pass.tier\n    notice(ss, { kind = \"season\", season = id, name = G.L.seasonName(id) })\n  end\n  st.pass.season, st.pass.tier = id, 0\n  return true\nend\n\nfunction G.unlockTier(st, ss)\n  local L = G.L\n  st.pass.tier = st.pass.tier + 1\n  st.stats.tiers = st.stats.tiers + 1\n  local drops, kind = L.tierRewards(st.pass.season, st.pass.tier, st.level, { collector = G.hasPower(st, \"collector\") })\n  if kind ~= \"small\" and G.hasPower(st, \"golden_hour\") then\n    drops[#drops + 1] = L.makeDrop(ss.rnd, L.rollRarity(ss.rnd, L.RARE, L.MYTHIC, G.bonus(st, \"luck\")), \"crate\", { ilvl = st.level })\n  end\n  notice(ss, { kind = \"tier\", tier = st.pass.tier, tierKind = kind, drops = drops })\n  grantAll(st, ss, drops)\n  if st.pass.tier == L.SEASON_TIERS then st.stats.seasonsDone = st.stats.seasonsDone + 1 end\n  G.progress(st, ss, \"tiers\", 1)\n  return drops\nend\n\n------------------------------------------------------------------------------\n-- Time: the idle-aware clock\n--\n-- signals = { input = something happened, playing, recording, project = name }\n------------------------------------------------------------------------------\n\nfunction G.tick(st, ss, tp, epoch, signals)\n  epoch = math.floor(epoch)\n  local dt = math.max(0, math.min(1.0, tp - (ss.now or tp)))\n  ss.now, ss.epoch = tp, epoch\n  ss.hour = tonumber(os.date(\"%H\", epoch)) or ss.hour\n  ss.wday = tonumber(os.date(\"%w\", epoch)) or ss.wday\n  if signals.input or signals.recording then ss.lastInput = tp end\n  local idle = (tp - ss.lastInput) > G.idleLimit(st, signals.playing)\n  if idle ~= ss.idle then\n    ss.idle = idle\n    if idle then notice(ss, { kind = \"idle\" })\n    else\n      notice(ss, { kind = \"active\" })\n      if G.hasPower(st, \"second_wind\") and tp - ss.lastWind >= 1800 then\n        ss.lastWind = tp\n        G.addXp(st, ss, G.XP.wind, \"wind\")\n        notice(ss, { kind = \"toast\", text = \"Second Wind\", sub = \"+\" .. G.XP.wind .. \" XP for coming back\", icon = \"bolt\", rarity = 6 })\n      end\n    end\n  end\n  if signals.project and signals.project ~= ss.project then\n    ss.project = signals.project\n    G.progress(st, ss, \"projects\", 1, { name = signals.project })\n  end\n  if idle or dt <= 0 then return end\n\n  local s = st.stats\n  ss.active = ss.active + dt\n  s.active = s.active + dt\n  s.longest = math.max(s.longest, ss.active)\n  local day = G.dayKey(epoch)\n  st.days[day] = (st.days[day] or 0) + dt\n  s.maxDay = math.max(s.maxDay, st.days[day])\n  if ss.project then st.projects[ss.project] = (st.projects[ss.project] or 0) + dt end\n  if ss.hour < 5 then s.night = s.night + dt elseif ss.hour < 9 then s.dawn = s.dawn + dt end\n  if ss.wday == 0 or ss.wday == 6 then s.weekend = s.weekend + dt end\n  if st.boost > 0 then st.boost = math.max(0, st.boost - dt) end\n\n  ss.minuteAcc = ss.minuteAcc + dt\n  while ss.minuteAcc >= 60 do\n    ss.minuteAcc = ss.minuteAcc - 60\n    G.addXp(st, ss, G.XP.minute, \"time\")\n  end\n  G.progress(st, ss, \"minutes\", dt)\n  G.progress(st, ss, \"session\", 0)\n\n  st.pass.secs = st.pass.secs + dt * (ss.speed or 1)\n  while st.pass.secs >= G.TIER_SECONDS do\n    st.pass.secs = st.pass.secs - G.TIER_SECONDS\n    G.unlockTier(st, ss)\n  end\nend\n\n------------------------------------------------------------------------------\n-- What you do in REAPER: events from the watcher.\n------------------------------------------------------------------------------\n\n-- Plugin names as REAPER gives them - \"VST3i: Serum (Xfer Records)\" - made\n-- into something two lists can be matched on: \"serum\". Also the display name\n-- and whether it is an instrument.\nfunction G.normFx(name)\n  name = tostring(name or \"\")\n  local prefix = name:match(\"^(%u+%d?i?):%s*\")\n  local instrument = prefix ~= nil and prefix:sub(-1) == \"i\"\n  local display = name:gsub(\"^%u+%d?i?:%s*\", \"\")\n  for _ = 1, 3 do display = display:gsub(\"%s*%b()%s*$\", \"\") end\n  display = display:gsub(\"^%s+\", \"\"):gsub(\"%s+$\", \"\")\n  return display:lower(), display, instrument\nend\n\nG.CATEGORIES = {\n  { id = \"eq\",    name = \"an EQ\",                 keys = { \"eq\", \"equali\", \"pro%-q\", \"pultec\" } },\n  { id = \"comp\",  name = \"a compressor\",          keys = { \"comp\", \"1176\", \"la%-2a\", \"la2a\", \"opto\", \"glue\", \"pro%-c\", \"limit\" } },\n  { id = \"verb\",  name = \"a reverb\",              keys = { \"verb\", \"hall\", \"plate\", \"valhalla\", \"room\" } },\n  { id = \"delay\", name = \"a delay\",               keys = { \"delay\", \"echo\", \"dly\" } },\n  { id = \"sat\",   name = \"a saturator or distortion\", keys = { \"satur\", \"distort\", \"drive\", \"tube\", \"decapitator\", \"crush\", \"fuzz\", \"tape\", \"clip\" } },\n  { id = \"mod\",   name = \"a chorus, flanger or phaser\", keys = { \"chorus\", \"flang\", \"phas\", \"trem\", \"vibrato\", \"ensemble\", \"rotary\" } },\n  { id = \"inst\",  name = \"a virtual instrument\",  instrument = true },\n}\nfor _, c in ipairs(G.CATEGORIES) do G.CATEGORIES[c.id] = c end\n\nfunction G.inCategory(info, catId)\n  local c = G.CATEGORIES[catId]\n  if not c then return false end\n  if c.instrument then return info.instrument == true end\n  for _, k in ipairs(c.keys) do if info.norm:find(k) then return true end end\n  return false\nend\n\n-- kind: edit, track, item, fx, notes, take, marker, idea. n: how many.\n-- info for fx: { name, norm, instrument }.\nfunction G.event(st, ss, kind, n, info)\n  n = n or 1\n  local s = st.stats\n  if kind == \"edit\" then\n    s.edits = s.edits + n\n    G.addXp(st, ss, G.XP.edit * n, \"edit\")\n    G.progress(st, ss, \"edits\", n)\n  elseif kind == \"track\" then\n    s.tracks = s.tracks + n\n    G.addXp(st, ss, G.XP.track * n, \"track\")\n    G.progress(st, ss, \"tracks\", n)\n  elseif kind == \"item\" then\n    s.items = s.items + n\n    G.addXp(st, ss, G.XP.item * n, \"item\")\n    G.progress(st, ss, \"items\", n)\n  elseif kind == \"notes\" then\n    s.notes = s.notes + n\n    G.addXp(st, ss, G.XP.note * n, \"notes\")\n    G.progress(st, ss, \"notes\", n)\n  elseif kind == \"take\" then\n    s.takes = s.takes + n\n    G.addXp(st, ss, G.XP.take * n, \"take\")\n    G.progress(st, ss, \"takes\", n)\n  elseif kind == \"marker\" then\n    s.markers = s.markers + n\n    G.addXp(st, ss, G.XP.marker * n, \"marker\")\n    G.progress(st, ss, \"markers\", n)\n  elseif kind == \"idea\" then\n    s.ideasUsed = s.ideasUsed + n\n    G.addXp(st, ss, G.XP.idea, \"idea\")\n    G.progress(st, ss, \"ideas\", n)\n  elseif kind == \"fx\" then\n    info = info or {}\n    if not info.norm then info.norm, info.name, info.instrument = G.normFx(info.name) end\n    s.fx = s.fx + 1\n    info.first = st.plugins[info.norm] == nil\n    st.plugins[info.norm] = (st.plugins[info.norm] or 0) + 1\n    G.addXp(st, ss, G.XP.fx, \"fx\")\n    if info.first then\n      G.addXp(st, ss, G.XP.discover, \"discover\")\n      notice(ss, { kind = \"toast\", text = \"New plugin discovered\", sub = info.name .. \"  +\" .. G.XP.discover .. \" XP\", icon = \"plug\", rarity = 4 })\n    end\n    G.progress(st, ss, \"fx\", 1, info)\n  end\nend\n\n------------------------------------------------------------------------------\n-- Quests\n------------------------------------------------------------------------------\n\n-- daily/weekly: { lowest, highest, step } targets. unit: what one counts in\n-- seconds (minutes quests count seconds and show minutes).\nG.QUESTS = {\n  { kind = \"minutes\",  text = \"Make music for %d minutes\", unit = 60, daily = { 20, 60, 5 }, weekly = { 180, 420, 30 } },\n  { kind = \"session\",  text = \"Work for %d minutes in one sitting\", unit = 60, daily = { 30, 60, 15 }, weekly = { 90, 180, 30 } },\n  { kind = \"tracks\",   text = \"Create %d new tracks\", daily = { 2, 5, 1 }, weekly = { 10, 25, 5 } },\n  { kind = \"items\",    text = \"Create %d new media items\", daily = { 5, 15, 5 }, weekly = { 30, 80, 10 } },\n  { kind = \"fx\",       text = \"Add %d plugins to tracks\", daily = { 3, 8, 1 }, weekly = { 15, 40, 5 } },\n  { kind = \"plugin\",   text = \"Use %s\", daily = { 1, 2, 1 }, weekly = { 3, 5, 1 }, plugins = true, weight = 3 },\n  { kind = \"category\", text = \"Use %s\", daily = { 1, 3, 1 }, weekly = { 5, 10, 1 } },\n  { kind = \"discover\", text = \"Try %d plugins you've never used before\", daily = { 1, 2, 1 }, weekly = { 3, 6, 1 } },\n  { kind = \"distinct\", text = \"Use %d different plugins\", daily = { 3, 6, 1 }, weekly = { 10, 20, 2 } },\n  { kind = \"notes\",    text = \"Write %d MIDI notes\", daily = { 50, 200, 25 }, weekly = { 500, 1500, 100 } },\n  { kind = \"takes\",    text = \"Record %d takes\", daily = { 1, 4, 1 }, weekly = { 5, 15, 5 } },\n  { kind = \"markers\",  text = \"Add %d markers or regions\", daily = { 2, 6, 1 }, weekly = { 10, 25, 5 } },\n  { kind = \"edits\",    text = \"Make %d edits\", daily = { 50, 150, 25 }, weekly = { 400, 1000, 100 } },\n  { kind = \"tiers\",    text = \"Unlock %d battle pass tiers\", daily = { 2, 4, 1 }, weekly = { 12, 24, 4 } },\n  { kind = \"crates\",   text = \"Open %d loot crates\", daily = { 1, 2, 1 }, weekly = { 4, 8, 1 } },\n  { kind = \"ideas\",    text = \"Put %d reward ideas into a project\", daily = { 1, 2, 1 }, weekly = { 3, 6, 1 } },\n  { kind = \"projects\", text = \"Work on %d different projects\", weekly = { 2, 4, 1 } },\n  { kind = \"dailies\",  text = \"Complete %d daily quests\", weekly = { 8, 15, 1 } },\n  { kind = \"checkins\", text = \"Check in on %d days\", weekly = { 4, 6, 1 } },\n}\nfor _, q in ipairs(G.QUESTS) do G.QUESTS[q.kind] = q end\n\nlocal function makeQuest(rnd, tpl, scope, plugins)\n  local L = G.L\n  local spec = tpl[scope]\n  local steps = math.floor((spec[2] - spec[1]) / spec[3])\n  local target = spec[1] + math.floor(rnd() * (steps + 1)) * spec[3]\n  local diff = steps > 0 and (target - spec[1]) / (spec[2] - spec[1]) or 0.5\n  local q = { kind = tpl.kind, target = target * (tpl.unit or 1), progress = 0, done = false, claimed = false,\n              scope = scope, seen = {} }\n  if tpl.kind == \"plugin\" then\n    local p = L.pickOne(rnd, plugins)\n    q.param, q.match = p.display, p.norm\n    q.text = (target > 1) and string.format(\"Use %s on %d tracks\", p.display, target) or (\"Use \" .. p.display .. \" on a track\")\n  elseif tpl.kind == \"category\" then\n    local c = L.pickOne(rnd, G.CATEGORIES)\n    q.param = c.id\n    q.text = (target > 1) and string.format(\"Use %s %d times\", c.name, target) or (\"Use \" .. c.name)\n  else\n    q.text = string.format(tpl.text, target)\n  end\n  if scope == \"daily\" then\n    q.coins = math.floor(40 + diff * 50 + 0.5)\n    q.xp = math.floor(80 + diff * 80 + 0.5)\n    q.rarity = (diff > 0.66) and 4 or 3\n  else\n    q.coins = math.floor(250 + diff * 200 + 0.5)\n    q.xp = math.floor(500 + diff * 400 + 0.5)\n    q.crate = 4\n    q.rarity = (diff > 0.66) and 6 or 5\n  end\n  return q\nend\n\nlocal function questPool(scope, plugins, exclude)\n  local pool = {}\n  for _, tpl in ipairs(G.QUESTS) do\n    if tpl[scope] and not exclude[tpl.kind] and (not tpl.plugins or #plugins > 0) then\n      pool[#pool + 1] = { tpl.weight or 1, tpl }\n    end\n  end\n  return pool\nend\n\nfunction G.makeQuests(rnd, scope, plugins)\n  plugins = plugins or {}\n  local list, used = {}, {}\n  list[1] = makeQuest(rnd, G.QUESTS.minutes, scope, plugins)\n  used.minutes = true\n  if scope == \"weekly\" then\n    list[2] = makeQuest(rnd, G.QUESTS.dailies, scope, plugins)\n    used.dailies = true\n  end\n  local want = (scope == \"daily\") and 3 or 4\n  while #list < want do\n    local pool = questPool(scope, plugins, used)\n    if #pool == 0 then break end\n    local tpl = G.L.weighted(rnd, pool)\n    used[tpl.kind] = true\n    list[#list + 1] = makeQuest(rnd, tpl, scope, plugins)\n  end\n  return list\nend\n\nlocal function claimQuestRewards(st, ss, q, silent)\n  q.claimed = true\n  local pct = G.bonus(st, \"quest\")\n  local coins = G.addCoins(st, ss, q.coins * (1 + pct / 100), true)\n  local xp = q.xp * (1 + pct / 100) * (G.hasPower(st, \"scholar\") and 1.5 or 1)\n  G.addXp(st, ss, xp, \"quest\")\n  if q.crate then st.inv.crates[q.crate] = st.inv.crates[q.crate] + 1 end\n  if not silent then notice(ss, { kind = \"claim\", text = q.text, coins = coins, xp = math.floor(xp), crate = q.crate }) end\nend\n\n-- New quests when the day or week turns. Finished but unclaimed quests are\n-- claimed for you first: nothing earned is lost to the clock.\nfunction G.refresh(st, ss, epoch, plugins)\n  G.checkSeason(st, ss, epoch)\n  local day, week = G.dayKey(epoch), G.weekKey(epoch)\n  if st.daily.key ~= day then\n    for _, q in ipairs(st.daily.quests) do if q.done and not q.claimed then claimQuestRewards(st, ss, q, true) end end\n    local rnd = G.L.random(G.L.seedOf(\"daily\", day, epoch))\n    local had = st.daily.key ~= \"\"\n    st.daily = { key = day, quests = G.makeQuests(rnd, \"daily\", plugins), bonus = false, fickle = false }\n    if had then notice(ss, { kind = \"toast\", text = \"New daily quests\", sub = \"Three fresh quests are waiting\", icon = \"scroll\", rarity = 3 }) end\n    -- Prune old days from the history.\n    for k in pairs(st.days) do if G.daysBetween(k, day) > 120 then st.days[k] = nil end end\n  end\n  if st.weekly.key ~= week then\n    for _, q in ipairs(st.weekly.quests) do if q.done and not q.claimed then claimQuestRewards(st, ss, q, true) end end\n    local rnd = G.L.random(G.L.seedOf(\"weekly\", week, epoch))\n    local had = st.weekly.key ~= \"\"\n    st.weekly = { key = week, quests = G.makeQuests(rnd, \"weekly\", plugins), bonus = false }\n    if had then notice(ss, { kind = \"toast\", text = \"New weekly quests\", sub = \"Four big quests for the week\", icon = \"scroll\", rarity = 5 }) end\n  end\n  if st.shop.day ~= day then G.makeDeals(st, day) end\nend\n\nlocal function questMatches(q, kind, n, info)\n  local k = q.kind\n  if k == kind then\n    if k == \"projects\" then\n      if q.seen[info.name] then return 0 end\n      q.seen[info.name] = true\n      return 1\n    end\n    return n\n  end\n  if kind ~= \"fx\" then return 0 end\n  if k == \"plugin\" then\n    if info.norm == q.match or info.norm:find(q.match, 1, true) then return 1 end\n  elseif k == \"category\" then\n    if G.inCategory(info, q.param) then return 1 end\n  elseif k == \"discover\" then\n    if info.first then return 1 end\n  elseif k == \"distinct\" then\n    if not q.seen[info.norm] then q.seen[info.norm] = true; return 1 end\n  end\n  return 0\nend\n\n-- Moves every quest a thing counts towards.\nfunction G.progress(st, ss, kind, n, info)\n  for _, scope in ipairs({ \"daily\", \"weekly\" }) do\n    for _, q in ipairs(st[scope].quests) do\n      if not q.done then\n        if q.kind == \"session\" and kind == \"session\" then\n          q.progress = math.min(q.target, math.max(q.progress, ss.active))\n        else\n          local add = questMatches(q, kind, n, info or {})\n          if add > 0 then q.progress = math.min(q.target, q.progress + add) end\n        end\n        if q.progress >= q.target then\n          q.done = true\n          if scope == \"daily\" then\n            st.stats.dailies = st.stats.dailies + 1\n          else\n            st.stats.weeklies = st.stats.weeklies + 1\n          end\n          notice(ss, { kind = \"quest\", text = q.text, scope = scope, rarity = q.rarity })\n          if scope == \"daily\" then G.progress(st, ss, \"dailies\", 1) end\n        end\n      end\n    end\n  end\nend\n\n-- Claim a finished quest. Claiming the last of a set opens its bonus crate.\nfunction G.claimQuest(st, ss, scope, i)\n  local set = st[scope]\n  local q = set.quests[i]\n  if not q or not q.done or q.claimed then return false end\n  claimQuestRewards(st, ss, q)\n  local all = true\n  for _, x in ipairs(set.quests) do if not x.claimed then all = false end end\n  if all and not set.bonus then\n    set.bonus = true\n    local r = (scope == \"daily\") and 3 or 5\n    st.inv.crates[r] = st.inv.crates[r] + 1\n    notice(ss, { kind = \"toast\", text = \"All \" .. scope .. \" quests done!\", sub = G.L.RARITY[r].name .. \" Crate added to Loot\", icon = \"crate\", rarity = r })\n  end\n  return true\nend\n\nfunction G.canReroll(st, scope)\n  if scope == \"daily\" and G.hasPower(st, \"fickle\") and not st.daily.fickle then return true end\n  return (st.inv.tokens.reroll or 0) > 0\nend\n\nfunction G.reroll(st, ss, scope, i, plugins)\n  local set = st[scope]\n  local q = set.quests[i]\n  if not q or q.done or not G.canReroll(st, scope) then return false end\n  if scope == \"daily\" and G.hasPower(st, \"fickle\") and not st.daily.fickle then st.daily.fickle = true\n  else st.inv.tokens.reroll = st.inv.tokens.reroll - 1 end\n  local used = {}\n  for _, x in ipairs(set.quests) do used[x.kind] = true end\n  local pool = questPool(scope, plugins or {}, used)\n  if #pool == 0 then pool = questPool(scope, plugins or {}, { minutes = true, dailies = true }) end\n  set.quests[i] = makeQuest(ss.rnd, G.L.weighted(ss.rnd, pool), scope, plugins or {})\n  notice(ss, { kind = \"toast\", text = \"Quest rerolled\", sub = set.quests[i].text, icon = \"dice\", rarity = 3 })\n  return true\nend\n\n------------------------------------------------------------------------------\n-- Daily check-in: a seven-day calendar, every fourth week's seventh day a\n-- Legendary crate.\n------------------------------------------------------------------------------\n\nG.CHECKIN = {\n  { coins = 25 },\n  { coins = 35, xp = 50 },\n  { crate = 3 },\n  { coins = 60 },\n  { token = \"reroll\" },\n  { coins = 90, xp = 100 },\n  { coins = 120, crate = 5 },\n}\n\nfunction G.checkinAvailable(st, epoch) return st.checkin.last ~= G.dayKey(epoch) end\n\n-- The day of the cycle the next check-in lands on, and what the streak\n-- would become (for the calendar).\nfunction G.checkinPreview(st, epoch)\n  local today = G.dayKey(epoch)\n  local c = st.checkin\n  if c.last == today then return (c.streak - 1) % 7 + 1, c.streak, 0 end\n  local gap = G.daysBetween(c.last, today)\n  local streak, freezes = 1, 0\n  if c.last ~= \"\" and gap == 1 then streak = c.streak + 1\n  elseif c.last ~= \"\" and gap > 1 and gap - 1 <= (st.inv.tokens.freeze or 0) then\n    streak, freezes = c.streak + 1, gap - 1\n  end\n  return (streak - 1) % 7 + 1, streak, freezes\nend\n\nfunction G.checkin(st, ss, epoch)\n  if not G.checkinAvailable(st, epoch) then return nil end\n  local day, streak, freezes = G.checkinPreview(st, epoch)\n  local c = st.checkin\n  local broke = c.last ~= \"\" and streak == 1 and c.streak > 0\n  if freezes > 0 then st.inv.tokens.freeze = st.inv.tokens.freeze - freezes end\n  c.last, c.streak, c.total = G.dayKey(epoch), streak, c.total + 1\n  c.best = math.max(c.best, streak)\n  local reward = G.CHECKIN[day]\n  local pct = G.bonus(st, \"checkin\")\n  local got = { day = day, streak = streak, freezes = freezes, broke = broke }\n  if reward.coins then got.coins = G.addCoins(st, ss, reward.coins * (1 + pct / 100), true) end\n  if reward.xp then got.xp = G.addXp(st, ss, reward.xp * (1 + pct / 100), \"checkin\") end\n  if reward.token then st.inv.tokens[reward.token] = st.inv.tokens[reward.token] + 1; got.token = reward.token end\n  if reward.crate then\n    local r = reward.crate\n    if day == 7 and streak % 28 == 0 then r = 6 end\n    st.inv.crates[r] = st.inv.crates[r] + 1\n    got.crate = r\n  end\n  G.progress(st, ss, \"checkins\", 1)\n  got.kind = \"checkin\"\n  notice(ss, got)\n  return got\nend\n\n------------------------------------------------------------------------------\n-- The shop\n------------------------------------------------------------------------------\n\n-- Daily Deals: three items made for the day - gear, cosmetics, an idea -\n-- Rare to Legendary, at a price by rarity. Made once a day and kept, so they\n-- don't change as you level.\nfunction G.makeDeals(st, day)\n  local L = G.L\n  local rnd = L.random(L.seedOf(\"deals\", day))\n  local deals = {}\n  for i = 1, 3 do\n    local r = L.rollRarity(rnd, L.RARE, L.LEGENDARY)\n    local d = L.makeDrop(rnd, r, \"deal\", { ilvl = st.level })\n    deals[i] = { drop = d, price = math.floor(G.DEAL_PRICE[r] * (d.type == \"gear\" and 1 or 0.6) + 0.5), bought = false }\n  end\n  st.shop = { day = day, deals = deals }\nend\n\nfunction G.buy(st, ss, id)\n  local item = G.SHOP[id]\n  if not item or st.coins < item.price then return false end\n  st.coins = st.coins - item.price\n  st.stats.coinsSpent = st.stats.coinsSpent + item.price\n  st.stats.purchases = st.stats.purchases + 1\n  if item.kind == \"pass\" then st.inv.passes[id] = (st.inv.passes[id] or 0) + 1\n  elseif item.kind == \"token\" then st.inv.tokens[item.token] = (st.inv.tokens[item.token] or 0) + 1\n  elseif item.kind == \"crate\" then st.inv.crates[item.rarity] = st.inv.crates[item.rarity] + 1 end\n  notice(ss, { kind = \"purchase\", name = item.name, icon = item.icon, price = item.price })\n  return true\nend\n\nfunction G.buyDeal(st, ss, i)\n  local deal = st.shop.deals[i]\n  if not deal or deal.bought or st.coins < deal.price then return false end\n  st.coins = st.coins - deal.price\n  st.stats.coinsSpent = st.stats.coinsSpent + deal.price\n  st.stats.purchases = st.stats.purchases + 1\n  deal.bought = true\n  local d = {}\n  for k, v in pairs(deal.drop) do d[k] = v end\n  G.grant(st, ss, d)\n  notice(ss, { kind = \"purchase\", name = d.text, icon = d.icon, price = deal.price, rarity = d.rarity })\n  return true\nend\n\nfunction G.redeem(st, ss, id, epoch)\n  local item = G.SHOP[id]\n  if not item or (st.inv.passes[id] or 0) <= 0 then return false end\n  st.inv.passes[id] = st.inv.passes[id] - 1\n  st.stats.redeemed = st.stats.redeemed + 1\n  table.insert(st.log, 1, { id = id, name = item.name, t = epoch or 0 })\n  while #st.log > 50 do table.remove(st.log) end\n  notice(ss, { kind = \"redeem\", id = id, name = item.name, icon = item.icon })\n  return true\nend\n\nfunction G.useBoost(st, ss)\n  if (st.inv.tokens.boost or 0) <= 0 then return false end\n  st.inv.tokens.boost = st.inv.tokens.boost - 1\n  local secs = G.BOOST_SECONDS * (G.hasPower(st, \"overclock\") and 2 or 1)\n  st.boost = st.boost + secs\n  st.stats.boosts = st.stats.boosts + 1\n  notice(ss, { kind = \"toast\", text = \"XP Boost active\", sub = \"Double XP for \" .. math.floor(secs / 60) .. \" active minutes\", icon = \"bolt\", rarity = 5 })\n  return true\nend\n\n------------------------------------------------------------------------------\n-- Gear\n------------------------------------------------------------------------------\n\nlocal function findStash(st, uid)\n  for i, it in ipairs(st.gear.stash) do if it.uid == uid then return i, it end end\nend\n\nfunction G.equip(st, ss, uid)\n  local i, item = findStash(st, uid)\n  if not item then return false end\n  table.remove(st.gear.stash, i)\n  local old = st.gear.equipped[item.slot]\n  st.gear.equipped[item.slot] = item\n  if old then table.insert(st.gear.stash, 1, old) end\n  notice(ss, { kind = \"equip\", name = item.name, rarity = item.rarity })\n  return true\nend\n\nfunction G.unequip(st, ss, slot)\n  local item = st.gear.equipped[slot]\n  if not item or #st.gear.stash >= G.STASH_MAX then return false end\n  st.gear.equipped[slot] = nil\n  table.insert(st.gear.stash, 1, item)\n  return true\nend\n\nfunction G.salvage(st, ss, uid)\n  local i, item = findStash(st, uid)\n  if not item then return 0 end\n  table.remove(st.gear.stash, i)\n  local v = G.L.sellValue(item)\n  st.coins = st.coins + v\n  notice(ss, { kind = \"coins\", amount = v })\n  return v\nend\n\n-- Sells everything in the stash at or under a rarity.\nfunction G.salvageUpTo(st, ss, maxRarity)\n  local total, n = 0, 0\n  for i = #st.gear.stash, 1, -1 do\n    local it = st.gear.stash[i]\n    if it.rarity <= maxRarity then\n      table.remove(st.gear.stash, i)\n      total = total + G.L.sellValue(it)\n      n = n + 1\n    end\n  end\n  st.coins = st.coins + total\n  if n > 0 then notice(ss, { kind = \"coins\", amount = total }) end\n  return n, total\nend\n\n------------------------------------------------------------------------------\n-- The vault of ideas\n------------------------------------------------------------------------------\n\nfunction G.findIdea(st, uid)\n  for i, v in ipairs(st.vault) do if v.uid == uid then return i, v end end\nend\n\nfunction G.removeIdea(st, uid)\n  local i = G.findIdea(st, uid)\n  if i then table.remove(st.vault, i); return true end\n  return false\nend\n\nfunction G.ideaUsed(st, ss, uid)\n  local _, v = G.findIdea(st, uid)\n  if v and not v.used then\n    v.used = true\n    G.event(st, ss, \"idea\", 1)\n  end\nend\n\n------------------------------------------------------------------------------\n-- Achievements: series of tiers. The last tier of a series also gives its\n-- title to wear.\n------------------------------------------------------------------------------\n\nlocal function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end\n\nG.ACHIEVEMENTS = {\n  { id = \"hours\", name = \"Time in the Studio\", fmt = \"Make music for %s hours\", title = \"Studio Legend\",\n    value = function(st) return st.stats.active / 3600 end, goals = { 1, 5, 10, 25, 50, 100, 250, 500, 1000 } },\n  { id = \"session\", name = \"In the Zone\", fmt = \"Work for %s hours in one session\", title = \"The Unbreakable\",\n    value = function(st) return st.stats.longest / 3600 end, goals = { 1, 2, 3, 4, 6 } },\n  { id = \"day\", name = \"Full Shift\", fmt = \"Make music for %s hours in one day\", title = \"Overtime Hero\",\n    value = function(st) return st.stats.maxDay / 3600 end, goals = { 2, 4, 6, 8 } },\n  { id = \"level\", name = \"Level Up\", fmt = \"Reach level %s\", title = \"The Ascended\",\n    value = function(st) return st.level end, goals = { 5, 10, 20, 30, 50, 75, 100 } },\n  { id = \"tiers\", name = \"Battle Pass\", fmt = \"Unlock %s battle pass tiers\", title = \"Tier Crusher\",\n    value = function(st) return st.stats.tiers end, goals = { 1, 10, 50, 100, 250, 500, 1000 } },\n  { id = \"seasons\", name = \"Season Champion\", fmt = \"Finish %s season passes\", title = \"Champion of Seasons\",\n    value = function(st) return st.stats.seasonsDone end, goals = { 1, 3, 6, 12 } },\n  { id = \"streak\", name = \"On a Roll\", fmt = \"A check-in streak of %s days\", title = \"The Devoted\",\n    value = function(st) return st.checkin.best end, goals = { 3, 7, 14, 30, 60, 100, 365 } },\n  { id = \"loyal\", name = \"Regular\", fmt = \"Check in on %s days in total\", title = \"Part of the Furniture\",\n    value = function(st) return st.checkin.total end, goals = { 7, 30, 100, 365, 1000 } },\n  { id = \"tracks\", name = \"Track Builder\", fmt = \"Create %s tracks\", title = \"Architect of Tracks\",\n    value = function(st) return st.stats.tracks end, goals = { 10, 50, 250, 1000, 5000 } },\n  { id = \"items\", name = \"Item Maker\", fmt = \"Create %s media items\", title = \"Clip Collector\",\n    value = function(st) return st.stats.items end, goals = { 50, 250, 1000, 5000, 20000 } },\n  { id = \"notes\", name = \"Note Writer\", fmt = \"Write %s MIDI notes\", title = \"The Composer\",\n    value = function(st) return st.stats.notes end, goals = { 100, 1000, 10000, 50000, 250000 } },\n  { id = \"takes\", name = \"Tape Rolling\", fmt = \"Record %s takes\", title = \"One More Take\",\n    value = function(st) return st.stats.takes end, goals = { 1, 25, 100, 500 } },\n  { id = \"fx\", name = \"Plugin Stacker\", fmt = \"Add %s plugins to tracks\", title = \"Rack Master\",\n    value = function(st) return st.stats.fx end, goals = { 10, 100, 500, 2500 } },\n  { id = \"plugins\", name = \"Plugin Explorer\", fmt = \"Use %s different plugins\", title = \"Plugin Connoisseur\",\n    value = function(st) return count(st.plugins) end, goals = { 5, 15, 40, 100, 250 } },\n  { id = \"quests\", name = \"Quest Giver's Favourite\", fmt = \"Complete %s quests\", title = \"The Questor\",\n    value = function(st) return st.stats.dailies + st.stats.weeklies end, goals = { 1, 10, 50, 200, 1000 } },\n  { id = \"crates\", name = \"Crate Cracker\", fmt = \"Open %s loot crates\", title = \"Crate Goblin\",\n    value = function(st) return st.stats.crates end, goals = { 1, 10, 50, 250, 1000 } },\n  { id = \"coins\", name = \"Coin Hoarder\", fmt = \"Earn %s coins\", title = \"The Tycoon\",\n    value = function(st) return st.stats.coinsEarned end, goals = { 1000, 10000, 50000, 250000, 1000000 } },\n  { id = \"treats\", name = \"Treat Yourself\", fmt = \"Redeem %s passes\", title = \"Professional Relaxer\",\n    value = function(st) return st.stats.redeemed end, goals = { 1, 10, 50, 100 } },\n  { id = \"ideas\", name = \"Idea Collector\", fmt = \"Collect %s ideas\", title = \"Keeper of Ideas\",\n    value = function(st) return st.stats.ideas end, goals = { 10, 100, 500, 2000 } },\n  { id = \"used\", name = \"Ideas Into Music\", fmt = \"Put %s reward ideas into projects\", title = \"The Finisher\",\n    value = function(st) return st.stats.ideasUsed end, goals = { 1, 10, 50, 200 } },\n  { id = \"legend\", name = \"Legendary Luck\", fmt = \"Find %s Legendary or better items\", title = \"Touched by Fortune\",\n    value = function(st) return st.stats.legendaries end, goals = { 1, 10, 50, 200 } },\n  { id = \"mythic\", name = \"Myth Maker\", fmt = \"Find %s Mythic items\", title = \"The Mythic\",\n    value = function(st) return st.stats.mythics end, goals = { 1, 5, 25 } },\n  { id = \"gear\", name = \"Fully Kitted\", fmt = \"Reach a gear score of %s\", title = \"Gear Lord\",\n    value = function(st) return G.gearScore(st) end, goals = { 50, 150, 300, 500, 800 } },\n  { id = \"night\", name = \"Night Owl\", fmt = \"Make music for %s hours between midnight and 5am\", title = \"Creature of the Night\",\n    value = function(st) return st.stats.night / 3600 end, goals = { 1, 10, 50 } },\n  { id = \"dawn\", name = \"Early Bird\", fmt = \"Make music for %s hours between 5am and 9am\", title = \"Dawn Patrol\",\n    value = function(st) return st.stats.dawn / 3600 end, goals = { 1, 10, 50 } },\n  { id = \"weekend\", name = \"Weekend Warrior\", fmt = \"Make music for %s hours at weekends\", title = \"Weekend Warrior\",\n    value = function(st) return st.stats.weekend / 3600 end, goals = { 5, 25, 100 } },\n  { id = \"projects\", name = \"Project Hopper\", fmt = \"Work on %s different projects\", title = \"Many Hats\",\n    value = function(st) return count(st.projects) end, goals = { 3, 10, 50, 200 } },\n  { id = \"shopper\", name = \"Big Spender\", fmt = \"Spend %s coins\", title = \"Patron of the Shop\",\n    value = function(st) return st.stats.coinsSpent end, goals = { 500, 5000, 25000, 100000 } },\n}\nfor _, a in ipairs(G.ACHIEVEMENTS) do G.ACHIEVEMENTS[a.id] = a end\n\nfunction G.achievementTotals(st)\n  local have, all = 0, 0\n  for _, a in ipairs(G.ACHIEVEMENTS) do\n    all = all + #a.goals\n    have = have + (st.ach[a.id] or 0)\n  end\n  return have, all\nend\n\nlocal ROMAN = { \"I\", \"II\", \"III\", \"IV\", \"V\", \"VI\", \"VII\", \"VIII\", \"IX\", \"X\" }\nfunction G.roman(n) return ROMAN[n] or tostring(n) end\n\nlocal function fmtGoal(g)\n  if g >= 1000 and g % 1000 == 0 then return math.floor(g / 1000) .. \",000\" end\n  return tostring(g)\nend\nG.fmtGoal = fmtGoal\n\nfunction G.checkAchievements(st, ss)\n  for _, a in ipairs(G.ACHIEVEMENTS) do\n    local have = st.ach[a.id] or 0\n    local v = a.value(st)\n    while have < #a.goals and v >= a.goals[have + 1] do\n      have = have + 1\n      st.ach[a.id] = have\n      local coins = 40 * have\n      local xp = 80 * have\n      G.addCoins(st, ss, coins, false)\n      G.addXp(st, ss, xp, \"ach\")\n      local final = have == #a.goals\n      if final then st.cos.titles[#st.cos.titles + 1] = { text = a.title, rarity = 6 } end\n      notice(ss, { kind = \"ach\", name = a.name .. \" \" .. G.roman(have),\n                   text = string.format(a.fmt, fmtGoal(a.goals[have])), coins = coins, xp = xp,\n                   tier = have, final = final, title = final and a.title or nil })\n    end\n  end\nend\n\n------------------------------------------------------------------------------\n-- For the window\n------------------------------------------------------------------------------\n\nfunction G.weekSeconds(st, epoch)\n  local monday = G.weekKey(epoch)\n  local total = 0\n  for k, v in pairs(st.days) do\n    local d = G.daysBetween(monday, k)\n    if d >= 0 and d < 7 then total = total + v end\n  end\n  return total\nend\n\nfunction G.activeTitle(st)\n  local t = st.cos.titles[st.profile.title]\n  return t and t.text or \"\"\nend\n\nfunction G.activeBanner(st)\n  return st.cos.banners[st.profile.banner]\nend\n\nfunction G.init(L)\n  G.L = L\n  return G\nend\n\nreturn G\n", "battle-pass/bp_loot.lua": "--[[ DAW Battle Pass - the loot.\n\n     Pure Lua. Nothing in this file touches REAPER or ImGui: it takes a dice\n     function and returns plain tables, so tests/test_loot.lua can make\n     thousands of rewards and check every one.\n\n     Everything the pass hands out is made here, on the fly, from word lists\n     and musical rules - which is what makes it endless:\n\n       - the rarity ladder, Poor to Mythic (L.RARITY);\n       - ideas: song titles, song themes, chord progressions, drum patterns,\n         melodies, sound design briefs, challenges, genre fusions, artist\n         aliases, lyric openers, arrangements, song seeds and Good Idea\n         numbers (L.IDEAS);\n       - studio gear in the manner of Diablo: a base, an implicit stat, random\n         affixes that name the item, and on Legendary and Mythic gear a power\n         (L.makeGear);\n       - cosmetics: player titles and banners;\n       - coins, XP, tokens and crates, and what a crate holds;\n       - the season: its name and the reward on every tier of its track.\n\n     The dice are Midi Variator's generator (Park and Miller's), the same one\n     Good Idea uses, so a seed gives the same reward on any Lua. That is what\n     lets the season track show its rewards before they are reached: a tier's\n     reward is a function of the season and the tier, nothing else.\n\n     Loaded with dofile(...).init(T): it is handed the theory rather than\n     finding it, the way the sister repos load their engines.\n]]\n\nlocal L = {}\n\n------------------------------------------------------------------------------\n-- The dice\n------------------------------------------------------------------------------\n\nfunction L.random(seed)\n  local s = math.floor(math.abs(seed or 1)) % 2147483646 + 1\n  local function nextr()\n    s = s * 48271 % 2147483647\n    return (s - 1) / 2147483646\n  end\n  for _ = 1, 4 do nextr() end\n  return nextr\nend\n\n-- A seed from any mix of numbers and strings, so \"season 10, tier 37\" is\n-- always the same dice.\nfunction L.seedOf(...)\n  local h = 5381\n  for _, v in ipairs({ ... }) do\n    local s = tostring(v)\n    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483629 end\n    h = (h * 33 + 7) % 2147483629\n  end\n  return h + 1\nend\n\nlocal function between(rnd, lo, hi) return lo + math.floor(rnd() * (hi - lo + 1)) end\nlocal function chance(rnd, p) return rnd() < p end\nlocal function pickOne(rnd, list) return list[math.floor(rnd() * #list) + 1] end\nlocal function weighted(rnd, list)       -- list of { weight, value }\n  local total = 0\n  for _, e in ipairs(list) do total = total + e[1] end\n  local x = rnd() * total\n  for _, e in ipairs(list) do\n    x = x - e[1]\n    if x <= 0 then return e[2] end\n  end\n  return list[#list][2]\nend\nlocal function shuffled(rnd, list)\n  local t = {}\n  for i, v in ipairs(list) do t[i] = v end\n  for i = #t, 2, -1 do\n    local j = math.floor(rnd() * i) + 1\n    t[i], t[j] = t[j], t[i]\n  end\n  return t\nend\nL.between, L.chance, L.pickOne, L.weighted, L.shuffled = between, chance, pickOne, weighted, shuffled\n\n-- \"a\" before a consonant, \"an\" before a vowel, wherever a word list put it.\nlocal function articles(s)\n  return (s:gsub(\"(%f[%w][Aa]) ([AEIOUaeiou])\", \"%1n %2\"))\nend\nlocal function plural(w)\n  if w:sub(-1) == \"s\" then return w end\n  if w:sub(-1) == \"y\" and not w:sub(-2, -2):match(\"[aeiou]\") then return w:sub(1, -2) .. \"ies\" end\n  return w .. \"s\"\nend\nL.articles = articles\n\n------------------------------------------------------------------------------\n-- Rarity\n--\n-- The ladder of loot games: Diablo's grey Poor at the bottom, Fortnite's and\n-- WoW's Common, Uncommon, Rare, Epic and Legendary, and Mythic on top. The\n-- colours are the only saturated colours in the window besides the accent -\n-- see docs/COLOUR.md.\n------------------------------------------------------------------------------\n\nL.POOR, L.COMMON, L.UNCOMMON, L.RARE, L.EPIC, L.LEGENDARY, L.MYTHIC = 1, 2, 3, 4, 5, 6, 7\n\n-- `col` fills cards, glows and icons; `text` letters a rarity's name. Each\n-- `text` is at least 7:1 on the window's ground, Apple's target for small\n-- text in a dark window (0018); the fills are left as they were.\nL.RARITY = {\n  { name = \"Poor\",      col = 0x8A919CFF, text = 0xB0B6C0FF, weight = 12,  coins = { 4, 9 },     xp = 15,  sell = 1,   mult = 0.6 },\n  { name = \"Common\",    col = 0xDDE1E7FF, text = 0xDDE1E7FF, weight = 40,  coins = { 10, 20 },   xp = 30,  sell = 3,   mult = 0.8 },\n  { name = \"Uncommon\",  col = 0x3FCF6EFF, text = 0x3FCF6EFF, weight = 26,  coins = { 20, 40 },   xp = 60,  sell = 8,   mult = 1.0 },\n  { name = \"Rare\",      col = 0x3D8EFFFF, text = 0x8FBBFFFF, weight = 14,  coins = { 40, 80 },   xp = 120, sell = 20,  mult = 1.15 },\n  { name = \"Epic\",      col = 0xA45CFFFF, text = 0xC9A6FFFF, weight = 5.5, coins = { 90, 150 },  xp = 250, sell = 50,  mult = 1.3 },\n  { name = \"Legendary\", col = 0xFF8A1CFF, text = 0xFFA45CFF, weight = 2,   coins = { 200, 300 }, xp = 500, sell = 120, mult = 1.5 },\n  { name = \"Mythic\",    col = 0xFF3FA4FF, text = 0xFF92C9FF, weight = 0.5, coins = { 500, 750 }, xp = 1000, sell = 300, mult = 1.75 },\n}\n\n-- Luck (magic find, in percent) makes each step up the ladder that much\n-- likelier, compounding: at +50% luck an Epic is 1.5^3 times as likely.\nfunction L.rollRarity(rnd, minR, maxR, luck)\n  minR, maxR = minR or 1, maxR or #L.RARITY\n  local f = 1 + math.max(0, luck or 0) / 100\n  local list = {}\n  for i = minR, maxR do\n    local w = L.RARITY[i].weight\n    if i >= L.UNCOMMON then w = w * f ^ (i - L.COMMON) end\n    if i == L.POOR then w = w / f end\n    list[#list + 1] = { w, i }\n  end\n  return weighted(rnd, list)\nend\n\nfunction L.coinsFor(rnd, r) local c = L.RARITY[r].coins; return between(rnd, c[1], c[2]) end\n\n------------------------------------------------------------------------------\n-- Words\n------------------------------------------------------------------------------\n\nlocal ADJ = { \"Velvet\", \"Neon\", \"Midnight\", \"Golden\", \"Broken\", \"Electric\", \"Silent\",\n  \"Crystal\", \"Paper\", \"Hollow\", \"Burning\", \"Frozen\", \"Lucid\", \"Wild\", \"Distant\",\n  \"Fading\", \"Violet\", \"Static\", \"Liquid\", \"Endless\", \"Gentle\", \"Restless\", \"Secret\",\n  \"Cosmic\", \"Silver\", \"Crimson\", \"Lonely\", \"Shattered\", \"Sacred\", \"Bitter\", \"Sugar\",\n  \"Digital\", \"Analog\", \"Infinite\", \"Dusty\", \"Rusty\", \"Weightless\", \"Feral\", \"Tender\",\n  \"Hazy\", \"Lunar\", \"Solar\", \"Phantom\", \"Glass\", \"Ivory\", \"Amber\", \"Copper\",\n  \"Sleepless\", \"Borrowed\", \"Stolen\", \"Northern\", \"Tidal\", \"Holographic\", \"Vintage\",\n  \"Magnetic\", \"Scarlet\", \"Hidden\", \"Wandering\", \"Patient\", \"Reckless\", \"Quiet\",\n  \"Emerald\", \"Painted\", \"Second-hand\", \"Bulletproof\", \"Heavy\", \"Floating\", \"Kinetic\" }\n\nlocal NOUN = { \"Static\", \"Harbour\", \"Satellites\", \"Ghosts\", \"Horizon\", \"Mirrors\",\n  \"Thunder\", \"Echoes\", \"Gardens\", \"Rivers\", \"Skyline\", \"Heartbeat\", \"Daydream\",\n  \"Lighthouse\", \"Avalanche\", \"Signal\", \"Motel\", \"Arcade\", \"Polaroid\", \"Cathedral\",\n  \"Voltage\", \"Paradise\", \"Wolves\", \"Embers\", \"Tides\", \"Comet\", \"Orbit\", \"Monsoon\",\n  \"Velocity\", \"Labyrinth\", \"Carousel\", \"Fever\", \"Sunrise\", \"Moonlight\", \"Freeway\",\n  \"Postcard\", \"Wildfire\", \"Nebula\", \"Gravity\", \"Lullaby\", \"Mirage\", \"Rooftop\",\n  \"Streetlights\", \"Cassette\", \"Pulse\", \"Lantern\", \"Oasis\", \"Riot\", \"Desert\",\n  \"Blossom\", \"Prism\", \"Frequency\", \"Engine\", \"Window\", \"Ocean\", \"Kingdom\", \"Shadow\",\n  \"Feather\", \"Siren\", \"Circuit\", \"Galaxy\", \"Fireworks\", \"Starlight\", \"Hurricane\",\n  \"Diamonds\", \"Machines\", \"Petals\", \"Overdrive\", \"Dynamite\", \"Afterglow\", \"Silhouette\" }\n\nlocal VERBING = { \"Chasing\", \"Falling\", \"Running\", \"Dancing\", \"Breathing\", \"Burning\",\n  \"Waiting\", \"Drifting\", \"Floating\", \"Fading\", \"Calling\", \"Catching\", \"Counting\",\n  \"Painting\", \"Dreaming\", \"Holding\", \"Losing\", \"Building\", \"Breaking\", \"Melting\",\n  \"Racing\", \"Hunting\", \"Spinning\", \"Stealing\", \"Shaking\" }\n\nlocal SUBJECTS = { \"the last train home\", \"a city that never existed\",\n  \"finding an old voicemail\", \"the summer before everything changed\",\n  \"a robot learning to cry\", \"leaving your hometown\", \"dancing alone in the kitchen\",\n  \"a lighthouse keeper's final night\", \"two strangers on a night bus\",\n  \"the first warm day of spring\", \"an astronaut missing Earth\",\n  \"a party you weren't invited to\", \"rain on a tin roof\",\n  \"a friendship that slowly faded\", \"driving with no destination\",\n  \"the moment before a storm\", \"a message in a bottle\", \"insomnia at 4am\",\n  \"a secret garden in the middle of the city\", \"an arcade closing down for good\",\n  \"falling for someone in a dream\", \"the ocean at night\", \"a hero who gave up\",\n  \"growing up too fast\", \"a letter you never sent\", \"a festival at the end of the world\",\n  \"a ghost who just wants to dance\", \"running away to join the circus\",\n  \"a heatwave romance\", \"an empty shopping mall\", \"a chase through neon streets\",\n  \"waking up in a different decade\", \"the quiet after an argument\",\n  \"a sunrise you watched with friends\", \"a dragon guarding a vinyl collection\",\n  \"the last song at a wedding\", \"a phone call from your future self\",\n  \"a road trip in a car that keeps breaking down\", \"being the only one awake\",\n  \"a snow day when you were a kid\", \"a rivalry between two DJs\",\n  \"the view from the top of a ferris wheel\", \"a time machine with one trip left\",\n  \"a postcard from somewhere you've never been\", \"a band playing as the ship sinks\" }\n\nlocal MOODS = { \"bittersweet\", \"euphoric\", \"nostalgic\", \"anxious\", \"triumphant\",\n  \"dreamy\", \"menacing\", \"playful\", \"melancholic\", \"hopeful\", \"defiant\", \"serene\",\n  \"mysterious\", \"chaotic\", \"tender\", \"cinematic\", \"haunting\", \"carefree\", \"smug\",\n  \"desperate\", \"warm\", \"icy\", \"feverish\", \"lazy\", \"heroic\" }\n\nlocal SETTINGS = { \"in a rainy Tokyo alley\", \"on a beach at 3am\",\n  \"inside a 1980s video game\", \"on a space station orbiting Jupiter\",\n  \"in a laundrette at midnight\", \"on the last day of school\",\n  \"in a desert motel\", \"on a frozen lake\", \"in a crowded underground station\",\n  \"at a village fete\", \"in a lighthouse during a storm\", \"in a forgotten ballroom\",\n  \"on a night ferry\", \"in a greenhouse full of strange plants\", \"on a rooftop in July\",\n  \"at the edge of a volcano\", \"inside a snow globe\", \"in a 24-hour diner\" }\n\nlocal NARRATORS = { \"the moon\", \"a stray cat\", \"a retired superhero\", \"the car radio\",\n  \"the last person on Earth\", \"a lighthouse\", \"your younger self\", \"a houseplant\",\n  \"a ghost\", \"the villain\", \"an old jukebox\", \"a satellite\", \"the ocean\" }\n\nlocal TWISTS = { \"it was a dream all along\", \"the narrator is the villain\",\n  \"the final chorus is sung by someone else\", \"the love song is about a city\",\n  \"the happy melody hides sad lyrics\", \"everything happens backwards\",\n  \"the bridge reveals it was a goodbye\", \"the last line answers the first\",\n  \"the drop never comes\", \"it ends in a completely different key\" }\n\nlocal INSTRUMENTS = { \"pad\", \"pluck\", \"bass\", \"lead\", \"bell\", \"arp\", \"drone\", \"riser\",\n  \"impact\", \"texture\", \"kick\", \"snare\", \"hi-hat\", \"vocal chop\", \"stab\", \"sub bass\",\n  \"keys\", \"string section\", \"brass stab\", \"choir\", \"reese bass\", \"FX sweep\" }\n\nlocal IMAGES = { \"a frozen lake cracking\", \"sunlight through stained glass\",\n  \"a broken music box\", \"whale song underwater\", \"neon buzzing in the rain\",\n  \"an old VHS tape\", \"a spaceship engine idling\", \"wind through a canyon\",\n  \"a heartbeat in a cathedral\", \"melting chocolate\", \"a swarm of fireflies\",\n  \"a vintage radio between stations\", \"a giant's footsteps\", \"glass marbles on concrete\",\n  \"a sleepy cat's purr\", \"an alarm in a dream\", \"steam from a kettle\",\n  \"a distant thunderstorm\", \"a slot machine jackpot\", \"velvet curtains\",\n  \"a jellyfish glowing\", \"a rusty swing\", \"a robot sighing\", \"a library at night\" }\n\nlocal LIMITS = { \"a single oscillator\", \"only a sine wave\", \"only stock REAPER plugins\",\n  \"one sample you record on your phone\", \"no more than three plugins\",\n  \"only white noise as the source\", \"only your own voice\", \"only kitchen sounds\",\n  \"a synth's init preset as the starting point\", \"nothing but EQ and distortion\",\n  \"a field recording from outside your window\" }\n\nlocal MODULATIONS = { \"an LFO synced to dotted eighths\", \"velocity\", \"the mod wheel\",\n  \"a slow random LFO\", \"an envelope on the filter\", \"sidechain from the kick\",\n  \"automation drawn by hand\", \"an arpeggiator\", \"a step sequencer\" }\n\nlocal CONSTRAINTS = { \"Use only four tracks\", \"No reverb allowed\",\n  \"Every track must be panned hard left or hard right\", \"Use a time signature other than 4/4\",\n  \"No hi-hats\", \"Write the bassline first\", \"Use a sample of a household object\",\n  \"Only use one synth for everything\", \"Change key halfway through\",\n  \"Keep the tempo under 80 BPM\", \"Keep the tempo over 160 BPM\", \"No quantising\",\n  \"Use a field recording\", \"Only minor chords\", \"Write the melody with only three notes\",\n  \"Reverse something important\", \"Every section is exactly 8 bars\",\n  \"No drums for the first minute\", \"Record something live\", \"Use only stock REAPER plugins\",\n  \"Make a vocal chop the lead\", \"Sidechain everything to the kick\", \"Start with the outro\",\n  \"Make the bass the loudest thing\", \"Use a polyrhythm\", \"Mono only - no stereo widening\",\n  \"Use an instrument you've never used\", \"No EQ allowed\", \"Use 7/8 time\",\n  \"Every sound must be pitched\", \"Silence is an instrument: use a full bar of it\",\n  \"The chorus has no drums\", \"Use only one chord\" }\n\nlocal GENRES = { \"Lo-fi Hip Hop\", \"Drum & Bass\", \"Synthwave\", \"Bossa Nova\", \"Trap\",\n  \"Baroque\", \"Afrobeats\", \"Shoegaze\", \"Techno\", \"Funk\", \"Disco\", \"Jazz Fusion\",\n  \"Reggaeton\", \"Dubstep\", \"Ambient\", \"Grunge\", \"City Pop\", \"Gospel\", \"Hyperpop\",\n  \"Country\", \"K-Pop\", \"Flamenco\", \"UK Garage\", \"Phonk\", \"Vaporwave\", \"Chiptune\",\n  \"Bluegrass\", \"Metal\", \"House\", \"Soul\", \"Dancehall\", \"Jungle\", \"Trip Hop\",\n  \"Post-Rock\", \"Bollywood\", \"Sea Shanty\", \"Orchestral\", \"Garage Rock\", \"Amapiano\",\n  \"Jersey Club\", \"Drill\", \"Psytrance\", \"Neo-Soul\", \"Surf Rock\", \"Celtic\", \"Gamelan\",\n  \"Dub\", \"Grime\", \"Emo\", \"Film Noir Jazz\", \"Spaghetti Western\", \"Trance\" }\n\nlocal OCCASIONS = { \"a villain's entrance\", \"a montage of getting stronger\",\n  \"a heist going wrong\", \"the end credits\", \"a 3am drive\", \"a rooftop party\",\n  \"a boss fight\", \"a slow-motion goodbye\", \"a sunrise yoga class\", \"a chase scene\" }\n\nlocal LYRIC_LINES = {\n  \"I left my %n at the %p\", \"We were %a like %s\", \"Every %t I %v your %n\",\n  \"Don't call me when the %n %vs\", \"Tell me why the %n still %vs\",\n  \"You and me and the %a %n\", \"Somewhere between the %n and the %n\",\n  \"I kept your %n in a %a box\", \"We drove all night to find the %n\",\n  \"Nobody told me the %n would %v\", \"Under the %a %n we %vd\",\n  \"I've been %ving since the %n went out\", \"Turn up the %n, I can't hear the %n\" }\n-- Singular, so \"the %n still %vs\" agrees with itself.\nlocal LYRIC_NOUNS = { \"harbour\", \"satellite\", \"horizon\", \"mirror\", \"heartbeat\", \"daydream\",\n  \"lighthouse\", \"signal\", \"motel\", \"arcade\", \"polaroid\", \"cathedral\", \"comet\", \"carousel\",\n  \"sunrise\", \"freeway\", \"postcard\", \"wildfire\", \"lullaby\", \"rooftop\", \"cassette\", \"lantern\",\n  \"radio\", \"streetlight\", \"ocean\", \"kingdom\", \"shadow\", \"feather\", \"siren\", \"galaxy\", \"engine\" }\nlocal LYRIC_PLACES = { \"station\", \"party\", \"end of the road\", \"edge of town\", \"bottom of the sea\",\n  \"back of the bus\", \"top of the world\", \"corner shop\", \"last chance saloon\", \"door\" }\nlocal SIMILES = { \"neon in the rain\", \"kids on a sugar rush\", \"satellites in love\",\n  \"fireworks in winter\", \"strangers at a wedding\", \"ghosts at a disco\",\n  \"candles in a hurricane\", \"records on repeat\" }\nlocal VERBS = { { \"glow\", \"glows\", \"glowed\", \"glowing\" }, { \"break\", \"breaks\", \"broke\", \"breaking\" },\n  { \"sing\", \"sings\", \"sang\", \"singing\" }, { \"wait\", \"waits\", \"waited\", \"waiting\" },\n  { \"burn\", \"burns\", \"burned\", \"burning\" }, { \"fall\", \"falls\", \"fell\", \"falling\" },\n  { \"shine\", \"shines\", \"shone\", \"shining\" }, { \"fade\", \"fades\", \"faded\", \"fading\" },\n  { \"run\", \"runs\", \"ran\", \"running\" }, { \"dance\", \"dances\", \"danced\", \"dancing\" } }\nlocal TIMES = { \"night\", \"summer\", \"morning\", \"winter\", \"weekend\", \"December\", \"Sunday\" }\n\nlocal ALIAS_PATTERNS = { \"%A %N\", \"DJ %N\", \"Lil %N\", \"The %A %P\", \"%N & The %P\",\n  \"MC %A\", \"%N Collective\", \"%A%n\", \"Club %N\", \"%N Theory\", \"Sister %N\", \"Kid %N\" }\n\nlocal TITLE_ADJ = { \"Cosmic\", \"Supreme\", \"Midnight\", \"Funky\", \"Certified\", \"Grand\",\n  \"Turbo\", \"Mystic\", \"Undisputed\", \"Feral\", \"Golden\", \"Elusive\", \"Chaotic\", \"Serene\",\n  \"Iron\", \"Velvet\", \"Low-End\", \"Hi-Fi\", \"Lo-Fi\", \"Analogue\", \"Quantised\", \"Unquantised\",\n  \"Sleepless\", \"Legendary\", \"Tireless\", \"Humble\", \"Infamous\", \"Wandering\" }\nlocal TITLE_ROLE = { \"Beatsmith\", \"Loop Alchemist\", \"Knob Twister\", \"Groove Wizard\",\n  \"Sample Pirate\", \"Bass Baron\", \"Synth Sorcerer\", \"Mix Monk\", \"Chord Captain\",\n  \"Fader Ninja\", \"Snare Whisperer\", \"Reverb Druid\", \"Tempo Titan\", \"Hook Hunter\",\n  \"Riff Ranger\", \"Sidechain Sultan\", \"Drum Shaman\", \"Arp Architect\", \"Vocal Viking\",\n  \"Melody Merchant\", \"Patch Sculptor\", \"Groove Gardener\", \"Noise Knight\" }\nlocal TITLE_OF = { \"the Night\", \"the Low End\", \"the Infinite Loop\", \"the Final Mixdown\",\n  \"the Golden Ratio\", \"the Eighth Note\", \"the Last Bar\", \"Many Plugins\", \"the Downbeat\",\n  \"the Big Room\", \"the Upside Down\", \"the Sustain Pedal\" }\n\nlocal COLOUR_WORDS = { \"Neon\", \"Midnight\", \"Solar\", \"Arctic\", \"Toxic\", \"Royal\", \"Sunset\",\n  \"Deep\", \"Electric\", \"Cyber\", \"Pastel\", \"Molten\", \"Velvet\", \"Retro\", \"Lunar\", \"Ember\" }\nlocal BANNER_THINGS = { \"Lion\", \"Comet\", \"Fox\", \"Wave\", \"Crown\", \"Serpent\", \"Phoenix\",\n  \"Owl\", \"Wolf\", \"Tiger\", \"Moth\", \"Crow\", \"Stag\", \"Kraken\", \"Dragon\", \"Meteor\" }\n\n-- Syllables for the made-up names Legendary and Mythic gear carries.\nlocal SYL_A = { \"Kal\", \"Mor\", \"Ae\", \"Vel\", \"Zan\", \"Or\", \"Thal\", \"Ys\", \"Bel\", \"Cor\",\n  \"Dra\", \"Ely\", \"Fen\", \"Gal\", \"Hal\", \"Ith\", \"Jor\", \"Lys\", \"Nyx\", \"Quin\", \"Ser\", \"Tor\" }\nlocal SYL_B = { \"dor\", \"ion\", \"ara\", \"eth\", \"iel\", \"os\", \"an\", \"ix\", \"umb\", \"ira\",\n  \"ond\", \"ael\", \"ash\", \"or\", \"ys\", \"ene\", \"ul\", \"ath\" }\nlocal EPITHETS = { \"Breaker of Silence\", \"Keeper of the Groove\", \"the Unquantised\",\n  \"Voice of the Void\", \"Bringer of Drops\", \"the Eternal Loop\", \"Heart of the Mix\",\n  \"the Last Encore\", \"Lord of Low End\", \"the Golden Ear\", \"Herald of the Hook\" }\n\nL.WORDS = { ADJ = ADJ, NOUN = NOUN, GENRES = GENRES, CONSTRAINTS = CONSTRAINTS }\n\nlocal function madeUpName(rnd)\n  local n = pickOne(rnd, SYL_A) .. pickOne(rnd, SYL_B)\n  if chance(rnd, 0.3) then n = n .. pickOne(rnd, SYL_B) end\n  return n\nend\n\n------------------------------------------------------------------------------\n-- Ideas\n--\n-- Each kind makes { text, sub, data } for a rarity. A rarer idea is a richer\n-- one: more chords, sevenths, borrowed chords, more bars, more parts to the\n-- brief. Poor ideas are the grey junk of the loot table, and know it.\n------------------------------------------------------------------------------\n\nlocal IDEAS = {}\nL.IDEAS = IDEAS\n\nlocal function idea(def) IDEAS[#IDEAS + 1] = def; IDEAS[def.id] = def end\n\nidea { id = \"title\", label = \"Song Title\", icon = \"note\", weight = 9,\n  make = function(rnd, r)\n    if r == L.POOR then\n      return { text = \"Untitled \" .. pickOne(rnd, { \"Beat\", \"Project\", \"Loop\", \"Idea\" }) .. \" \" .. between(rnd, 2, 99),\n               sub = \"A song title. Technically.\" }\n    end\n    local t\n    local pat = between(rnd, 1, math.min(r, 6))\n    if pat <= 2 then\n      t = chance(rnd, 0.6) and (pickOne(rnd, ADJ) .. \" \" .. pickOne(rnd, NOUN))\n          or (pickOne(rnd, NOUN) .. \" \" .. pickOne(rnd, NOUN))\n    elseif pat == 3 then t = pickOne(rnd, VERBING) .. \" \" .. pickOne(rnd, NOUN)\n    elseif pat == 4 then t = pickOne(rnd, NOUN) .. \" of \" .. pickOne(rnd, NOUN)\n    elseif pat == 5 then t = \"The \" .. pickOne(rnd, ADJ) .. \" \" .. pickOne(rnd, NOUN)\n    else t = pickOne(rnd, ADJ) .. \" \" .. pickOne(rnd, NOUN) .. \" \" .. pickOne(rnd, NOUN) end\n    local sub = \"A song title\"\n    if r >= L.LEGENDARY then sub = \"B-side: \" .. pickOne(rnd, ADJ) .. \" \" .. pickOne(rnd, NOUN) end\n    if r == L.MYTHIC then sub = \"Album: \" .. pickOne(rnd, NOUN) .. \" \" .. pickOne(rnd, NOUN) .. \"  /  \" .. sub end\n    return { text = t, sub = sub }\n  end }\n\nidea { id = \"theme\", label = \"Song Theme\", icon = \"bulb\", weight = 8,\n  make = function(rnd, r)\n    if r == L.POOR then return { text = \"A song about making a song.\", sub = \"Very meta. Very grey.\" } end\n    local mood = pickOne(rnd, MOODS)\n    local t = (r >= L.UNCOMMON and (\"A \" .. mood .. \" song about \") or \"A song about \") .. pickOne(rnd, SUBJECTS) .. \".\"\n    local sub = {}\n    if r < L.UNCOMMON then sub[#sub + 1] = \"Mood: \" .. mood end\n    if r >= L.RARE then sub[#sub + 1] = \"Set \" .. pickOne(rnd, SETTINGS) end\n    if r >= L.EPIC then sub[#sub + 1] = \"Told by \" .. pickOne(rnd, NARRATORS) end\n    if r >= L.LEGENDARY then sub[#sub + 1] = \"Twist: \" .. pickOne(rnd, TWISTS) end\n    if r >= L.MYTHIC then sub[#sub + 1] = \"Title: \" .. pickOne(rnd, ADJ) .. \" \" .. pickOne(rnd, NOUN) end\n    return { text = articles(t), sub = table.concat(sub, \". \") }\n  end }\n\n-- Chords ---------------------------------------------------------------------\n\n-- Progressions by 0-based degree, the ones everyone knows first.\nlocal MAJOR_PROGS = { { 0, 4, 5, 3 }, { 5, 3, 0, 4 }, { 0, 5, 3, 4 }, { 1, 4, 0, 0 },\n  { 0, 3, 5, 4 }, { 0, 2, 3, 3 }, { 3, 0, 4, 5 }, { 0, 4, 3, 3 }, { 0, 3, 0, 4 },\n  { 5, 4, 3, 4 }, { 0, 1, 3, 0 }, { 3, 4, 2, 5 } }\nlocal MINOR_PROGS = { { 0, 5, 2, 6 }, { 0, 3, 6, 2 }, { 0, 6, 5, 6 }, { 0, 5, 6, 0 },\n  { 0, 3, 4, 0 }, { 0, 2, 6, 5 }, { 3, 5, 0, 6 }, { 0, 6, 5, 4 }, { 0, 3, 0, 4 } }\n-- Which degree may follow which: tonic anywhere, predominants to dominants,\n-- dominants home. The walk for rarer progressions, so they are still music.\nlocal NEXT = { [0] = { 3, 4, 5, 1, 2 }, [1] = { 4, 6, 3 }, [2] = { 5, 3, 1 },\n  [3] = { 4, 0, 1, 6 }, [4] = { 0, 5, 3 }, [5] = { 1, 3, 4, 2 }, [6] = { 0, 2, 5 } }\n\nlocal LETTER_PC = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }\nlocal LETTER_ORDER = { \"C\", \"D\", \"E\", \"F\", \"G\", \"A\", \"B\" }\n-- A pitch class spelled on a given letter: the fifth above D is A, the fifth\n-- above Bb is F, and a V/V in Eb is F7, not E#7.\nlocal function spell(letter, pc)\n  local acc = (pc - LETTER_PC[letter]) % 12\n  if acc > 6 then acc = acc - 12 end\n  -- A double flat or sharp is right by the letter and wrong for a reader.\n  if acc < -1 or acc > 1 then return L.T.ROOTS[L.T.rootFor(pc)].name end\n  return letter .. (acc == -1 and \"b\" or (acc == 1 and \"#\" or \"\"))\nend\nlocal function letterUp(letter, steps)\n  for i, l in ipairs(LETTER_ORDER) do\n    if l == letter then return LETTER_ORDER[(i - 1 + steps) % 7 + 1] end\n  end\n  return letter\nend\n\nlocal function chordSym(pcs, root)\n  return L.T.symbolOf(pcs, root) or \"\"\nend\n\n-- Close voicings around middle C, each chord the inversion nearest the last.\nlocal function voice(pcs, prevMean)\n  local best, bestCost\n  for inv = 0, #pcs - 1 do\n    local notes, last = {}, nil\n    for i = 0, #pcs - 1 do\n      local pc = pcs[(inv + i) % #pcs + 1]\n      local p = 48 + pc\n      while last and p <= last do p = p + 12 end\n      while not last and p < 52 do p = p + 12 end\n      notes[#notes + 1] = p\n      last = p\n    end\n    local mean = 0\n    for _, p in ipairs(notes) do mean = mean + p end\n    mean = mean / #notes\n    local cost = math.abs(mean - (prevMean or 62))\n    if notes[#notes] > 79 then cost = cost + 20 end\n    if not bestCost or cost < bestCost then best, bestCost = notes, cost end\n  end\n  local mean = 0\n  for _, p in ipairs(best) do mean = mean + p end\n  return best, mean / #best\nend\n\n-- A key on a pitch class, spelled the way that gives its scale the fewest\n-- sharps and flats - Good Idea's rule (T.transpose there): Ab Phrygian\n-- would need Bbb and Fb, so it is G# Phrygian.\nlocal function keyFor(pc, scaleIdx)\n  local T = L.T\n  local best, bestCost\n  for i, rt in ipairs(T.ROOTS) do\n    local k = T.key(i, scaleIdx)\n    if T.rootPc(k) == pc % 12 then\n      local cost = 0\n      for pos = 0, T.scaleLen(k) - 1 do\n        local name = T.noteName(k, pos)\n        cost = cost + #name - 1\n        if name:find(\"bb\") or name:find(\"x\") then cost = cost + 10 end\n      end\n      if not bestCost or cost < bestCost then best, bestCost = k, cost end\n    end\n  end\n  return best\nend\nL.keyFor = keyFor\n\nlocal function scaleByWeight(rnd, r)\n  if r <= L.COMMON then return pickOne(rnd, { \"Major\", \"Minor\" }) end\n  return weighted(rnd, (function()\n    local t = {}\n    for _, s in ipairs(L.T.REWARD_SCALES) do t[#t + 1] = { s[2], s[1] } end\n    return t\n  end)())\nend\n\nfunction L.progression(rnd, r)\n  local T = L.T\n  local scaleName = scaleByWeight(rnd, r)\n  local key = keyFor(between(rnd, 0, 11), T.scaleIndex(scaleName))\n  local minorish = T.degreeQuality(key, 0) == \"minor\"\n  local count = (r >= L.LEGENDARY) and 8 or ((r >= L.EPIC) and 6 or 4)\n  local degrees = {}\n  if r <= L.UNCOMMON or chance(rnd, 0.5) then\n    local base = pickOne(rnd, minorish and MINOR_PROGS or MAJOR_PROGS)\n    if r == L.POOR then base = minorish and { 0, 3, 4, 0 } or { 0, 3, 4, 0 } end\n    for i = 1, count do degrees[i] = base[(i - 1) % 4 + 1] end\n    if count > 4 then degrees[count] = 0; degrees[count - 1] = 4 end\n  else\n    degrees[1] = 0\n    for i = 2, count do degrees[i] = pickOne(rnd, NEXT[degrees[i - 1]]) end\n    degrees[count - 1] = (degrees[count - 2] == 4) and 3 or 4\n    degrees[count] = 0\n  end\n  local sevenths = r >= L.EPIC or (r == L.RARE and chance(rnd, 0.5))\n  local chords = {}\n  for i, d in ipairs(degrees) do\n    local c = T.degreeChord(key, d, sevenths or (r == L.UNCOMMON and d == 4))\n    c.degree = d\n    chords[i] = c\n  end\n  -- Borrowed from the parallel key: the iv, bVI and bVII in major, the major\n  -- IV and V in minor. Never the first chord or the last.\n  if r >= L.EPIC and T.scaleLen(key) == 7 then\n    local parallel = T.key(key.root, T.scaleIndex(minorish and \"Major\" or \"Minor\"))\n    local tries = minorish and { 3, 4 } or { 3, 5, 6 }\n    local slot = between(rnd, 2, count - 1)\n    local d = pickOne(rnd, tries)\n    local c = T.degreeChord(parallel, d, sevenths)\n    local diatonic = T.pitch(key, d) % 12\n    local acc = \"\"\n    if (c.root % 12) ~= diatonic then acc = ((c.root - diatonic) % 12 == 11) and \"b\" or \"#\" end\n    c.numeral = acc .. T.degreeNumeral(parallel, d)\n    if c.name:find(\"bb\") or c.name:find(\"x\") then\n      -- Db major's bVI is Bbb by the letter; nobody reads it that way.\n      c.name = T.ROOTS[T.rootFor(c.root % 12)].name .. (c.name:gsub(\"^[A-G][#bx]*\", \"\"))\n    end\n    c.borrowed = true\n    c.degree = d\n    chords[slot] = c\n  end\n  -- A secondary dominant: the chord before a major or minor chord becomes its\n  -- V7, spelled a fifth up on the letter.\n  if r >= L.LEGENDARY then\n    for i = 3, count - 1 do\n      local target = chords[i]\n      if not target.borrowed and target.degree ~= 0 and not chords[i - 1].borrowed\n         and T.degreeQuality(key, target.degree) ~= \"diminished\" then\n        local rootPc = (target.root + 7) % 12\n        local letter = letterUp(target.name:sub(1, 1), 4)\n        local pcs = { rootPc, (rootPc + 4) % 12, (rootPc + 7) % 12, (rootPc + 10) % 12 }\n        chords[i - 1] = { root = rootPc, pcs = pcs, name = spell(letter, rootPc) .. \"7\",\n                          numeral = \"V7/\" .. target.numeral, applied = true, degree = -1 }\n        break\n      end\n    end\n  end\n  -- Colour: an add9 or a sus on a plain major triad.\n  if r >= L.LEGENDARY then\n    for i = 2, count - 1 do\n      local c = chords[i]\n      if #c.pcs == 3 and not c.applied and chance(rnd, 0.35) then\n        local third = (c.pcs[2] - c.pcs[1]) % 12\n        if third == 4 then\n          local sus = chance(rnd, 0.5)\n          local pcs = sus and { c.pcs[1], (c.pcs[1] + 5) % 12, c.pcs[3] } or { c.pcs[1], c.pcs[2], c.pcs[3], (c.pcs[1] + 2) % 12 }\n          local letterName = c.name:match(\"^[A-G][#bx]*\")\n          chords[i] = { root = c.root, pcs = pcs, name = letterName .. (sus and \"sus4\" or \"add9\"),\n                        numeral = c.numeral .. (sus and \"sus4\" or \"add9\"), degree = c.degree, borrowed = c.borrowed }\n        end\n      end\n    end\n  end\n  -- Mythic: the second half goes up a whole step.\n  local modulated = false\n  if r == L.MYTHIC then\n    modulated = true\n    local half = count / 2\n    for i = half + 1, count do\n      local c = chords[i]\n      local pcs = {}\n      for j, pc in ipairs(c.pcs) do pcs[j] = (pc + 2) % 12 end\n      local letterName = c.name:match(\"^([A-G])\")\n      local rest = c.name:gsub(\"^[A-G][#bx]*\", \"\")\n      chords[i] = { root = (c.root + 2) % 12, pcs = pcs, name = spell(letterUp(letterName, 1), (c.root + 2) % 12) .. rest,\n                    numeral = c.numeral, degree = c.degree, lifted = true }\n    end\n  end\n  for _, c in ipairs(chords) do c.sym = chordSym(c.pcs, c.pcs[1]) end\n  return { key = key, keyName = T.noteName(key, 0) .. \" \" .. T.SCALES[key.scale].name,\n           chords = chords, modulated = modulated }\nend\n\nlocal function progressionBlock(p, name)\n  local notes, prevMean = {}, nil\n  for i, c in ipairs(p.chords) do\n    local s = (i - 1) * 4\n    local vs\n    vs, prevMean = voice(c.pcs, prevMean)\n    for _, pitch in ipairs(vs) do notes[#notes + 1] = { start = s, len = 4, pitch = pitch, vel = 90 } end\n    notes[#notes + 1] = { start = s, len = 4, pitch = 36 + (c.root % 12), vel = 100 }\n  end\n  return { name = name, beats = #p.chords * 4, notes = notes }\nend\n\nidea { id = \"chords\", label = \"Chord Progression\", icon = \"keys\", weight = 9, midi = true,\n  make = function(rnd, r)\n    local p = L.progression(rnd, r)\n    local names, nums = {}, {}\n    for i, c in ipairs(p.chords) do names[i] = c.name; nums[i] = c.numeral end\n    local sub = p.keyName .. \"  /  \" .. table.concat(nums, \" - \")\n    if p.modulated then sub = sub .. \"  (up a tone halfway)\" end\n    if r == L.POOR then sub = sub .. \"  /  A classic. Some say too classic.\" end\n    return { text = table.concat(names, \" - \"), sub = sub,\n             data = { block = progressionBlock(p, \"Chords: \" .. table.concat(names, \" \")) } }\n  end }\n\n-- Drums ----------------------------------------------------------------------\n\nlocal GM = { kick = 36, rim = 37, snare = 38, clap = 39, chh = 42, ohh = 46, ltom = 45,\n             htom = 50, crash = 49, ride = 51, cowbell = 56, shaker = 70 }\n\n-- Sixteen steps a bar: x is a hit, o a ghost (soft) hit.\nlocal DRUM_STYLES = {\n  { name = \"House\", bpm = { 120, 128 }, swing = 0, rows = {\n      kick = \"x...x...x...x...\", clap = \"....x.......x...\", chh = \"..x...x...x...x.\", ohh = \"......x.......x.\" } },\n  { name = \"Boom Bap\", bpm = { 84, 96 }, swing = 58, rows = {\n      kick = \"x......x..x.....\", snare = \"....x.......x...\", chh = \"x.x.x.x.x.x.x.x.\" } },\n  { name = \"Trap\", bpm = { 130, 150 }, swing = 0, rows = {\n      kick = \"x......x..x....x\", snare = \"........x.......\", chh = \"x.xxx.x.x.xxx.xx\" } },\n  { name = \"Drum & Bass\", bpm = { 170, 176 }, swing = 0, rows = {\n      kick = \"x.........x.....\", snare = \"....x.......x...\", chh = \"x.x.x.x.x.x.x.x.\" } },\n  { name = \"Reggaeton\", bpm = { 90, 100 }, swing = 0, rows = {\n      kick = \"x...x...x...x...\", snare = \"...x..x....x..x.\", chh = \"x.x.x.x.x.x.x.x.\" } },\n  { name = \"Lo-fi\", bpm = { 70, 88 }, swing = 62, rows = {\n      kick = \"x..x......x.....\", snare = \"....x.......x...\", chh = \"x.x.x.x.x.x.x.x.\", rim = \"..........o.....\" } },\n  { name = \"Techno\", bpm = { 128, 140 }, swing = 0, rows = {\n      kick = \"x...x...x...x...\", clap = \"....x.......x...\", chh = \"xxxxxxxxxxxxxxxx\", ohh = \"..x...x...x...x.\" } },\n  { name = \"Funk\", bpm = { 98, 112 }, swing = 54, rows = {\n      kick = \"x.x.......x..x..\", snare = \"....x..o.o..x..o\", chh = \"x.x.x.x.x.x.x.x.\" } },\n  { name = \"UK Garage\", bpm = { 130, 136 }, swing = 66, rows = {\n      kick = \"x.........x.....\", snare = \"....x.......x...\", chh = \"..x...x...x...xx\", rim = \".......o......o.\" } },\n  { name = \"Afrobeats\", bpm = { 100, 112 }, swing = 55, rows = {\n      kick = \"x..x..x...x..x..\", rim = \"...x..x....x..x.\", shaker = \"xxxxxxxxxxxxxxxx\", clap = \"....x.......x...\" } },\n}\nL.DRUM_STYLES = DRUM_STYLES\nlocal ROW_ORDER = { \"kick\", \"snare\", \"clap\", \"rim\", \"chh\", \"ohh\", \"shaker\", \"cowbell\", \"ltom\", \"htom\", \"crash\", \"ride\" }\nlocal ROW_NAMES = { kick = \"Kick\", snare = \"Snare\", clap = \"Clap\", rim = \"Rim\", chh = \"Hat\", ohh = \"Open hat\",\n  shaker = \"Shaker\", cowbell = \"Cowbell\", ltom = \"Low tom\", htom = \"High tom\", crash = \"Crash\", ride = \"Ride\" }\n\nfunction L.drumPattern(rnd, r)\n  local style = pickOne(rnd, DRUM_STYLES)\n  local bars = (r >= L.LEGENDARY) and 4 or ((r >= L.EPIC) and 2 or 1)\n  local steps = bars * 16\n  local rows = {}\n  local function row(id)\n    if not rows[id] then rows[id] = {}; for i = 1, steps do rows[id][i] = 0 end end\n    return rows[id]\n  end\n  for id, s in pairs(style.rows) do\n    local rr = row(id)\n    for b = 0, bars - 1 do\n      for i = 1, 16 do\n        local ch = s:sub(i, i)\n        if ch == \"x\" then rr[b * 16 + i] = (i % 4 == 1) and 110 or 96\n        elseif ch == \"o\" then rr[b * 16 + i] = 50 end\n      end\n    end\n  end\n  -- Variations, more of them the rarer the pattern.\n  local changes = ({ 0, 1, 2, 3, 4, 5, 6 })[r]\n  for _ = 1, changes do\n    local what = between(rnd, 1, 4)\n    local i = between(rnd, 1, steps)\n    if what == 1 then row(\"kick\")[i] = (row(\"kick\")[i] > 0 and i % 16 ~= 1) and 0 or 92\n    elseif what == 2 and rows.snare then if rows.snare[i] == 0 then rows.snare[i] = 45 end\n    elseif what == 3 and rows.chh then rows.chh[i] = (rows.chh[i] > 0) and 0 or 70\n    else row(\"ohh\")[i] = (i % 2 == 1) and 0 or 85 end\n  end\n  if r >= L.EPIC then\n    -- A fill at the end of the last bar, and a crash on the way back in.\n    local t = row(chance(rnd, 0.5) and \"htom\" or \"snare\")\n    local lt = row(\"ltom\")\n    for i = steps - 3, steps do\n      if rows.kick then rows.kick[i] = 0 end\n      if i % 2 == 0 then t[i] = 100 else lt[i] = 100 end\n    end\n    row(\"crash\")[1] = 115\n  end\n  if r >= L.MYTHIC then\n    -- Three against four: a cowbell every three sixteenths.\n    local cb = row(\"cowbell\")\n    for i = 1, steps, 3 do cb[i] = 80 end\n  end\n  local bpm = between(rnd, style.bpm[1], style.bpm[2])\n  local list = {}\n  for _, id in ipairs(ROW_ORDER) do\n    if rows[id] then\n      local any = false\n      for i = 1, steps do if rows[id][i] > 0 then any = true end end\n      if any then list[#list + 1] = { id = id, name = ROW_NAMES[id], note = GM[id], steps = rows[id] } end\n    end\n  end\n  return { style = style.name, bpm = bpm, bars = bars, steps = steps, swing = style.swing, rows = list }\nend\n\nfunction L.drumBlock(p, name)\n  local notes = {}\n  for _, row in ipairs(p.rows) do\n    for i, v in ipairs(row.steps) do\n      if v > 0 then\n        local pairStart = math.floor((i - 1) / 2) * 0.5\n        local start = (i % 2 == 1) and pairStart\n                      or (pairStart + 0.5 * (p.swing > 0 and p.swing / 100 or 0.5))\n        -- A swung last sixteenth is shortened to end with the pattern.\n        local len = math.min(0.2, p.bars * 4 - start)\n        notes[#notes + 1] = { start = start, len = len, pitch = row.note, vel = v }\n      end\n    end\n  end\n  return { name = name, beats = p.bars * 4, notes = notes }\nend\n\nfunction L.drumText(p)\n  local lines = {}\n  for _, row in ipairs(p.rows) do\n    local s = {}\n    for i = 1, math.min(16, p.steps) do s[i] = row.steps[i] > 60 and \"x\" or (row.steps[i] > 0 and \"o\" or \".\") end\n    lines[#lines + 1] = string.format(\"%-8s %s\", row.name, table.concat(s))\n  end\n  return table.concat(lines, \"\\n\")\nend\n\nidea { id = \"drums\", label = \"Drum Pattern\", icon = \"drum\", weight = 7, midi = true,\n  make = function(rnd, r)\n    local p = L.drumPattern(rnd, r)\n    local sub = string.format(\"%d BPM  /  %d bar%s%s\", p.bpm, p.bars, p.bars > 1 and \"s\" or \"\",\n                              p.swing > 0 and (\"  /  swing \" .. p.swing .. \"%\") or \"\")\n    if r == L.POOR then sub = sub .. \"  /  It's a beat.\" end\n    return { text = p.style .. \" beat\", sub = sub,\n             data = { drums = p, block = L.drumBlock(p, \"Drums: \" .. p.style), text = L.drumText(p), bpm = p.bpm } }\n  end }\n\n-- Melody ---------------------------------------------------------------------\n\nlocal CELLS = { { 4 }, { 2, 2 }, { 3, 1 }, { 1, 1, 2 }, { 2, 1, 1 }, { 2, 2 }, { -2, 2 }, { 1, 1, 1, 1 }, { 4 }, { 6, 2 }, { 8 } }\nlocal STEPS = { { 1, 0 }, { 7, 1 }, { 7, -1 }, { 3, 2 }, { 3, -2 }, { 1, 3 }, { 1, -3 }, { 1, 4 }, { 1, -4 } }\n\nfunction L.melody(rnd, r)\n  local T = L.T\n  local scaleName = (r <= L.COMMON) and pickOne(rnd, { \"Maj Pent\", \"Min Pent\" }) or scaleByWeight(rnd, r)\n  local key = keyFor(between(rnd, 0, 11), T.scaleIndex(scaleName))\n  local n = T.scaleLen(key)\n  local bars = (r >= L.EPIC) and 4 or ((r >= L.UNCOMMON) and 2 or 1)\n  local base = 5 * n     -- the root in the octave of middle C\n  local notes, t, pos = {}, 0, pickOne(rnd, { 0, 2, 4 }) % n\n  local function phrase(len)\n    local out, at = {}, 0\n    while at < len do\n      local cell = pickOne(rnd, CELLS)\n      local total = 0\n      for _, d in ipairs(cell) do total = total + math.abs(d) end\n      if at + total > len then cell = { len - at } end\n      for _, d in ipairs(cell) do\n        if d > 0 then\n          out[#out + 1] = { s = at, l = d, pos = pos }\n          pos = math.max(-2, math.min(n + 4, pos + weighted(rnd, STEPS)))\n        end\n        at = at + math.abs(d)\n      end\n    end\n    return out\n  end\n  local first = phrase(math.min(bars, 2) * 16)\n  for _, x in ipairs(first) do notes[#notes + 1] = x end\n  if bars == 4 then\n    -- Call and answer: the second half starts like the first and ends home.\n    for i, x in ipairs(first) do\n      if x.s < 16 then notes[#notes + 1] = { s = x.s + 32, l = x.l, pos = x.pos }\n      else notes[#notes + 1] = { s = x.s + 32, l = x.l, pos = (i % 2 == 0) and x.pos + 1 or x.pos } end\n    end\n  end\n  table.sort(notes, function(a, b) return a.s < b.s end)\n  -- End on the key note, held.\n  local last = notes[#notes]\n  last.pos = (last.pos >= n / 2) and n or 0\n  t = 0\n  local names, block = {}, {}\n  local barNames = {}\n  for _, x in ipairs(notes) do\n    local bar = math.floor(x.s / 16) + 1\n    barNames[bar] = barNames[bar] or {}\n    table.insert(barNames[bar], T.noteName(key, x.pos % n))\n    block[#block + 1] = { start = x.s / 4, len = x.l / 4 * 0.95, pitch = T.pitch(key, base + x.pos), vel = 100 }\n  end\n  for b = 1, bars do names[#names + 1] = table.concat(barNames[b] or { \"-\" }, \" \") end\n  return { key = key, keyName = T.noteName(key, 0) .. \" \" .. T.SCALES[key.scale].name,\n           bars = bars, text = table.concat(names, \" | \"), notes = block }\nend\n\nidea { id = \"melody\", label = \"Melody\", icon = \"wave\", weight = 7, midi = true,\n  make = function(rnd, r)\n    local m = L.melody(rnd, r)\n    local sub = m.keyName .. \"  /  \" .. m.bars .. \" bar\" .. (m.bars > 1 and \"s\" or \"\")\n    return { text = m.text, sub = sub,\n             data = { block = { name = \"Melody: \" .. m.keyName, beats = m.bars * 4, notes = m.notes } } }\n  end }\n\n-- Words ----------------------------------------------------------------------\n\nidea { id = \"sound\", label = \"Sound Design Brief\", icon = \"dial\", weight = 6,\n  make = function(rnd, r)\n    local t = articles(\"Design a \" .. pickOne(rnd, INSTRUMENTS) .. \" that sounds like \" .. pickOne(rnd, IMAGES) .. \".\")\n    local sub = {}\n    if r >= L.RARE then sub[#sub + 1] = \"Use \" .. pickOne(rnd, LIMITS) end\n    if r >= L.EPIC then sub[#sub + 1] = \"Modulate it with \" .. pickOne(rnd, MODULATIONS) end\n    if r >= L.MYTHIC then sub[#sub + 1] = \"Make it evolve over 16 bars\" end\n    if r == L.POOR then sub[#sub + 1] = \"Or just pick a preset. No judgement.\" end\n    return { text = t, sub = table.concat(sub, \". \") }\n  end }\n\nidea { id = \"challenge\", label = \"Challenge\", icon = \"flag\", weight = 6,\n  make = function(rnd, r)\n    local n = (r >= L.LEGENDARY) and 3 or ((r >= L.RARE) and 2 or 1)\n    local picks = shuffled(rnd, CONSTRAINTS)\n    local list = {}\n    for i = 1, n do list[i] = picks[i] end\n    local sub = (r >= L.EPIC) and (\"Finish a loop in \" .. pickOne(rnd, { 20, 30, 45, 60 }) .. \" minutes\") or \"Try it on your next idea\"\n    if r == L.POOR then sub = \"Optional. Very optional.\" end\n    return { text = table.concat(list, \". \") .. \".\", sub = sub }\n  end }\n\nidea { id = \"fusion\", label = \"Genre Fusion\", icon = \"atom\", weight = 6,\n  make = function(rnd, r)\n    local picks = shuffled(rnd, GENRES)\n    local n = (r >= L.EPIC) and 3 or 2\n    local list = {}\n    for i = 1, n do list[i] = picks[i] end\n    local sub = \"at \" .. between(rnd, 70, 175) .. \" BPM\"\n    if r >= L.LEGENDARY then sub = sub .. \", for \" .. pickOne(rnd, OCCASIONS) end\n    return { text = table.concat(list, \" x \"), sub = sub }\n  end }\n\nidea { id = \"alias\", label = \"Artist Alias\", icon = \"mask\", weight = 4,\n  make = function(rnd, r)\n    local function one()\n      local p = pickOne(rnd, ALIAS_PATTERNS)\n      p = p:gsub(\"%%A\", function() return pickOne(rnd, ADJ) end)\n      p = p:gsub(\"%%N\", function() return pickOne(rnd, NOUN) end)\n      p = p:gsub(\"%%P\", function() return plural(pickOne(rnd, NOUN)) end)\n      p = p:gsub(\"%%n\", function() return pickOne(rnd, NOUN):lower() end)\n      return p\n    end\n    local sub = \"Your next side project\"\n    if r >= L.EPIC then sub = \"a.k.a. \" .. one() end\n    if r == L.POOR then return { text = \"DJ \" .. pickOne(rnd, { \"Laptop\", \"Default\", \"Preset\", \"Untitled\" }), sub = \"It's a start.\" } end\n    return { text = one(), sub = sub }\n  end }\n\nidea { id = \"lyric\", label = \"Lyric Opener\", icon = \"mic\", weight = 6,\n  make = function(rnd, r)\n    local function line()\n      local v = pickOne(rnd, VERBS)\n      local s = pickOne(rnd, LYRIC_LINES)\n      s = s:gsub(\"%%vs\", v[2]):gsub(\"%%vd\", v[3]):gsub(\"%%ving\", v[4]):gsub(\"%%v\", v[1])\n      s = s:gsub(\"%%n\", function() return pickOne(rnd, LYRIC_NOUNS) end)\n      s = s:gsub(\"%%a\", function() return pickOne(rnd, ADJ):lower() end)\n      s = s:gsub(\"%%p\", function() return pickOne(rnd, LYRIC_PLACES) end)\n      s = s:gsub(\"%%s\", function() return pickOne(rnd, SIMILES) end)\n      s = s:gsub(\"%%t\", function() return pickOne(rnd, TIMES) end)\n      return articles(s)\n    end\n    local t = \"\\\"\" .. line() .. \"\\\"\"\n    local sub = { \"Write the next three lines\" }\n    if r >= L.RARE then sub[1] = \"Rhyme the next line with \\\"\" .. pickOne(rnd, LYRIC_NOUNS) .. \"\\\"\" end\n    if r >= L.EPIC then sub[#sub + 1] = \"Hook: \\\"\" .. line() .. \"\\\"\" end\n    if r >= L.MYTHIC then sub[#sub + 1] = \"Bridge: \\\"\" .. line() .. \"\\\"\" end\n    return { text = t, sub = table.concat(sub, \". \") }\n  end }\n\nlocal SECTION_SETS = {\n  { { \"Intro\", 8 }, { \"Verse\", 16 }, { \"Chorus\", 8 }, { \"Verse\", 16 }, { \"Chorus\", 8 }, { \"Bridge\", 8 }, { \"Chorus\", 16 }, { \"Outro\", 8 } },\n  { { \"Intro\", 16 }, { \"Build\", 8 }, { \"Drop\", 16 }, { \"Break\", 16 }, { \"Build\", 8 }, { \"Drop\", 16 }, { \"Outro\", 16 } },\n  { { \"Intro\", 4 }, { \"Verse\", 8 }, { \"Pre-Chorus\", 4 }, { \"Chorus\", 8 }, { \"Verse\", 8 }, { \"Pre-Chorus\", 4 }, { \"Chorus\", 8 }, { \"Outro\", 4 } },\n  { { \"Intro\", 8 }, { \"A\", 16 }, { \"B\", 16 }, { \"A\", 16 }, { \"Solo\", 16 }, { \"A\", 16 }, { \"Outro\", 8 } },\n  { { \"Cold open\", 4 }, { \"Hook\", 8 }, { \"Verse\", 16 }, { \"Hook\", 8 }, { \"Verse\", 16 }, { \"Hook\", 8 }, { \"Outro\", 4 } },\n}\n\nidea { id = \"arrange\", label = \"Arrangement\", icon = \"blocks\", weight = 5,\n  make = function(rnd, r)\n    local set = pickOne(rnd, SECTION_SETS)\n    local list = {}\n    for i, s in ipairs(set) do list[i] = { s[1], s[2] } end\n    if r >= L.RARE and chance(rnd, 0.7) then\n      table.insert(list, between(rnd, 3, #list - 1), { pickOne(rnd, { \"Breakdown\", \"Interlude\", \"Key change\", \"Half-time\" }), 8 })\n    end\n    if r >= L.LEGENDARY then table.insert(list, #list, { \"False ending\", 4 }) end\n    if r == L.POOR then list = { { \"Loop\", 8 }, { \"Same loop\", 8 }, { \"Loop again\", 8 } } end\n    local bpm = between(rnd, 80, 140)\n    local bars, parts = 0, {}\n    for i, s in ipairs(list) do bars = bars + s[2]; parts[i] = s[1] .. \" \" .. s[2] end\n    local secs = bars * 4 * 60 / bpm\n    return { text = table.concat(parts, \"  >  \"),\n             sub = string.format(\"%d bars, about %d:%02d at %d BPM\", bars, math.floor(secs / 60), math.floor(secs % 60), bpm),\n             data = { sections = list, bpm = bpm } }\n  end }\n\nlocal SIGS = { { \"4/4\", 60 }, { \"3/4\", 10 }, { \"6/8\", 10 }, { \"5/4\", 4 }, { \"7/8\", 4 }, { \"12/8\", 6 } }\n\nidea { id = \"seed\", label = \"Song Seed\", icon = \"seed\", weight = 6,\n  make = function(rnd, r)\n    local T = L.T\n    local scaleName = scaleByWeight(rnd, r)\n    local key = keyFor(between(rnd, 0, 11), T.scaleIndex(scaleName))\n    local bpm = between(rnd, 68, 174)\n    local sig = (r >= L.RARE) and weighted(rnd, (function()\n      local t = {}\n      for _, s in ipairs(SIGS) do t[#t + 1] = { s[2], s[1] } end\n      return t\n    end)()) or \"4/4\"\n    local parts = { T.noteName(key, 0) .. \" \" .. T.SCALES[key.scale].name, bpm .. \" BPM\", sig }\n    local sub = { pickOne(rnd, GENRES) }\n    if r >= L.UNCOMMON then sub[#sub + 1] = \"feeling \" .. pickOne(rnd, MOODS) end\n    if r >= L.EPIC then sub[#sub + 1] = \"called \\\"\" .. pickOne(rnd, ADJ) .. \" \" .. pickOne(rnd, NOUN) .. \"\\\"\" end\n    return { text = table.concat(parts, \"  /  \"), sub = table.concat(sub, \", \"), data = { bpm = bpm } }\n  end }\n\nidea { id = \"goodidea\", label = \"Good Idea Number\", icon = \"dice\", weight = 2,\n  make = function(rnd, r)\n    local kinds = { \"Motif\", \"Phrase\", \"Measure\", \"Drums\" }\n    local n = between(rnd, 1, 99999)\n    return { text = \"Idea #\" .. n, sub = \"Open Good Idea, choose \" .. pickOne(rnd, kinds) .. \" and type in idea number \" .. n,\n             data = { number = n } }\n  end }\n\nfunction L.makeIdea(rnd, kind, r)\n  local def = IDEAS[kind]\n  local out = def.make(rnd, r)\n  return { type = \"idea\", kind = kind, rarity = r, name = def.label, icon = def.icon,\n           text = out.text, sub = out.sub or \"\", data = out.data or {}, midi = def.midi or false }\nend\n\nfunction L.randomIdeaKind(rnd)\n  local list = {}\n  for _, d in ipairs(IDEAS) do list[#list + 1] = { d.weight, d.id } end\n  return weighted(rnd, list)\nend\n\n------------------------------------------------------------------------------\n-- Gear\n--\n-- Diablo's way with items: a base for its slot; an implicit stat every item\n-- of that slot carries; affixes, more the rarer it is, each rolled within a\n-- range and naming the item; and on Legendary and Mythic gear a power that\n-- changes a rule rather than a number. Stats only ever reward working on\n-- music - none of them shortens the fifteen minutes a tier takes.\n------------------------------------------------------------------------------\n\nL.SLOTS = {\n  { id = \"phones\", name = \"Headphones\", icon = \"phones\", implicit = \"xp\",\n    bases = { \"Earbuds\", \"Studio Cans\", \"Open-Backs\", \"Closed-Backs\", \"Reference Headphones\", \"Planar Headphones\" } },\n  { id = \"monitors\", name = \"Monitors\", icon = \"speaker\", implicit = \"coins\",\n    bases = { \"Desk Speakers\", \"Nearfields\", \"Studio Monitors\", \"Midfields\", \"Horn Monitors\", \"Coaxial Monitors\" } },\n  { id = \"keys\", name = \"Controller\", icon = \"keys\", implicit = \"notes\",\n    bases = { \"Mini Keyboard\", \"Pad Controller\", \"MIDI Keyboard\", \"Weighted Keys\", \"Grid Controller\", \"Fader Bank\" } },\n  { id = \"mic\", name = \"Microphone\", icon = \"mic\", implicit = \"rec\",\n    bases = { \"Dynamic Mic\", \"Condenser Mic\", \"Ribbon Mic\", \"Tube Mic\", \"Shotgun Mic\", \"Valve Condenser\" } },\n  { id = \"interface\", name = \"Interface\", icon = \"dial\", implicit = \"quest\",\n    bases = { \"Audio Interface\", \"Preamp\", \"Channel Strip\", \"Converter\", \"Summing Mixer\", \"Patchbay\" } },\n  { id = \"charm\", name = \"Desk Charm\", icon = \"gem\", implicit = \"luck\",\n    bases = { \"Coffee Mug\", \"Lava Lamp\", \"Rubber Duck\", \"Cactus\", \"Lucky Plectrum\", \"Vinyl Record\", \"Cassette Tape\", \"Tiny Gong\" } },\n}\nfor _, s in ipairs(L.SLOTS) do L.SLOTS[s.id] = s end\n\nL.JUNK = { \"Cracked\", \"Dusty\", \"Buzzing\", \"Wobbly\", \"Chipped\", \"Sticky\", \"Crackling\", \"Second-hand\" }\n\n-- stat: what the game reads. lo/hi: the roll at item level 1, before rarity.\nL.AFFIXES = {\n  { id = \"xp\",      lo = 2, hi = 6,   fmt = \"+%d%% XP from everything\",            prefix = \"Studious\",  suffix = \"of Learning\" },\n  { id = \"coins\",   lo = 3, hi = 8,   fmt = \"+%d%% coins found\",                   prefix = \"Gilded\",    suffix = \"of Riches\" },\n  { id = \"luck\",    lo = 3, hi = 10,  fmt = \"+%d%% better loot (magic find)\",       prefix = \"Lucky\",     suffix = \"of Fortune\" },\n  { id = \"quest\",   lo = 4, hi = 10,  fmt = \"+%d%% quest rewards\",                 prefix = \"Questing\",  suffix = \"of the Seeker\" },\n  { id = \"notes\",   lo = 8, hi = 20,  fmt = \"+%d%% XP from writing MIDI notes\",    prefix = \"Melodic\",   suffix = \"of the Composer\" },\n  { id = \"rec\",     lo = 8, hi = 20,  fmt = \"+%d%% XP from recording\",             prefix = \"Live\",      suffix = \"of the Performer\" },\n  { id = \"fx\",      lo = 8, hi = 20,  fmt = \"+%d%% XP from plugins\",               prefix = \"Processed\", suffix = \"of the Engineer\" },\n  { id = \"tracks\",  lo = 8, hi = 20,  fmt = \"+%d%% XP from new tracks and items\",  prefix = \"Building\",  suffix = \"of the Arranger\" },\n  { id = \"endure\",  lo = 5, hi = 15,  fmt = \"+%d%% XP after an hour in a session\", prefix = \"Tireless\",  suffix = \"of Endurance\" },\n  { id = \"night\",   lo = 8, hi = 25,  fmt = \"+%d%% XP between midnight and 5am\",   prefix = \"Nocturnal\", suffix = \"of the Night Owl\" },\n  { id = \"dawn\",    lo = 8, hi = 25,  fmt = \"+%d%% XP between 5am and 9am\",        prefix = \"Dawnlit\",   suffix = \"of the Early Bird\" },\n  { id = \"grace\",   lo = 15, hi = 45, fmt = \"+%d seconds before you count as idle\", prefix = \"Patient\",  suffix = \"of Focus\" },\n  { id = \"checkin\", lo = 10, hi = 30, fmt = \"+%d%% check-in rewards\",              prefix = \"Loyal\",     suffix = \"of Devotion\" },\n  { id = \"crate\",   lo = 5, hi = 15,  fmt = \"+%d%% chance of an extra item in crates\", prefix = \"Hoarding\", suffix = \"of Plenty\" },\n}\nfor _, a in ipairs(L.AFFIXES) do L.AFFIXES[a.id] = a end\n\nL.POWERS = {\n  { id = \"golden_hour\", name = \"Golden Hour\",  text = \"Hour rewards hold one extra item.\" },\n  { id = \"hoarder\",     name = \"Hoarder\",      text = \"Every crate holds one extra item.\" },\n  { id = \"midas\",       name = \"Midas Touch\",  text = \"A 10% chance to double any coins you find.\" },\n  { id = \"collector\",   name = \"The Collector\", text = \"Ideas you find have a 25% chance to be one rarity higher.\" },\n  { id = \"second_wind\", name = \"Second Wind\",  text = \"Coming back from idle gives 30 XP (once every 30 minutes).\" },\n  { id = \"fickle\",      name = \"Fickle Muse\",  text = \"A free quest reroll every day.\" },\n  { id = \"deep_focus\",  name = \"Deep Focus\",   text = \"Three extra minutes before you count as idle.\" },\n  { id = \"overclock\",   name = \"Overclocked\",  text = \"XP Boosts last twice as long.\" },\n  { id = \"marathon\",    name = \"Marathon\",     text = \"+50% XP after two hours in a session.\" },\n  { id = \"scholar\",     name = \"Scholar\",      text = \"Quests give 50% more XP.\" },\n}\nfor _, p in ipairs(L.POWERS) do L.POWERS[p.id] = p end\n\nlocal AFFIX_COUNT = { 0, 0, 1, 2, 3, 3, 4 }\nlocal RARE_A = { \"Storm\", \"Doom\", \"Echo\", \"Rune\", \"Dread\", \"Grim\", \"Bliss\", \"Soul\", \"Ghost\", \"Star\", \"Blood\", \"Dusk\", \"Glory\", \"Hex\", \"Void\" }\nlocal RARE_B = { \"Whisper\", \"Howl\", \"Hymn\", \"Song\", \"Roar\", \"Chant\", \"Pulse\", \"Beat\", \"Wail\", \"Drone\", \"Groove\", \"Fang\", \"Ward\", \"Mark\" }\n\nlocal function affixValue(rnd, a, r, ilvl, top)\n  local roll = top and (0.5 + 0.5 * rnd()) or rnd()\n  local v = (a.lo + (a.hi - a.lo) * roll) * L.RARITY[r].mult * (1 + math.min(ilvl or 1, 100) / 200)\n  return math.max(1, math.floor(v + 0.5))\nend\n\nfunction L.makeGear(rnd, r, ilvl, slotId)\n  ilvl = math.max(1, math.floor(ilvl or 1))\n  local slot = slotId and L.SLOTS[slotId] or pickOne(rnd, L.SLOTS)\n  local base = slot.bases[math.min(#slot.bases, 1 + math.floor((r - 1) * #slot.bases / 7 + rnd() * 1.5))]\n  local implicit = L.AFFIXES[slot.implicit]\n  local item = { type = \"gear\", slot = slot.id, base = base, rarity = r, ilvl = ilvl, icon = slot.icon,\n                 implicit = { id = implicit.id, value = math.max(1, math.floor(affixValue(rnd, implicit, r, ilvl, r == L.MYTHIC) * 0.5 + 0.5)) },\n                 affixes = {} }\n  if r == L.POOR then item.implicit.value = 1 end\n  local pool = {}\n  for _, a in ipairs(L.AFFIXES) do if a.id ~= slot.implicit then pool[#pool + 1] = a end end\n  pool = shuffled(rnd, pool)\n  for i = 1, AFFIX_COUNT[r] do\n    local a = pool[i]\n    item.affixes[i] = { id = a.id, value = affixValue(rnd, a, r, ilvl, r == L.MYTHIC) }\n  end\n  if r >= L.LEGENDARY then item.power = pickOne(rnd, L.POWERS).id end\n  -- The name, the way Diablo builds one.\n  if r == L.POOR then item.name = pickOne(rnd, L.JUNK) .. \" \" .. base\n  elseif r == L.COMMON then item.name = base\n  elseif r == L.UNCOMMON then\n    local a = L.AFFIXES[item.affixes[1].id]\n    item.name = chance(rnd, 0.5) and (a.prefix .. \" \" .. base) or (base .. \" \" .. a.suffix)\n  elseif r == L.RARE then\n    item.name = L.AFFIXES[item.affixes[1].id].prefix .. \" \" .. base .. \" \" .. L.AFFIXES[item.affixes[2].id].suffix\n  elseif r == L.EPIC then item.name = pickOne(rnd, RARE_A) .. \" \" .. pickOne(rnd, RARE_B)\n  elseif r == L.LEGENDARY then item.name = madeUpName(rnd) .. \"'s \" .. base\n  else item.name = madeUpName(rnd) .. \", \" .. pickOne(rnd, EPITHETS) end\n  item.text = item.name\n  item.sub = L.RARITY[r].name .. \" \" .. slot.name .. (r >= L.EPIC and (\" (\" .. base .. \")\") or \"\") .. \"  /  item level \" .. ilvl\n  item.name = item.name\n  return item\nend\n\n-- Every stat an item gives, implicit included, as { id = value }.\nfunction L.gearStats(item)\n  local s = {}\n  if item.implicit then s[item.implicit.id] = (s[item.implicit.id] or 0) + item.implicit.value end\n  for _, a in ipairs(item.affixes or {}) do s[a.id] = (s[a.id] or 0) + a.value end\n  return s\nend\n\nfunction L.statLine(id, value) return string.format(L.AFFIXES[id].fmt, value) end\n\n-- A single number to compare gear by: each stat against its own range.\nfunction L.gearScore(item)\n  local score = 0\n  for id, v in pairs(L.gearStats(item)) do\n    local a = L.AFFIXES[id]\n    score = score + v / ((a.lo + a.hi) / 2) * 10\n  end\n  if item.power then score = score + 25 end\n  return math.floor(score + 0.5)\nend\n\nfunction L.sellValue(item)\n  return math.floor(L.RARITY[item.rarity].sell * (1 + (item.ilvl or 1) / 50) + 0.5)\nend\n\n------------------------------------------------------------------------------\n-- Cosmetics\n------------------------------------------------------------------------------\n\nfunction L.makeTitle(rnd, r)\n  local t\n  if r <= L.COMMON then t = pickOne(rnd, TITLE_ROLE)\n  elseif r <= L.RARE then t = pickOne(rnd, TITLE_ADJ) .. \" \" .. pickOne(rnd, TITLE_ROLE)\n  elseif r <= L.LEGENDARY then t = pickOne(rnd, TITLE_ADJ) .. \" \" .. pickOne(rnd, TITLE_ROLE) .. \" of \" .. pickOne(rnd, TITLE_OF)\n  else t = madeUpName(rnd) .. \" the \" .. pickOne(rnd, TITLE_ADJ) .. \", \" .. pickOne(rnd, TITLE_ROLE) .. \" of \" .. pickOne(rnd, TITLE_OF) end\n  return { type = \"title\", rarity = r, name = \"Player Title\", icon = \"crown\", text = t, sub = \"Wear it in your banner\" }\nend\n\nL.BANNER_SHAPES = { \"circle\", \"shield\", \"diamond\", \"hexagon\", \"star\" }\nL.BANNER_PATTERNS = { \"plain\", \"split\", \"stripes\", \"chevron\", \"rings\", \"rays\", \"dots\" }\nL.BANNER_GLYPHS = { \"note\", \"bolt\", \"star\", \"crown\", \"flame\", \"wave\", \"moon\", \"gem\" }\n\nfunction L.makeBanner(rnd, r)\n  local maxPattern = math.min(#L.BANNER_PATTERNS, 1 + r)\n  local b = {\n    shape = pickOne(rnd, L.BANNER_SHAPES),\n    pattern = L.BANNER_PATTERNS[between(rnd, 1, maxPattern)],\n    h1 = rnd(), h2 = rnd(),\n    glyph = (r >= L.RARE) and pickOne(rnd, L.BANNER_GLYPHS) or nil,\n    glow = r >= L.LEGENDARY, spin = r >= L.MYTHIC,\n  }\n  if r == L.POOR then b.pattern = \"plain\"; b.sat = 0.1 end\n  return { type = \"banner\", rarity = r, name = \"Banner\", icon = \"banner\",\n           text = pickOne(rnd, COLOUR_WORDS) .. \" \" .. pickOne(rnd, BANNER_THINGS), sub = \"A banner for your profile\", data = b }\nend\n\n------------------------------------------------------------------------------\n-- Coins, XP, tokens, crates\n------------------------------------------------------------------------------\n\nL.TOKENS = {\n  reroll = { name = \"Quest Reroll\", icon = \"dice\", text = \"Swap a quest for a new one\" },\n  freeze = { name = \"Streak Freeze\", icon = \"snow\", text = \"Saves your check-in streak for a missed day\" },\n  boost  = { name = \"XP Boost\", icon = \"bolt\", text = \"Double XP for 30 minutes of active time\" },\n}\n\nfunction L.makeCoins(rnd, r)\n  local n = L.coinsFor(rnd, r)\n  return { type = \"coins\", rarity = r, name = \"Coins\", icon = \"coin\", amount = n, text = n .. \" coins\", sub = \"Spend them in the shop\" }\nend\n\nfunction L.makeXp(rnd, r)\n  local n = L.RARITY[r].xp\n  return { type = \"xp\", rarity = r, name = \"XP\", icon = \"star\", amount = n, text = n .. \" XP\", sub = \"Straight onto your level\" }\nend\n\nfunction L.makeToken(rnd, r, id)\n  id = id or weighted(rnd, { { 5, \"reroll\" }, { 2, \"freeze\" }, { 3, \"boost\" } })\n  local tk = L.TOKENS[id]\n  local n = (r >= L.MYTHIC) and 3 or ((r >= L.LEGENDARY) and 2 or 1)\n  return { type = \"token\", rarity = math.max(r, L.UNCOMMON), name = tk.name, icon = tk.icon, token = id, amount = n,\n           text = (n > 1 and (n .. \" x \") or \"\") .. tk.name, sub = tk.text }\nend\n\nfunction L.makeCrate(r)\n  r = math.max(L.COMMON, r)\n  return { type = \"crate\", rarity = r, name = \"Loot Crate\", icon = \"crate\",\n           text = L.RARITY[r].name .. \" Crate\", sub = \"Open it in Loot\" }\nend\n\n-- A random drop of a rarity, from a pool's weights. ctx: ilvl, collector.\nlocal POOLS = {\n  tier  = { { 24, \"coins\" }, { 34, \"idea\" }, { 18, \"gear\" }, { 8, \"cosmetic\" }, { 9, \"token\" }, { 7, \"xp\" } },\n  crate = { { 32, \"gear\" }, { 30, \"idea\" }, { 14, \"coins\" }, { 12, \"cosmetic\" }, { 8, \"token\" }, { 4, \"xp\" } },\n  deal  = { { 50, \"gear\" }, { 35, \"cosmetic\" }, { 15, \"idea\" } },\n}\nL.POOLS = POOLS\n\nfunction L.makeDrop(rnd, r, pool, ctx)\n  ctx = ctx or {}\n  local what = weighted(rnd, POOLS[pool or \"tier\"])\n  if what == \"coins\" then return L.makeCoins(rnd, r)\n  elseif what == \"xp\" then return L.makeXp(rnd, r)\n  elseif what == \"token\" then return L.makeToken(rnd, r)\n  elseif what == \"gear\" then return L.makeGear(rnd, r, ctx.ilvl or 1)\n  elseif what == \"cosmetic\" then\n    if chance(rnd, 0.5) then return L.makeTitle(rnd, r) end\n    return L.makeBanner(rnd, r)\n  end\n  local kind = L.randomIdeaKind(rnd)\n  if ctx.collector and r < L.MYTHIC and chance(rnd, 0.25) then r = r + 1 end\n  return L.makeIdea(rnd, kind, r)\nend\n\n-- What a crate holds: three things, one at least the crate's rarity, the rest\n-- at most two steps under it. `extra` items on top.\nfunction L.crateContents(rnd, r, luck, extra, ctx)\n  local out = {}\n  local n = 3 + (extra or 0)\n  for i = 1, n do\n    local rr\n    if i == 1 then rr = L.rollRarity(rnd, r, L.MYTHIC, luck)\n    else rr = L.rollRarity(rnd, math.max(L.POOR, r - 2), L.MYTHIC, luck) end\n    out[i] = L.makeDrop(rnd, rr, \"crate\", ctx)\n  end\n  return out\nend\n\n------------------------------------------------------------------------------\n-- Seasons\n--\n-- A season is a calendar month, numbered from January 2026, with a name made\n-- from its number. Its track has 100 tiers, one every fifteen active minutes,\n-- every fourth (each hour) a big one; past 100 the bonus tiers go on for ever.\n-- Each tier's reward is made from the season and the tier alone, so the track\n-- can be shown ahead of time.\n------------------------------------------------------------------------------\n\nL.SEASON_TIERS = 100\n\nlocal SEASON_ADJ = { \"Neon\", \"Midnight\", \"Golden\", \"Electric\", \"Cosmic\", \"Velvet\", \"Crystal\",\n  \"Analog\", \"Lunar\", \"Solar\", \"Feral\", \"Infinite\", \"Phantom\", \"Tidal\", \"Static\", \"Molten\" }\nlocal SEASON_NOUN = { \"Tides\", \"Frequencies\", \"Echoes\", \"Horizons\", \"Circuits\", \"Embers\",\n  \"Dreams\", \"Signals\", \"Voltage\", \"Gardens\", \"Machines\", \"Skies\", \"Waves\", \"Ruins\", \"Rhythms\" }\n\nfunction L.seasonId(year, month) return (year - 2026) * 12 + month end\n\nfunction L.seasonName(id)\n  local rnd = L.random(L.seedOf(\"season\", id))\n  return pickOne(rnd, SEASON_ADJ) .. \" \" .. pickOne(rnd, SEASON_NOUN)\nend\n\n-- \"big\" tiers are each hour's; \"milestone\" every tenth; the last the finale.\nfunction L.tierKind(tier)\n  if tier == L.SEASON_TIERS then return \"finale\" end\n  if tier % 25 == 0 and tier <= L.SEASON_TIERS then return \"legendary\" end\n  if tier % 10 == 0 and tier <= L.SEASON_TIERS then return \"milestone\" end\n  if tier % 4 == 0 then return \"big\" end\n  return \"small\"\nend\n\n-- The rarity a tier's headline reward will have, without making it: for the\n-- track's preview.\nfunction L.tierRewards(season, tier, ilvl, ctx)\n  ctx = ctx or {}\n  ctx.ilvl = ilvl\n  local rnd = L.random(L.seedOf(\"tier\", season, tier))\n  local kind = L.tierKind(tier)\n  local out = {}\n  if kind == \"small\" then\n    out[1] = L.makeCoins(rnd, L.rollRarity(rnd, L.POOR, L.UNCOMMON))\n    out[2] = L.makeDrop(rnd, L.rollRarity(rnd, L.POOR, L.MYTHIC), \"tier\", ctx)\n  elseif kind == \"big\" then\n    out[1] = L.makeCoins(rnd, L.RARE)\n    out[2] = L.makeCrate(L.rollRarity(rnd, L.RARE, L.MYTHIC))\n    out[3] = L.makeDrop(rnd, L.rollRarity(rnd, L.UNCOMMON, L.MYTHIC), \"crate\", ctx)\n  elseif kind == \"milestone\" then\n    out[1] = L.makeCoins(rnd, L.EPIC)\n    out[2] = L.makeGear(rnd, L.rollRarity(rnd, L.EPIC, L.MYTHIC), ilvl)\n    out[3] = L.makeDrop(rnd, L.rollRarity(rnd, L.RARE, L.MYTHIC), \"crate\", ctx)\n  elseif kind == \"legendary\" then\n    out[1] = L.makeCoins(rnd, L.LEGENDARY)\n    out[2] = L.makeGear(rnd, L.LEGENDARY, ilvl)\n    out[3] = L.makeCrate(L.EPIC)\n  else\n    out[1] = L.makeCoins(rnd, L.MYTHIC)\n    out[2] = L.makeGear(rnd, L.MYTHIC, ilvl)\n    local t = L.makeTitle(rnd, L.MYTHIC)\n    t.text = \"Champion of \" .. L.seasonName(season)\n    out[3] = t\n    local b = L.makeBanner(rnd, L.MYTHIC)\n    out[4] = b\n  end\n  return out, kind\nend\n\n-- What the track shows for a tier before it is reached: its best reward.\nfunction L.tierHeadline(season, tier, ilvl)\n  local list, kind = L.tierRewards(season, tier, ilvl)\n  local best = list[1]\n  for _, d in ipairs(list) do\n    if d.rarity > best.rarity or (d.rarity == best.rarity and best.type == \"coins\") then best = d end\n  end\n  return best, kind\nend\n\nfunction L.init(T)\n  L.T = T\n  return L\nend\n\nreturn L\n", "battle-pass/bp_theory.lua": "--[[ DAW Battle Pass - keys, scales and chord names.\n\n     Pure Lua. Nothing in this file touches REAPER or ImGui.\n\n     The battle pass hands out musical ideas as rewards (chord progressions,\n     melodies, song seeds), and they should name their notes and chords the\n     way the sister apps do. So everything here is Good Idea's theory file -\n     which is Midi Catalogue's, ScaleView's and Starting Blocks' - copied\n     unchanged and cut down to what the rewards use: the keys, positions and\n     spelling, the degree numerals, and Starting Blocks' chord table for\n     naming. tests/test_theory.lua checks the copies still say what the\n     originals say. Do not tidy them independently.\n\n     Two ways of naming a note run through it:\n\n       - a MIDI pitch, 0..127;\n       - a scale position, an integer counting scale notes from the key's root\n         in MIDI octave -1. A third above is +2, whatever the scale.\n]]\n\nlocal M = {}\n\n\n------------------------------------------------------------------------------\n-- Keys\n--\n-- ScaleView for REAPER's roots and scales, unchanged, the same tables Starting\n-- Blocks copies, so all three apps agree on what a scale is and what to call\n-- its notes. test_theory.lua asserts they still match. Do not tidy them\n-- independently.\n------------------------------------------------------------------------------\n\nlocal LETTER_PC  = { 0, 2, 4, 5, 7, 9, 11 }        -- C D E F G A B\nlocal LETTERS    = { \"C\", \"D\", \"E\", \"F\", \"G\", \"A\", \"B\" }\nlocal ACCIDENTAL = { [-2] = \"bb\", [-1] = \"b\", [0] = \"\", [1] = \"#\", [2] = \"x\" }\n\nM.ROOTS = {\n  { name = \"C\",  letter = 0, acc =  0 }, { name = \"C#\", letter = 0, acc =  1 },\n  { name = \"Db\", letter = 1, acc = -1 }, { name = \"D\",  letter = 1, acc =  0 },\n  { name = \"D#\", letter = 1, acc =  1 }, { name = \"Eb\", letter = 2, acc = -1 },\n  { name = \"E\",  letter = 2, acc =  0 }, { name = \"F\",  letter = 3, acc =  0 },\n  { name = \"F#\", letter = 3, acc =  1 }, { name = \"Gb\", letter = 4, acc = -1 },\n  { name = \"G\",  letter = 4, acc =  0 }, { name = \"G#\", letter = 4, acc =  1 },\n  { name = \"Ab\", letter = 5, acc = -1 }, { name = \"A\",  letter = 5, acc =  0 },\n  { name = \"A#\", letter = 5, acc =  1 }, { name = \"Bb\", letter = 6, acc = -1 },\n  { name = \"B\",  letter = 6, acc =  0 }, { name = \"Cb\", letter = 0, acc = -1 },\n}\n\nM.SCALES = {\n  { name = \"Major\",      iv = {0,2,4,5,7,9,11},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Minor\",      iv = {0,2,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Harm Minor\", iv = {0,2,3,5,7,8,11},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Ionian\",     iv = {0,2,4,5,7,9,11},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Dorian\",     iv = {0,2,3,5,7,9,10},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Phrygian\",   iv = {0,1,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Lydian\",     iv = {0,2,4,6,7,9,11},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Mixolydian\", iv = {0,2,4,5,7,9,10},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Aeolian\",    iv = {0,2,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },\n  { name = \"Maj Pent\",   iv = {0,2,4,7,9},        letters = {0,1,2,4,5} },\n  { name = \"Min Pent\",   iv = {0,3,5,7,10},       letters = {0,2,3,4,6} },\n  { name = \"Maj Blues\",  iv = {0,2,3,4,7,9},      letters = {0,1,2,2,4,5} },\n  { name = \"Min Blues\",  iv = {0,3,5,6,7,10},     letters = {0,2,3,4,4,6} },\n  { name = \"Whole Tone\", iv = {0,2,4,6,8,10},     letters = {0,1,2,3,4,5} },\n  { name = \"Dim W-H\",    iv = {0,2,3,5,6,8,9,11}, letters = {0,1,2,3,4,5,5,6} },\n  { name = \"Dim H-W\",    iv = {0,1,3,4,6,7,9,10}, letters = {0,1,2,2,3,4,5,6} },\n}\n\nlocal NUMERALS = { \"I\", \"II\", \"III\", \"IV\", \"V\", \"VI\", \"VII\", \"VIII\" }\n\n-- A key is the pair of indices the window picks. A chord scale (M.chordKey)\n-- is a key that also carries its own intervals: the same scale with a note\n-- or two bent to the chord sounding over it.\nfunction M.key(root, scale) return { root = root or 1, scale = scale or 1 } end\n\nlocal function ivOf(key) return key.iv or M.SCALES[key.scale].iv end\n\nM.ivOf = ivOf\n\nfunction M.scaleLen(key) return #ivOf(key) end\n\nfunction M.rootPc(key)\n  local rt = M.ROOTS[key.root]\n  return (LETTER_PC[rt.letter + 1] + rt.acc + 12) % 12\nend\n\n------------------------------------------------------------------------------\n-- Positions and pitches\n------------------------------------------------------------------------------\n\n-- The MIDI pitch of a scale position.\nfunction M.pitch(key, pos)\n  local iv  = ivOf(key)\n  local n   = #iv\n  local oct = math.floor(pos / n)\n  local k   = pos - oct * n\n  return M.rootPc(key) + (key.lift or 0) + iv[k + 1] + 12 * oct\nend\n\n-- The highest position at or below a pitch. Every pitch has one, because the\n-- root is in every octave.\nfunction M.floorPos(key, midi)\n  local iv   = ivOf(key)\n  local n    = #iv\n  local root = M.rootPc(key) + (key.lift or 0)\n  local oct  = math.floor((midi - root) / 12)\n  local kmax = 0\n  for k = 1, n do\n    if root + iv[k] + 12 * oct <= midi then kmax = k - 1 end\n  end\n  return oct * n + kmax\nend\n\n-- The position of a pitch that is in the scale, or nil for one that is not.\nfunction M.posOf(key, midi)\n  local s = M.floorPos(key, midi)\n  if M.pitch(key, s) == midi then return s end\n  return nil\nend\n\n-- The nearest position to any pitch. A pitch exactly between two scale notes\n-- goes the way `lean` says (+1 up, -1 down), and down when it says nothing.\nfunction M.nearestPos(key, midi, lean)\n  local lo = M.floorPos(key, midi)\n  if M.pitch(key, lo) == midi then return lo end\n  local dLo = midi - M.pitch(key, lo)\n  local dHi = M.pitch(key, lo + 1) - midi\n  if dLo < dHi then return lo end\n  if dHi < dLo then return lo + 1 end\n  return (lean or -1) > 0 and lo + 1 or lo\nend\n\nfunction M.pc(key, pos) return M.pitch(key, pos) % 12 end\n\n-- Spelled for the key: the seventh of F# major comes out E#, not F.\nfunction M.noteName(key, pos)\n  local sc  = M.SCALES[key.scale]\n  local n   = #ivOf(key)\n  local oct = math.floor(pos / n)\n  local k   = pos - oct * n\n  local letter = (M.ROOTS[key.root].letter + sc.letters[k + 1]) % 7\n  local acc = M.pitch(key, pos) % 12 - LETTER_PC[letter + 1]\n  if acc >  6 then acc = acc - 12 end\n  if acc < -6 then acc = acc + 12 end\n  return LETTERS[letter + 1] .. (ACCIDENTAL[acc] or \"?\")\nend\n\n-- A pitch named with its octave, C4 being middle C (60). Out of the key, the\n-- sharp spelling.\nlocal SHARP_NAMES = { \"C\", \"C#\", \"D\", \"D#\", \"E\", \"F\", \"F#\", \"G\", \"G#\", \"A\", \"A#\", \"B\" }\nfunction M.pitchName(midi, key)\n  local oct = math.floor(midi / 12) - 1\n  if key then\n    local s = M.posOf(key, midi)\n    if s then return M.noteName(key, s) .. oct end\n  end\n  return SHARP_NAMES[midi % 12 + 1] .. oct\nend\n\n------------------------------------------------------------------------------\n-- Degrees\n------------------------------------------------------------------------------\n\n-- Read off the scale rather than assumed, so the modes and the blues scales\n-- come out right: the vii of major is diminished, the III of minor is major.\nfunction M.degreeQuality(key, degree)\n  local p  = M.pitch(key, degree)\n  local r3 = M.pitch(key, degree + 2) - p\n  local r5 = M.pitch(key, degree + 4) - p\n  if r3 == 4 and r5 == 7 then return \"major\"      end\n  if r3 == 3 and r5 == 7 then return \"minor\"      end\n  if r3 == 3 and r5 == 6 then return \"diminished\" end\n  if r3 == 4 and r5 == 8 then return \"augmented\"  end\n  return \"other\"\nend\n\nfunction M.degreeNumeral(key, degree, ascii)\n  local q = M.degreeQuality(key, degree)\n  local n = NUMERALS[(degree % 8) + 1]\n  if q == \"minor\" or q == \"diminished\" then n = n:lower() end\n  if q == \"diminished\" then n = n .. (ascii and \"dim\" or \"\\u{00B0}\") end\n  if q == \"augmented\"  then n = n .. (ascii and \"aug\" or \"+\") end\n  return n\nend\n\n\n------------------------------------------------------------------------------\n-- Chords\n--\n-- Starting Blocks' chord tables, copied unchanged: one row per chord carrying\n-- its own name, symbol and intervals (semitones from the chord's root), in\n-- the families of Wikipedia's list of chords. Here they only name what the\n-- scale builds (Good Idea's chords are always in key). Do not tidy them\n-- independently of Starting Blocks.\n------------------------------------------------------------------------------\n\nM.FAMILIES = { \"Diatonic\", \"Triads\", \"6ths & 7ths\", \"Extended\", \"Altered\",\n               \"Sus & Add\", \"Quartal\", \"Named\" }\n\nlocal TR, S7, EX, AL, SA, QU, NA = 2, 3, 4, 5, 6, 7, 8   -- indices into FAMILIES\n\nM.CHORDS = {\n  { sym=\"maj\",  name=\"Major\",                  iv={0,4,7},          fam=TR },\n  { sym=\"m\",    name=\"Minor\",                  iv={0,3,7},          fam=TR },\n  { sym=\"dim\",  name=\"Diminished\",             iv={0,3,6},          fam=TR },\n  { sym=\"aug\",  name=\"Augmented\",              iv={0,4,8},          fam=TR },\n  { sym=\"b5\",   name=\"Flat Five\",              iv={0,4,6},          fam=TR },\n  { sym=\"5\",    name=\"Fifth (Power)\",          iv={0,7},            fam=TR },\n\n  { sym=\"6\",       name=\"Sixth\",                    iv={0,4,7,9},     fam=S7 },\n  { sym=\"m6\",      name=\"Minor Sixth\",              iv={0,3,7,9},     fam=S7 },\n  { sym=\"6/9\",     name=\"Six-Nine\",                 iv={0,4,7,9,14},  fam=S7 },\n  { sym=\"m6/9\",    name=\"Minor Six-Nine\",           iv={0,3,7,9,14},  fam=S7 },\n  { sym=\"7\",       name=\"Dominant Seventh\",         iv={0,4,7,10},    fam=S7 },\n  { sym=\"maj7\",    name=\"Major Seventh\",            iv={0,4,7,11},    fam=S7 },\n  { sym=\"m7\",      name=\"Minor Seventh\",            iv={0,3,7,10},    fam=S7 },\n  { sym=\"mMaj7\",   name=\"Minor-Major Seventh\",      iv={0,3,7,11},    fam=S7 },\n  { sym=\"m7b5\",    name=\"Half-Diminished Seventh\",  iv={0,3,6,10},    fam=S7 },\n  { sym=\"dim7\",    name=\"Diminished Seventh\",       iv={0,3,6,9},     fam=S7 },\n  { sym=\"7#5\",     name=\"Augmented Seventh\",        iv={0,4,8,10},    fam=S7 },\n  { sym=\"maj7#5\",  name=\"Augmented Major Seventh\",  iv={0,4,8,11},    fam=S7 },\n  { sym=\"7b5\",     name=\"Seventh Flat Five\",        iv={0,4,6,10},    fam=S7 },\n  { sym=\"dimMaj7\", name=\"Diminished Major Seventh\", iv={0,3,6,11},    fam=S7 },\n  { sym=\"7/6\",     name=\"Seven Six\",                iv={0,4,7,9,10},  fam=S7 },\n\n  { sym=\"9\",     name=\"Ninth\",               iv={0,4,7,10,14},       fam=EX },\n  { sym=\"maj9\",  name=\"Major Ninth\",         iv={0,4,7,11,14},       fam=EX },\n  { sym=\"m9\",    name=\"Minor Ninth\",         iv={0,3,7,10,14},       fam=EX },\n  { sym=\"mMaj9\", name=\"Minor-Major Ninth\",   iv={0,3,7,11,14},       fam=EX },\n  { sym=\"11\",    name=\"Eleventh\",            iv={0,4,7,10,14,17},    fam=EX },\n  { sym=\"maj11\", name=\"Major Eleventh\",      iv={0,4,7,11,14,17},    fam=EX },\n  { sym=\"m11\",   name=\"Minor Eleventh\",      iv={0,3,7,10,14,17},    fam=EX },\n  { sym=\"13\",    name=\"Thirteenth\",          iv={0,4,7,10,14,17,21}, fam=EX },\n  { sym=\"maj13\", name=\"Major Thirteenth\",    iv={0,4,7,11,14,17,21}, fam=EX },\n  { sym=\"m13\",   name=\"Minor Thirteenth\",    iv={0,3,7,10,14,17,21}, fam=EX },\n\n  { sym=\"7b9\",       name=\"Seventh Flat Nine\",             iv={0,4,7,10,13},    fam=AL },\n  { sym=\"7#9\",       name=\"Seventh Sharp Nine\",            iv={0,4,7,10,15},    fam=AL },\n  { sym=\"7#11\",      name=\"Seventh Sharp Eleven\",          iv={0,4,7,10,18},    fam=AL },\n  { sym=\"7b13\",      name=\"Seventh Flat Thirteen\",         iv={0,4,7,10,20},    fam=AL },\n  { sym=\"7#5b9\",     name=\"Seventh Sharp Five Flat Nine\",  iv={0,4,8,10,13},    fam=AL },\n  { sym=\"7#5#9\",     name=\"Seventh Sharp Five Sharp Nine\", iv={0,4,8,10,15},    fam=AL },\n  { sym=\"7b5b9\",     name=\"Seventh Flat Five Flat Nine\",   iv={0,4,6,10,13},    fam=AL },\n  { sym=\"7alt\",      name=\"Altered Dominant\",              iv={0,4,8,10,13,15}, fam=AL },\n  { sym=\"13b9\",      name=\"Thirteenth Flat Nine\",          iv={0,4,7,10,13,21}, fam=AL },\n  { sym=\"maj7#11\",   name=\"Major Seventh Sharp Eleven\",    iv={0,4,7,11,18},    fam=AL },\n  { sym=\"m9b5\",      name=\"Minor Ninth Flat Five\",         iv={0,3,6,10,14},    fam=AL },\n  { sym=\"9#5\",       name=\"Ninth Augmented Fifth\",         iv={0,4,8,10,14},    fam=AL },\n  { sym=\"9b5\",       name=\"Ninth Flat Fifth\",              iv={0,4,6,10,14},    fam=AL },\n  { sym=\"9#11\",      name=\"Augmented Eleventh\",            iv={0,4,7,10,14,18}, fam=AL },\n  { sym=\"maj7#5#11\", name=\"Augmented Major Seventh Sharp Eleven\", iv={0,4,8,11,18}, fam=AL },\n  { sym=\"13b9b5\",    name=\"Thirteenth Flat Nine Flat Five\", iv={0,4,6,10,13,21}, fam=AL },\n\n  { sym=\"sus2\",     name=\"Suspended Second\",             iv={0,2,7},       fam=SA },\n  { sym=\"sus4\",     name=\"Suspended Fourth\",             iv={0,5,7},       fam=SA },\n  { sym=\"7sus4\",    name=\"Seventh Suspended Fourth\",     iv={0,5,7,10},    fam=SA },\n  { sym=\"9sus4\",    name=\"Ninth Suspended Fourth\",       iv={0,5,7,10,14}, fam=SA },\n  { sym=\"maj7sus4\", name=\"Major Seventh Suspended Fourth\", iv={0,5,7,11},  fam=SA },\n  { sym=\"add9\",     name=\"Added Ninth\",                  iv={0,4,7,14},    fam=SA },\n  { sym=\"m(add9)\",  name=\"Minor Added Ninth\",            iv={0,3,7,14},    fam=SA },\n  { sym=\"add4\",     name=\"Added Fourth\",                 iv={0,4,5,7},     fam=SA },\n  { sym=\"add11\",    name=\"Added Eleventh\",               iv={0,4,7,17},    fam=SA },\n  { sym=\"add13\",    name=\"Added Thirteenth\",             iv={0,4,7,21},    fam=SA },\n  { sym=\"add2\",     name=\"Added Second\",                 iv={0,2,4,7},     fam=SA },\n  { sym=\"m(add2)\",  name=\"Minor Added Second\",           iv={0,2,3,7},     fam=SA },\n\n  { sym=\"Q4/3\",    name=\"Quartal Triad\",       iv={0,5,10},    fam=QU },\n  { sym=\"Q4/4\",    name=\"Quartal Tetrad\",      iv={0,5,10,15}, fam=QU },\n  { sym=\"Q5/3\",    name=\"Quintal Triad\",       iv={0,7,14},    fam=QU },\n  { sym=\"WT3\",     name=\"Whole-Tone Trichord\", iv={0,2,4},     fam=QU },\n  { sym=\"cluster\", name=\"Chromatic Cluster\",   iv={0,1,2},     fam=QU },\n  { sym=\"dia-cl\",  name=\"Diatonic Cluster\",    iv={0,2,4,5},   fam=QU },\n\n  -- Voiced as they stand rather than reduced to a pitch-class set: the list\n  -- gives the Tristan chord as 0 3 6 10, which makes it a half-diminished\n  -- seventh and indistinguishable from one.\n  { sym=\"Mystic\",    name=\"Mystic (Scriabin)\",   iv={0,6,10,16,21,26}, fam=NA },\n  { sym=\"Petrushka\", name=\"Petrushka\",           iv={0,4,6,7,10,13},   fam=NA },\n  { sym=\"Tristan\",   name=\"Tristan\",             iv={0,6,10,15},       fam=NA },\n  { sym=\"So What\",   name=\"So What\",             iv={0,5,10,15,19},    fam=NA },\n  { sym=\"Dream\",     name=\"Dream\",               iv={0,5,6,7},         fam=NA },\n  { sym=\"Vienna\",    name=\"Viennese Trichord\",   iv={0,1,6},           fam=NA },\n  { sym=\"Vienna II\", name=\"Viennese Trichord II\", iv={0,6,7},          fam=NA },\n  { sym=\"Napoleon\",  name=\"Ode-to-Napoleon\",     iv={0,1,4,5,8,9},     fam=NA },\n  { sym=\"Elektra\",   name=\"Elektra\",             iv={0,7,9,13,16},     fam=NA },\n  { sym=\"Farben\",    name=\"Farben\",              iv={0,8,11,16,21},    fam=NA },\n  { sym=\"It+6\",      name=\"Italian Sixth\",       iv={0,4,10},          fam=NA },\n  { sym=\"Fr+6\",      name=\"French Sixth\",        iv={0,4,6,10},        fam=NA },\n  { sym=\"Ger+6\",     name=\"German Sixth\",        iv={0,4,7,10},        fam=NA },\n}\n\n\n\n-- The symbol a set of pitch classes goes by, read off the chord tables: the\n-- first chord whose notes are exactly these, from this root. \"\" for a major\n-- triad, nil for a set with no name here.\nfunction M.symbolOf(pcs, root)\n  local want = {}\n  for _, pc in ipairs(pcs) do want[(pc - root) % 12] = true end\n  local n = 0\n  for _ in pairs(want) do n = n + 1 end\n  for _, c in ipairs(M.CHORDS) do\n    local have, m = {}, 0\n    for _, iv in ipairs(c.iv) do\n      if not have[iv % 12] then have[iv % 12] = true; m = m + 1 end\n    end\n    if m == n then\n      local same = true\n      for k in pairs(want) do if not have[k] then same = false end end\n      if same then return (c.sym == \"maj\") and \"\" or c.sym end\n    end\n  end\n  return nil\nend\n\n------------------------------------------------------------------------------\n-- What the battle pass adds\n------------------------------------------------------------------------------\n\n-- The scales a reward may be written in, by name. The common ones come up\n-- far more often: a reward should be useful before it is exotic.\nM.REWARD_SCALES = {\n  { \"Major\", 30 }, { \"Minor\", 30 }, { \"Dorian\", 10 }, { \"Mixolydian\", 8 },\n  { \"Harm Minor\", 6 }, { \"Lydian\", 5 }, { \"Phrygian\", 4 },\n}\n\nfunction M.scaleIndex(name)\n  for i, s in ipairs(M.SCALES) do if s.name == name then return i end end\n  return nil\nend\n\n-- The root index (into M.ROOTS) a key note is usually spelled with: the\n-- spelling with the fewest sharps and flats for that scale.\nlocal PREFERRED = { \"C\", \"Db\", \"D\", \"Eb\", \"E\", \"F\", \"F#\", \"G\", \"Ab\", \"A\", \"Bb\", \"B\" }\nfunction M.rootFor(pc)\n  local want = PREFERRED[pc % 12 + 1]\n  for i, rt in ipairs(M.ROOTS) do if rt.name == want then return i end end\n  return 1\nend\n\n-- The triad (or seventh) the scale builds on a degree: its root position, its\n-- pitch classes root first, and its symbol from the chord table.\nfunction M.degreeChord(key, degree, seventh)\n  local root = M.pitch(key, degree)\n  local pcs = { root % 12, M.pitch(key, degree + 2) % 12, M.pitch(key, degree + 4) % 12 }\n  if seventh then pcs[#pcs + 1] = M.pitch(key, degree + 6) % 12 end\n  local name = M.noteName(key, degree)\n  local sym = M.symbolOf(pcs, root % 12) or \"\"\n  return { root = root, pcs = pcs, name = name .. sym, numeral = M.degreeNumeral(key, degree) }\nend\n\nreturn M\n"};

/* ---- kit/palette.js ---- */
/* The devices' colours in Live: after Ableton Live 8's default theme.
 *
 * The scheme is Starting Blocks' own experiment of 18 September 2026
 * (commit 2765b0a3, "theme the window after Live 8"): a neutral grey chrome
 * meant to sit quietly under brightly coloured clips, controls raised off it,
 * and one warm amber spent where Live spends its accent, on what is switched
 * on. It was built from the theme's described character, not Live's own
 * files, so it is a likeness, not a match.
 *
 * Two changes from that experiment, both for the family's rules (every word
 * 7:1 on what it sits on, ink on every button, marks and edges 3:1):
 *   - the chrome is #3E3E3E, a step darker than its #4A4A4A, because on
 *     #4A4A4A a secondary word cannot reach 7:1 and still look secondary;
 *   - buttons are a light grey with dark ink, as the house scheme's are,
 *     because light words on its #5E5E5E buttons reach only 5:1.
 * The greys are neutral (R = G = B), as Live's are: the house rule that
 * every grey leans blue is the yellow scheme's, and Live's look is not that.
 *
 * Palette.tone(r, g, b) is how the REAPER windows (the JSFX and Lua scripts,
 * drawn through gfx.js) take the scheme without a line of theirs changing:
 *   - the house scheme's own colours map one for one (HOUSE below), each
 *     chosen so the pairs the scripts rely on stay 7:1 for words and 3:1
 *     for edges;
 *   - the house yellow, and the shades the scripts make of it, become the
 *     amber, shaded the same way;
 *   - any other grey loses its tint at the same brightness, so a script
 *     with a palette of its own keeps every contrast it had;
 *   - every other colour (a material, an engine, a part) is left alone.
 */
var Palette = (function () {
  'use strict';
  var C = {
    ground: 0x3E3E3E,     // the chrome: Live 8's #4A4A4A, a step darker (see above)
    raised: 0x484848,     // a control that is off
    sunken: 0x2E2E2E,     // lists, fields, a roll or a page: Live 8's roll ground
    deep: 0x262626,       // a roll's own ground under a sunken frame
    popup: 0x333333,      // menus
    rule: 0x555555,       // separators: they group, they do not act
    edge: 0x8C8C8C,       // the edge of anything that acts: 3.2:1 on the chrome
    control: 0xB4B4B4,    // buttons, with ink on them
    controlHover: 0xC4C4C4,
    controlHeld: 0xAAAAAA,
    accent: 0xD7A93C,     // Live 8's warm amber: what is on
    accentHeld: 0xCDA139,  // held: ink on it still 7.2:1
    ink: 0x1A1A1A,        // words on a button, grey or amber; also a window's darkest ground
                          // (AutoCC paints its window in the ink), so words are 7:1 on it too
    text: 0xF0F0F0,       // 9.4:1 on the chrome
    label: 0xD8D8D8,      // 7.5:1
    dim: 0xD4D4D4,        // secondary words, 7.2:1
    mark: 0xA8A8A8,       // a mark that is not a word, or a control that is off
    note: 0xA8D8E8,       // Live 8's cool note colour, for a roll
    ring: 0xFAFAFA,       // the keyboard's place
    warn: 0xF0605A,       // a warning's mark, never its words: 3.3:1 on the chrome
    warnText: 0xFFC8C2    // a warning's words, 7.3:1
  };
  // The house scheme (HousePalette, every family repo's docs/COLOUR.md) to this one.
  var HOUSE = {
    0x111419: C.deep, 0x14171C: C.ink, 0x1A1D23: C.sunken, 0x1B1F25: C.popup, 0x1E2228: 0x343434,
    0x22262D: 0x363636, 0x23272E: C.ground, 0x2A2F37: C.raised, 0x3A404A: C.rule, 0x585F6B: 0x707070,
    0x646B77: 0x7A7A7A, 0x6D7581: C.edge, 0x8A919C: C.mark, 0x8F96A2: C.controlHeld, 0xA9AFBA: C.control,
    0xB0B6C0: C.dim, 0xB6BCC6: C.dim, 0xBFC5CE: C.label, 0xC0C6CF: C.controlHover, 0xDDE1E7: C.text,
    0xF2F4F7: C.ring, 0xFFF200: C.accent, 0xD1C600: C.accentHeld, 0xFF9E96: C.warnText, 0xFFA6A0: C.warnText, 0xD2483F: C.warn
  };
  function rgb(hex, a) {
    return [((hex >> 16) & 255) / 255, ((hex >> 8) & 255) / 255, (hex & 255) / 255, a === undefined ? 1 : a];
  }
  function lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
  function unlin(l) { return l <= 0.0031308 ? l * 12.92 : 1.055 * Math.pow(l, 1 / 2.4) - 0.055; }
  function luminance(r, g, b) { return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b); }
  function contrast(a, b) {
    var la = luminance(a[0], a[1], a[2]), lb = luminance(b[0], b[1], b[2]);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  }
  function clamp(x) { return x < 0 ? 0 : x > 1 ? 1 : x; }
  var AMBER = rgb(C.accent);
  // r, g, b from 0 to 1; returns [r, g, b].
  function tone(r, g, b) {
    r = clamp(r); g = clamp(g); b = clamp(b);
    var R = Math.round(r * 255), G = Math.round(g * 255), B = Math.round(b * 255);
    var hex = (R << 16) | (G << 8) | B;
    if (HOUSE[hex] !== undefined) { var t = rgb(HOUSE[hex]); return [t[0], t[1], t[2]]; }
    // The house yellow and its shades: lighter ones mix in white (blue rises
    // from 0), darker ones scale down (red and green fall together).
    if (R >= 120 && G >= 110 && Math.abs(R - G) <= 40 && B <= Math.min(R, G) - 90) {
      var w = B / 255, k = Math.max(R, G) / 255;
      return [0, 1, 2].map(function (i) { return clamp(AMBER[i] * k + (1 - AMBER[i] * k) * w); });
    }
    // A grey with a tint, from any palette: neutral at the same brightness.
    var hi = Math.max(R, G, B), lo = Math.min(R, G, B);
    if (hi - lo <= 28) { var n = unlin(luminance(r, g, b)); return [n, n, n]; }
    return [r, g, b];
  }
  return { C: C, HOUSE: HOUSE, rgb: rgb, tone: tone, luminance: luminance, contrast: contrast };
})();


/* ---- kit/runtime/polyfill.js ---- */
/* What JavaScriptCore lacks and the Lua runtime uses: TextEncoder and
 * TextDecoder, UTF-8 only, as the web defines them (an invalid byte decodes
 * to U+FFFD and decoding goes on). Installed only where they are missing, so
 * Node and browsers keep their own; MiddawUTF8 is the same code, always, for
 * the tests to hold against the real thing.
 */
(function (G) {
  'use strict';
  function encode(str) {
    var out = [];
    for (var i = 0; i < str.length; i++) {
      var c = str.charCodeAt(i);
      if (c >= 0xD800 && c <= 0xDBFF && i + 1 < str.length) {
        var d = str.charCodeAt(i + 1);
        if (d >= 0xDC00 && d <= 0xDFFF) { c = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00); i++; }
        else c = 0xFFFD;
      } else if (c >= 0xD800 && c <= 0xDFFF) c = 0xFFFD;
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xC0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) out.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else out.push(0xF0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    }
    return new Uint8Array(out);
  }
  function decode(bytes) {
    var b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
    var out = '', i = 0, n = b.length;
    while (i < n) {
      var c = b[i], need = 0, cp = 0, min = 0;
      if (c < 0x80) { out += String.fromCharCode(c); i++; continue; }
      else if (c >= 0xC2 && c <= 0xDF) { need = 1; cp = c & 0x1F; min = 0x80; }
      else if (c >= 0xE0 && c <= 0xEF) { need = 2; cp = c & 0x0F; min = 0x800; }
      else if (c >= 0xF0 && c <= 0xF4) { need = 3; cp = c & 0x07; min = 0x10000; }
      else { out += '�'; i++; continue; }
      var j = 1, ok = true;
      for (; j <= need; j++) {
        if (i + j >= n) { ok = false; break; }
        var x = b[i + j];
        // the second byte's range is narrower for a few leads (no overlongs, no surrogates)
        var lo = 0x80, hi = 0xBF;
        if (j === 1) {
          if (c === 0xE0) lo = 0xA0; else if (c === 0xED) hi = 0x9F;
          else if (c === 0xF0) lo = 0x90; else if (c === 0xF4) hi = 0x8F;
        }
        if (x < lo || x > hi) { ok = false; break; }
        cp = (cp << 6) | (x & 0x3F);
      }
      if (!ok || cp < min) { out += '�'; i += Math.max(1, j); continue; }
      if (cp >= 0x10000) { cp -= 0x10000; out += String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF)); }
      else out += String.fromCharCode(cp);
      i += need + 1;
    }
    return out;
  }
  function Enc() {}
  Enc.prototype.encode = function (s) { return encode(String(s === undefined ? '' : s)); };
  function Dec() {}
  Dec.prototype.decode = function (b) { return decode(b); };
  G.MiddawUTF8 = { TextEncoder: Enc, TextDecoder: Dec };
  if (typeof G.TextEncoder === 'undefined') G.TextEncoder = Enc;
  if (typeof G.TextDecoder === 'undefined') G.TextDecoder = Dec;
})(typeof globalThis !== 'undefined' ? globalThis : this);


/* ---- kit/runtime/lua_parse.js ---- */
/* Middaw's Lua 5.4, part 1 of 3: the lexer and the parser.
 *
 * Middaw runs the family's Lua engines (Good Idea, Midi Suggester, Midi
 * Variator, Midi Catalogue, Starting Blocks, DAW Battle Pass...) unchanged, in
 * the browser, with no third-party code: this file reads Lua source into a
 * syntax tree, lua_compile.js turns the tree into JavaScript, lua_runtime.js
 * supplies the values and the standard library. tests/js/test_lua.js holds
 * all three to what the real Lua 5.4 prints for the same programs.
 *
 * Source is a "byte string": one JS character per byte of the file, which is
 * how Lua itself sees a string, so `#s` and string.sub count bytes as Lua does.
 */
(function (NS) {
  'use strict';

  var KEYWORDS = {};
  ('and break do else elseif end false for function goto if in local nil not ' +
   'or repeat return then true until while').split(' ').forEach(function (k) { KEYWORDS[k] = true; });

  function LuaSyntaxError(message, chunk, line) {
    this.message = chunk + ':' + line + ': ' + message;
    this.line = line;
  }
  LuaSyntaxError.prototype = Object.create(Error.prototype);
  LuaSyntaxError.prototype.name = 'LuaSyntaxError';

  function isDigit(c) { return c >= 48 && c <= 57; }
  function isHex(c) { return isDigit(c) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70); }
  function isAlpha(c) { return (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c === 95; }
  function isSpace(c) { return c === 32 || (c >= 9 && c <= 13); }

  // ---------------------------------------------------------------- lexer --
  function lex(src, chunk) {
    var toks = [];
    var i = 0, n = src.length, line = 1;
    function err(msg) { throw new LuaSyntaxError(msg, chunk, line); }
    function longBracketLevel(at) {   // at points to '['; returns level or -1
      var j = at + 1, level = 0;
      while (src.charCodeAt(j) === 61) { level++; j++; }
      return src.charCodeAt(j) === 91 ? level : -1;
    }
    function readLong(at, level) {    // returns [content, end index]
      var start = at + level + 2;
      // a newline straight after the opening bracket is skipped
      if (src[start] === '\r') { start++; if (src[start] === '\n') start++; }
      else if (src[start] === '\n') { start++; if (src[start] === '\r') start++; }
      var close = ']' + '='.repeat(level) + ']';
      var end = src.indexOf(close, start);
      if (end < 0) err('unfinished long string');
      var body = src.slice(start, end);
      for (var k = at; k < end + close.length; k++) if (src.charCodeAt(k) === 10) line++;
      return [body, end + close.length];
    }
    while (i < n) {
      var c = src.charCodeAt(i);
      if (c === 10) { line++; i++; continue; }
      if (isSpace(c)) { i++; continue; }
      if (c === 45 && src.charCodeAt(i + 1) === 45) {           // comment
        i += 2;
        if (src.charCodeAt(i) === 91) {
          var lvl = longBracketLevel(i);
          if (lvl >= 0) { i = readLong(i, lvl)[1]; continue; }
        }
        while (i < n && src.charCodeAt(i) !== 10) i++;
        continue;
      }
      var tline = line;
      if (isAlpha(c)) {
        var j = i + 1;
        while (j < n && (isAlpha(src.charCodeAt(j)) || isDigit(src.charCodeAt(j)))) j++;
        var word = src.slice(i, j);
        toks.push(KEYWORDS[word] ? { t: word, line: tline } : { t: 'name', v: word, line: tline });
        i = j; continue;
      }
      if (isDigit(c) || (c === 46 && isDigit(src.charCodeAt(i + 1)))) {
        var j2 = i, isFloat = false, text;
        if (c === 48 && (src[i + 1] === 'x' || src[i + 1] === 'X')) {
          j2 = i + 2;
          while (j2 < n) {
            var d = src.charCodeAt(j2);
            if (isHex(d) || d === 46) { if (d === 46) isFloat = true; j2++; }
            else if ((d === 112 || d === 80)) {
              isFloat = true; j2++;
              if (src[j2] === '+' || src[j2] === '-') j2++;
            } else break;
          }
        } else {
          while (j2 < n) {
            var e = src.charCodeAt(j2);
            if (isDigit(e) || e === 46) { if (e === 46) isFloat = true; j2++; }
            else if (e === 101 || e === 69) {
              isFloat = true; j2++;
              if (src[j2] === '+' || src[j2] === '-') j2++;
            } else break;
          }
        }
        text = src.slice(i, j2);
        if (j2 < n && (isAlpha(src.charCodeAt(j2)))) err("malformed number near '" + text + src[j2] + "'");
        toks.push({ t: 'number', v: text, line: tline });
        i = j2; continue;
      }
      if (c === 34 || c === 39) {                                // short string
        var q = c, out = [], k = i + 1;
        for (;;) {
          if (k >= n) err('unfinished string');
          var ch = src.charCodeAt(k);
          if (ch === q) { k++; break; }
          if (ch === 10) err('unfinished string');
          if (ch === 92) {
            var x = src[k + 1];
            k += 2;
            switch (x) {
              case 'n': out.push('\n'); break;
              case 't': out.push('\t'); break;
              case 'r': out.push('\r'); break;
              case 'a': out.push('\x07'); break;
              case 'b': out.push('\b'); break;
              case 'f': out.push('\f'); break;
              case 'v': out.push('\v'); break;
              case '\\': out.push('\\'); break;
              case '"': out.push('"'); break;
              case "'": out.push("'"); break;
              case '\n': line++; out.push('\n'); break;
              case 'x': {
                var hx = src.slice(k, k + 2);
                if (!/^[0-9a-fA-F]{2}$/.test(hx)) err('hexadecimal digit expected');
                out.push(String.fromCharCode(parseInt(hx, 16))); k += 2; break;
              }
              case 'z': {
                while (k < n && isSpace(src.charCodeAt(k))) { if (src.charCodeAt(k) === 10) line++; k++; }
                break;
              }
              case 'u': {
                if (src[k] !== '{') err("missing '{' in \\u{xxxx}");
                var close = src.indexOf('}', k);
                var cp = parseInt(src.slice(k + 1, close), 16);
                k = close + 1;
                out.push(utf8Bytes(cp)); break;
              }
              default: {
                if (x !== undefined && isDigit(x.charCodeAt(0))) {
                  var digits = x; var m = 0;
                  while (m < 2 && isDigit(src.charCodeAt(k))) { digits += src[k]; k++; m++; }
                  var val = parseInt(digits, 10);
                  if (val > 255) err('decimal escape too large');
                  out.push(String.fromCharCode(val));
                } else err('invalid escape sequence');
              }
            }
            continue;
          }
          out.push(src[k]); k++;
        }
        toks.push({ t: 'string', v: out.join(''), line: tline });
        i = k; continue;
      }
      if (c === 91) {
        var lv = longBracketLevel(i);
        if (lv >= 0) {
          var r = readLong(i, lv);
          toks.push({ t: 'string', v: r[0], line: tline });
          i = r[1]; continue;
        }
      }
      var three = src.substr(i, 3), two = src.substr(i, 2);
      if (three === '...') { toks.push({ t: '...', line: tline }); i += 3; continue; }
      if (two === '==' || two === '~=' || two === '<=' || two === '>=' || two === '//' ||
          two === '::' || two === '<<' || two === '>>' || two === '..') {
        toks.push({ t: two, line: tline }); i += 2; continue;
      }
      var one = src[i];
      if ('+-*/%^#&~|<>=(){}[];:,.'.indexOf(one) >= 0) { toks.push({ t: one, line: tline }); i++; continue; }
      err("unexpected symbol near '" + one + "'");
    }
    toks.push({ t: '<eof>', line: line });
    return toks;
  }

  function utf8Bytes(cp) {
    if (cp < 0x80) return String.fromCharCode(cp);
    if (cp < 0x800) return String.fromCharCode(0xC0 | (cp >> 6), 0x80 | (cp & 63));
    if (cp < 0x10000) return String.fromCharCode(0xE0 | (cp >> 12), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
    return String.fromCharCode(0xF0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
  }

  // --------------------------------------------------------------- parser --
  // Binary priorities exactly as lparser.c has them: { left, right }.
  var BINARY = {
    '+': [10, 10], '-': [10, 10], '*': [11, 11], '%': [11, 11], '^': [14, 13],
    '/': [11, 11], '//': [11, 11], '&': [6, 6], '|': [4, 4], '~': [5, 5],
    '<<': [7, 7], '>>': [7, 7], '..': [9, 8],
    '==': [3, 3], '<': [3, 3], '<=': [3, 3], '~=': [3, 3], '>': [3, 3], '>=': [3, 3],
    'and': [2, 2], 'or': [1, 1]
  };
  var UNARY_PRIORITY = 12;

  function parse(src, chunk) {
    chunk = chunk || '?';
    var toks = lex(src, chunk);
    var p = 0;
    function peek() { return toks[p]; }
    function next() { return toks[p++]; }
    function check(t) { return toks[p].t === t; }
    function err(msg, tok) {
      tok = tok || toks[p];
      var near = tok.t === '<eof>' ? '<eof>' : (tok.v !== undefined ? tok.v : tok.t);
      throw new LuaSyntaxError(msg + " near '" + near + "'", chunk, tok.line);
    }
    function expect(t, what) {
      if (toks[p].t !== t) err("'" + t + "' expected" + (what ? ' (to close ' + what + ')' : ''));
      return toks[p++];
    }
    function accept(t) { if (toks[p].t === t) { p++; return true; } return false; }
    function name() {
      if (toks[p].t !== 'name') err('<name> expected');
      return toks[p++].v;
    }

    function blockFollow(withUntil) {
      var t = toks[p].t;
      return t === 'else' || t === 'elseif' || t === 'end' || t === '<eof>' || (withUntil && t === 'until');
    }

    function block() {
      var body = [];
      while (!blockFollow(true)) {
        if (check('return')) { body.push(retstat()); break; }
        var s = statement();
        if (s) body.push(s);
      }
      return body;
    }

    function retstat() {
      var tok = next();
      var exprs = [];
      if (!blockFollow(true) && !check(';')) exprs = exprlist();
      accept(';');
      return { k: 'Return', exprs: exprs, line: tok.line };
    }

    function statement() {
      var tok = peek(), line = tok.line;
      switch (tok.t) {
        case ';': next(); return null;
        case 'if': return ifstat();
        case 'while': {
          next(); var cond = expr(); expect('do'); var b = block(); expect('end', 'while');
          return { k: 'While', cond: cond, body: b, line: line };
        }
        case 'do': { next(); var b2 = block(); expect('end', 'do'); return { k: 'Do', body: b2, line: line }; }
        case 'for': return forstat();
        case 'repeat': {
          next(); var b3 = block(); expect('until', 'repeat'); var c3 = expr();
          return { k: 'Repeat', body: b3, cond: c3, line: line };
        }
        case 'function': {
          next();
          var target = { k: 'Name', name: name(), line: line }, isMethod = false;
          while (check('.') || check(':')) {
            var sep = next().t;
            var key = name();
            target = { k: 'Index', obj: target, key: { k: 'String', v: key }, line: line };
            if (sep === ':') { isMethod = true; break; }
          }
          var f = funcbody(isMethod, line);
          return { k: 'Assign', targets: [target], exprs: [f], line: line };
        }
        case 'local': {
          next();
          if (accept('function')) {
            var nm = name();
            return { k: 'LocalFunction', name: nm, func: funcbody(false, line), line: line };
          }
          var names = [], attribs = [];
          do {
            names.push(name());
            if (accept('<')) { attribs.push(name()); expect('>'); } else attribs.push(null);
          } while (accept(','));
          var exprs = accept('=') ? exprlist() : [];
          return { k: 'Local', names: names, attribs: attribs, exprs: exprs, line: line };
        }
        case '::': { next(); var label = name(); expect('::'); return { k: 'Label', name: label, line: line }; }
        case 'return': return retstat();
        case 'break': next(); return { k: 'Break', line: line };
        case 'goto': next(); return { k: 'Goto', name: name(), line: line };
        default: return exprstat();
      }
    }

    function ifstat() {
      var line = next().line;
      var clauses = [];
      var cond = expr(); expect('then');
      clauses.push({ cond: cond, body: block() });
      var orelse = null;
      for (;;) {
        if (accept('elseif')) { var c = expr(); expect('then'); clauses.push({ cond: c, body: block() }); }
        else if (accept('else')) { orelse = block(); expect('end', 'if'); break; }
        else { expect('end', 'if'); break; }
      }
      return { k: 'If', clauses: clauses, orelse: orelse, line: line };
    }

    function forstat() {
      var line = next().line;
      var n1 = name();
      if (accept('=')) {
        var start = expr(); expect(',');
        var limit = expr();
        var step = accept(',') ? expr() : null;
        expect('do'); var b = block(); expect('end', 'for');
        return { k: 'NumFor', name: n1, start: start, limit: limit, step: step, body: b, line: line };
      }
      var names = [n1];
      while (accept(',')) names.push(name());
      expect('in');
      var exprs = exprlist();
      expect('do'); var body = block(); expect('end', 'for');
      return { k: 'GenFor', names: names, exprs: exprs, body: body, line: line };
    }

    function exprstat() {
      var line = peek().line;
      var e = suffixedexp();
      if (check('=') || check(',')) {
        var targets = [e];
        while (accept(',')) targets.push(suffixedexp());
        expect('=');
        var exprs = exprlist();
        targets.forEach(function (t) { if (t.k !== 'Name' && t.k !== 'Index') err('syntax error'); });
        return { k: 'Assign', targets: targets, exprs: exprs, line: line };
      }
      if (e.k !== 'Call' && e.k !== 'Method') err('syntax error');
      return { k: 'ExprStat', expr: e, line: line };
    }

    function exprlist() {
      var list = [expr()];
      while (accept(',')) list.push(expr());
      return list;
    }

    function funcbody(isMethod, line) {
      var params = isMethod ? ['self'] : [], vararg = false;
      expect('(');
      if (!check(')')) {
        do {
          if (accept('...')) { vararg = true; break; }
          params.push(name());
        } while (accept(','));
      }
      expect(')');
      var b = block();
      var endTok = expect('end', 'function');
      return { k: 'Function', params: params, vararg: vararg, body: b, line: line, endLine: endTok.line };
    }

    function primaryexp() {
      var tok = peek();
      if (tok.t === 'name') { next(); return { k: 'Name', name: tok.v, line: tok.line }; }
      if (tok.t === '(') {
        next(); var e = expr(); expect(')');
        return { k: 'Paren', expr: e, line: tok.line };
      }
      err('unexpected symbol');
    }

    function suffixedexp() {
      var e = primaryexp();
      for (;;) {
        var tok = peek();
        switch (tok.t) {
          case '.': next(); e = { k: 'Index', obj: e, key: { k: 'String', v: name() }, line: tok.line }; break;
          case '[': next(); var key = expr(); expect(']'); e = { k: 'Index', obj: e, key: key, line: tok.line }; break;
          case ':': next(); var m = name(); e = { k: 'Method', obj: e, name: m, args: callargs(), line: tok.line }; break;
          case '(': case 'string': case '{': e = { k: 'Call', fn: e, args: callargs(), line: tok.line }; break;
          default: return e;
        }
      }
    }

    function callargs() {
      var tok = peek();
      if (tok.t === 'string') { next(); return [{ k: 'String', v: tok.v }]; }
      if (tok.t === '{') return [tablecons()];
      expect('(');
      if (accept(')')) return [];
      var args = exprlist();
      expect(')');
      return args;
    }

    function tablecons() {
      var line = expect('{').line;
      var items = [];   // { kind: 'pos'|'named'|'keyed', key, value }
      while (!check('}')) {
        if (check('name') && toks[p + 1].t === '=') {
          var key = next().v; next();
          items.push({ kind: 'keyed', key: { k: 'String', v: key }, value: expr() });
        } else if (check('[')) {
          next(); var k = expr(); expect(']'); expect('=');
          items.push({ kind: 'keyed', key: k, value: expr() });
        } else {
          items.push({ kind: 'pos', value: expr() });
        }
        if (!accept(',') && !accept(';')) break;
      }
      expect('}', 'table');
      return { k: 'Table', items: items, line: line };
    }

    function simpleexp() {
      var tok = peek();
      switch (tok.t) {
        case 'number': next(); return { k: 'Number', v: tok.v, line: tok.line };
        case 'string': next(); return { k: 'String', v: tok.v };
        case 'nil': next(); return { k: 'Nil' };
        case 'true': next(); return { k: 'True' };
        case 'false': next(); return { k: 'False' };
        case '...': next(); return { k: 'Vararg', line: tok.line };
        case '{': return tablecons();
        case 'function': next(); return funcbody(false, tok.line);
        default: return suffixedexp();
      }
    }

    function expr(limit) {
      limit = limit || 0;
      var left, tok = peek();
      if (tok.t === 'not' || tok.t === '-' || tok.t === '#' || tok.t === '~') {
        next();
        left = { k: 'Unop', op: tok.t, expr: expr(UNARY_PRIORITY), line: tok.line };
      } else {
        left = simpleexp();
      }
      for (;;) {
        var op = peek().t, pr = BINARY[op];
        if (!pr || pr[0] <= limit) break;
        var line = next().line;
        var right = expr(pr[1]);
        left = { k: 'Binop', op: op, left: left, right: right, line: line };
      }
      return left;
    }

    var body = block();
    if (!check('<eof>')) err("'<eof>' expected");
    return { k: 'Chunk', body: body };
  }

  NS.lex = lex;
  NS.parse = parse;
  NS.LuaSyntaxError = LuaSyntaxError;
  NS.utf8Bytes = utf8Bytes;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawLua = globalThis.MiddawLua || {}))
  : (globalThis.MiddawLua = globalThis.MiddawLua || {}));


/* ---- kit/runtime/lua_runtime.js ---- */
/* Middaw's Lua 5.4, part 3 of 3: values, operators and the standard library.
 *
 * Values, as JavaScript sees them:
 *   nil      undefined
 *   boolean  true / false
 *   number   a JS number. An integral JS number is a Lua *integer*; a
 *            non-integral one (or inf, nan) is a Lua *float*. A float whose
 *            value happens to be integral (4.0, 2/2) is an LFloat, so that it
 *            still prints "4.0" and math.type still says "float".
 *   string   a JS string with one character per byte (0-255)
 *   table    LuaTable
 *   function a JS function: Lua arguments in, and undefined, one value, or a
 *            Multi for two or more results.
 *
 * Wherever the result has to match the real Lua byte for byte - table.sort
 * with ties, the pattern matcher, math.random, number formatting - the code
 * is a port of Lua 5.4's own C, not a lookalike.
 */
(function (NS) {
  'use strict';

  // ------------------------------------------------------------ values ----
  function LFloat(n) { this.n = n; }
  LFloat.prototype.valueOf = function () { return this.n; };

  function mkf(x) { return Number.isInteger(x) ? new LFloat(x) : x; }
  function isNum(v) { return typeof v === 'number' || v instanceof LFloat; }
  function num(v) { return typeof v === 'number' ? v : v.n; }
  function isFloatVal(v) { return v instanceof LFloat || (typeof v === 'number' && !Number.isInteger(v)); }

  function Multi(a) { this.a = a; }
  function first(v) { return v instanceof Multi ? v.a[0] : v; }
  // `return` with no values gives NONE; a bare undefined is one nil.
  var NONE = new Multi([]);
  var NIL1 = Object.freeze([undefined]);
  function sp(v) {
    if (v instanceof Multi) return v.a;
    return v === undefined ? NIL1 : [v];
  }
  function ret(list) {
    if (list.length === 0) return NONE;
    if (list.length === 1) return list[0];
    return new Multi(list);
  }

  var tableIds = 0;
  function LuaTable() { this.arr = []; this.hash = null; this.mt = null; this.id = 0; this.hver = 0; }
  LuaTable.prototype.get = function (k) {
    if (typeof k === 'number') {
      var a = this.arr;
      if (k > 0 && k <= a.length && Number.isInteger(k)) return a[k - 1];
    } else if (typeof k === 'string') {
      return this.hash === null ? undefined : this.hash.get(k);
    } else if (k instanceof LFloat) {
      return this.get(k.n);
    }
    return this.hash === null ? undefined : this.hash.get(k);
  };
  LuaTable.prototype.set = function (k, v) {
    if (typeof k === 'number') {
      if (Number.isInteger(k) && k > 0) {
        var a = this.arr, n = a.length;
        if (k <= n) {
          a[k - 1] = v;
          if (v === undefined && k === n) { while (a.length && a[a.length - 1] === undefined) a.pop(); }
          return;
        }
        if (k === n + 1) {
          if (v === undefined) { if (this.hash !== null) this.hash.delete(k); return; }
          a.push(v);
          if (this.hash !== null && this.hash.size) {
            var h = this.hash;
            while (h.has(a.length + 1)) { var nk = a.length + 1; a.push(h.get(nk)); h.delete(nk); }
          }
          return;
        }
      } else if (k !== k) {
        throw rterror('table index is NaN');
      }
    } else if (k instanceof LFloat) {
      return this.set(k.n, v);
    } else if (k === undefined) {
      throw rterror('table index is nil');
    }
    if (v === undefined) { if (this.hash !== null) this.hash.delete(k); return; }
    if (this.hash === null) this.hash = new Map();
    if (!this.hash.has(k)) this.hver++;
    this.hash.set(k, v);
  };
  LuaTable.prototype.length = function () { return this.arr.length; };

  // ------------------------------------------------------------ errors ----
  // Compiled chunks register their line maps here, so an error can say
  // "gi_idea.lua:1234:" as the real Lua would.
  var lineMaps = {};
  function luaPosition(level) {
    var stack = new Error().stack || '';
    var re = /lua:([^:\s()]+):(\d+):\d+/g, m, found = 0;
    while ((m = re.exec(stack)) !== null) {
      found++;
      if (found >= level) {
        var map = lineMaps[m[1]];
        var line = map ? map[Number(m[2]) - 1] : undefined;
        if (line) return m[1] + ':' + line + ': ';
        return m[1] + ': ';
      }
    }
    return '';
  }
  function LuaError(value, traceback) {
    this.value = value;
    this.message = typeof value === 'string' ? value : tostring(value);
    this.luaTraceback = traceback;
    this.stack = new Error().stack;
  }
  LuaError.prototype = Object.create(Error.prototype);
  LuaError.prototype.name = 'LuaError';
  function rterror(msg) { return new LuaError(luaPosition(1) + msg); }

  function typeName(v) {
    if (v === undefined || v === null) return 'nil';
    switch (typeof v) {
      case 'boolean': return 'boolean';
      case 'number': return 'number';
      case 'string': return 'string';
      case 'function': return 'function';
    }
    if (v instanceof LFloat) return 'number';
    if (v instanceof LuaTable) return 'table';
    return 'userdata';
  }

  // --------------------------------------------------------- numbers ----
  // Exact decimal expansion of a double: x = D * 10^-s, D a BigInt.
  var F64 = new Float64Array(1), U32 = new Uint32Array(F64.buffer);
  function exactDecimal(x) {
    F64[0] = x;
    var hi = U32[1], lo = U32[0];
    var exp = (hi >>> 20) & 0x7ff;
    var mant = (BigInt(hi & 0xfffff) << 32n) | BigInt(lo);
    if (exp === 0) exp = 1; else mant |= 1n << 52n;
    var e = exp - 1075;
    if (e >= 0) return { D: mant << BigInt(e), s: 0 };
    return { D: mant * (5n ** BigInt(-e)), s: -e };
  }
  function roundDiv(N, div) {      // round N/div half to even
    var q = N / div, r = N % div;
    var twice = r * 2n;
    if (twice > div || (twice === div && (q & 1n) === 1n)) q += 1n;
    return q;
  }
  function fixedDigits(x, f) {     // |x| to f decimals, C-exact; returns string
    var ex = exactDecimal(Math.abs(x));
    var q;
    if (f >= ex.s) q = ex.D * (10n ** BigInt(f - ex.s));
    else q = roundDiv(ex.D, 10n ** BigInt(ex.s - f));
    var s = q.toString();
    if (f === 0) return s;
    while (s.length <= f) s = '0' + s;
    return s.slice(0, s.length - f) + '.' + s.slice(s.length - f);
  }
  function expDigits(x, prec) {    // |x| as d.ddd with prec decimals; returns [mantissa, exponent]
    if (x === 0) return [prec > 0 ? '0.' + '0'.repeat(prec) : '0', 0];
    var ex = exactDecimal(Math.abs(x));
    var D = ex.D.toString();
    var X = D.length - 1 - ex.s;
    var P = prec + 1, q;
    if (D.length > P) {
      q = roundDiv(ex.D, 10n ** BigInt(D.length - P)).toString();
      if (q.length > P) { q = q.slice(0, P); X++; }
    } else q = D + '0'.repeat(P - D.length);
    return [prec > 0 ? q[0] + '.' + q.slice(1) : q, X];
  }
  function fmtExp(x, prec, upper) {
    var r = expDigits(x, prec);
    var X = r[1];
    var s = r[0] + (upper ? 'E' : 'e') + (X < 0 ? '-' : '+') + (Math.abs(X) < 10 ? '0' : '') + Math.abs(X);
    return s;
  }
  function stripZeros(s) {
    if (s.indexOf('.') < 0) return s;
    s = s.replace(/0+$/, '');
    return s.replace(/\.$/, '');
  }
  function fmtG(x, P, upper, alt) {   // C's %g of |x|
    if (P === 0) P = 1;
    if (x === 0) return '0';
    var X = expDigits(x, P - 1)[1];
    var s;
    if (X < -4 || X >= P) {
      var r = expDigits(x, P - 1);
      var m = alt ? r[0] : stripZeros(r[0]);
      s = m + (upper ? 'E' : 'e') + (r[1] < 0 ? '-' : '+') + (Math.abs(r[1]) < 10 ? '0' : '') + Math.abs(r[1]);
    } else {
      s = fixedDigits(x, P - 1 - X);
      if (!alt) s = stripZeros(s);
    }
    return s;
  }
  function floatStr(x) {
    if (x === Infinity) return 'inf';
    if (x === -Infinity) return '-inf';
    if (x !== x) return (1 / x) < 0 ? 'nan' : '-nan';
    var neg = x < 0 || (x === 0 && 1 / x < 0);
    var s = (neg ? '-' : '') + fmtG(x, 14, false, false);
    if (/^-?\d+$/.test(s)) s += '.0';
    return s;
  }
  function intStr(n) {
    if (Math.abs(n) <= 9007199254740992) return String(n === 0 ? 0 : n);
    return BigInt(n).toString();
  }
  // io.write prints a float with LUA_NUMBER_FMT alone: 1.0 is "1".
  function writeNum(v) {
    if (!isNum(v)) throw rterror('bad argument to \'write\' (string expected, got ' + typeName(v) + ')');
    if (typeof v === 'number' && Number.isInteger(v)) return intStr(v);
    var x = num(v);
    if (x === Infinity) return 'inf';
    if (x === -Infinity) return '-inf';
    if (x !== x) return '-nan';
    return (x < 0 || (x === 0 && 1 / x < 0) ? '-' : '') + fmtG(Math.abs(x), 14, false, false);
  }
  function numStr(v) {
    if (typeof v === 'number') return Number.isInteger(v) ? intStr(v) : floatStr(v);
    return floatStr(v.n);
  }

  // lua_stringtonumber: a whole numeral, spaces either side, or undefined.
  function str2num(s) {
    var t = s.replace(/^[ \f\n\r\t\v]+|[ \f\n\r\t\v]+$/g, '');
    var m;
    if ((m = /^([+-])?0[xX]([0-9a-fA-F]*)(?:\.([0-9a-fA-F]*))?(?:[pP]([+-]?\d+))?$/.exec(t))) {
      var ip = m[2], fp = m[3], ex = m[4];
      if (!ip && !fp) return undefined;
      var neg = m[1] === '-';
      if (fp === undefined && ex === undefined) {
        var big = BigInt.asIntN(64, BigInt('0x' + ip));
        var n = Number(big);
        return neg ? 0 - n : n;
      }
      var val = 0;
      for (var i = 0; i < ip.length; i++) val = val * 16 + parseInt(ip[i], 16);
      var scale = 1 / 16;
      fp = fp || '';
      for (var j = 0; j < fp.length; j++) { val += parseInt(fp[j], 16) * scale; scale /= 16; }
      if (ex) val *= Math.pow(2, Number(ex));
      return mkf(neg ? -val : val);
    }
    if ((m = /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.exec(t))) {
      var isInt = m[1].indexOf('.') < 0 && !m[2];
      var v = Number(t);
      if (isInt) {
        if (Math.abs(v) <= 9223372036854775807) return v;
        return mkf(v);
      }
      return mkf(v);
    }
    return undefined;
  }

  function toNumberArith(v, op) {
    if (typeof v === 'number') return v;
    if (v instanceof LFloat) return v;
    if (typeof v === 'string') { var n = str2num(v); if (n !== undefined) return n; }
    return null;
  }
  function arithError(op, a, b) {
    var bad = (isNum(a) || (typeof a === 'string' && str2num(a) !== undefined)) ? b : a;
    if (op === 'concat') return rterror('attempt to concatenate a ' + typeName(bad) + ' value');
    if (op === 'bit') return rterror('attempt to perform bitwise operation on a ' + typeName(bad) + ' value');
    return rterror('attempt to perform arithmetic on a ' + typeName(bad) + ' value');
  }
  function metaOf(v) {
    if (v instanceof LuaTable) return v.mt;
    if (typeof v === 'string') return stringMeta;
    return null;
  }
  function metaBin(ev, a, b) {
    var mt = metaOf(a), h = mt && mt.get(ev);
    if (h === undefined) { mt = metaOf(b); h = mt && mt.get(ev); }
    if (h === undefined || h === null) return NOMETA;
    return first(call(h)(a, b));
  }
  var NOMETA = {};

  function arithSlow(op, a, b, ev) {
    var x = toNumberArith(a), y = toNumberArith(b);
    if (x === null || y === null) {
      var r = metaBin(ev, a, b);
      if (r !== NOMETA) return r;
      throw arithError(op, a, b);
    }
    switch (op) {
      case 'add': return add(x, y);
      case 'sub': return sub(x, y);
      case 'mul': return mul(x, y);
      case 'div': return div(x, y);
      case 'mod': return mod(x, y);
      case 'idiv': return idiv(x, y);
      case 'pow': return pow(x, y);
    }
  }
  function add(a, b) {
    if (typeof a === 'number' && typeof b === 'number') {
      var r = a + b;
      return (Number.isInteger(a) && Number.isInteger(b)) ? r : mkf(r);
    }
    if (isNum(a) && isNum(b)) return mkf(num(a) + num(b));
    return arithSlow('add', a, b, '__add');
  }
  function sub(a, b) {
    if (typeof a === 'number' && typeof b === 'number') {
      var r = a - b;
      return (Number.isInteger(a) && Number.isInteger(b)) ? r : mkf(r);
    }
    if (isNum(a) && isNum(b)) return mkf(num(a) - num(b));
    return arithSlow('sub', a, b, '__sub');
  }
  function mul(a, b) {
    if (typeof a === 'number' && typeof b === 'number') {
      var r = a * b;
      if (Number.isInteger(a) && Number.isInteger(b)) return r === 0 ? 0 : r;
      return mkf(r);
    }
    if (isNum(a) && isNum(b)) return mkf(num(a) * num(b));
    return arithSlow('mul', a, b, '__mul');
  }
  function div(a, b) {
    if (isNum(a) && isNum(b)) return mkf(num(a) / num(b));
    return arithSlow('div', a, b, '__div');
  }
  function idiv(a, b) {
    if (typeof a === 'number' && typeof b === 'number' && Number.isInteger(a) && Number.isInteger(b)) {
      if (b === 0) throw rterror("attempt to perform 'n//0'");
      var q = Math.floor(a / b);
      return q === 0 ? 0 : q;
    }
    if (isNum(a) && isNum(b)) return mkf(Math.floor(num(a) / num(b)));
    return arithSlow('idiv', a, b, '__idiv');
  }
  function mod(a, b) {
    if (typeof a === 'number' && typeof b === 'number' && Number.isInteger(a) && Number.isInteger(b)) {
      if (b === 0) throw rterror("attempt to perform 'n%%0'");
      var r = a % b;
      if (r !== 0 && (r < 0) !== (b < 0)) r += b;
      return r === 0 ? 0 : r;
    }
    if (isNum(a) && isNum(b)) {
      var x = num(a), y = num(b);
      var m;
      if (y === Infinity || y === -Infinity) m = x;
      else m = x % y;
      if ((m > 0) ? y < 0 : (m < 0 && y !== m)) m += y;
      return mkf(m);
    }
    return arithSlow('mod', a, b, '__mod');
  }
  function pow(a, b) {
    if (isNum(a) && isNum(b)) return mkf(Math.pow(num(a), num(b)));
    return arithSlow('pow', a, b, '__pow');
  }
  function unm(a) {
    if (typeof a === 'number') return Number.isInteger(a) ? 0 - a : -a;
    if (a instanceof LFloat) return new LFloat(-a.n);
    var x = toNumberArith(a);
    if (x !== null) return unm(x);
    var mt = metaOf(a), h = mt && mt.get('__unm');
    if (h !== undefined && h !== null) return first(call(h)(a, a));
    throw rterror('attempt to perform arithmetic on a ' + typeName(a) + ' value');
  }

  // Bitwise operations work on 64-bit integers.
  function toInt64(v, a, b) {
    var x = typeof v === 'string' ? str2num(v) : v;
    if (typeof x === 'number' && Number.isInteger(x)) return BigInt(x);
    if (x instanceof LFloat) return BigInt(x.n);
    if (typeof x === 'number') throw rterror('number has no integer representation');
    throw arithError('bit', a, b);
  }
  function fromInt64(big) { return Number(BigInt.asIntN(64, big)); }
  function small(a, b) {
    return typeof a === 'number' && typeof b === 'number' && (a | 0) === a && (b | 0) === b;
  }
  function band(a, b) { if (small(a, b)) return a & b; return bitSlow('__band', a, b, function (x, y) { return x & y; }); }
  function bor(a, b) { if (small(a, b)) return a | b; return bitSlow('__bor', a, b, function (x, y) { return x | y; }); }
  function bxor(a, b) { if (small(a, b)) return a ^ b; return bitSlow('__bxor', a, b, function (x, y) { return x ^ y; }); }
  function shiftLeft(x, n) {
    if (n <= -64n || n >= 64n) return 0n;
    if (n >= 0n) return BigInt.asUintN(64, x << n);
    return BigInt.asUintN(64, x) >> (-n);
  }
  function shl(a, b) { return bitSlow('__shl', a, b, function (x, y) { return shiftLeft(x, y); }); }
  function shr(a, b) { return bitSlow('__shr', a, b, function (x, y) { return shiftLeft(x, -y); }); }
  function bnot(a) {
    if (typeof a === 'number' && (a | 0) === a) return ~a;
    var mt = metaOf(a), h = mt && mt.get('__bnot');
    if (h !== undefined && h !== null && !isNum(a)) return first(call(h)(a, a));
    return fromInt64(~toInt64(a, a, a));
  }
  function bitSlow(ev, a, b, f) {
    if (!((isNum(a) || typeof a === 'string') && (isNum(b) || typeof b === 'string'))) {
      var r = metaBin(ev, a, b);
      if (r !== NOMETA) return r;
    }
    return fromInt64(f(toInt64(a, a, b), toInt64(b, a, b)));
  }

  function concat(a, b) {
    var ta = typeof a, tb = typeof b;
    if (ta === 'string' && tb === 'string') return a + b;
    if ((ta === 'string' || isNum(a)) && (tb === 'string' || isNum(b))) {
      return (ta === 'string' ? a : numStr(a)) + (tb === 'string' ? b : numStr(b));
    }
    var r = metaBin('__concat', a, b);
    if (r !== NOMETA) return r;
    throw arithError('concat', a, b);
  }

  function len(v) {
    if (typeof v === 'string') return v.length;
    if (v instanceof LuaTable) {
      if (v.mt !== null) {
        var h = v.mt.get('__len');
        if (h !== undefined) return first(call(h)(v));
      }
      return v.arr.length;
    }
    var mt = metaOf(v), h2 = mt && mt.get('__len');
    if (h2 !== undefined && h2 !== null) return first(call(h2)(v));
    throw rterror('attempt to get length of a ' + typeName(v) + ' value');
  }

  function eq(a, b) {
    if (a === b) return true;
    var ta = typeof a, tb = typeof b;
    if (ta === 'object' || tb === 'object') {
      if (isNum(a) && isNum(b)) return num(a) === num(b);
      if (a instanceof LuaTable && b instanceof LuaTable) {
        var h = (a.mt && a.mt.get('__eq')) || (b.mt && b.mt.get('__eq'));
        if (h) return truthy(first(call(h)(a, b)));
      }
    }
    return false;
  }
  function lt(a, b) {
    if (typeof a === 'number' && typeof b === 'number') return a < b;
    if (isNum(a) && isNum(b)) return num(a) < num(b);
    if (typeof a === 'string' && typeof b === 'string') return a < b;
    var r = metaBin('__lt', a, b);
    if (r !== NOMETA) return truthy(r);
    throw compareError(a, b);
  }
  function le(a, b) {
    if (typeof a === 'number' && typeof b === 'number') return a <= b;
    if (isNum(a) && isNum(b)) return num(a) <= num(b);
    if (typeof a === 'string' && typeof b === 'string') return a <= b;
    var r = metaBin('__le', a, b);
    if (r !== NOMETA) return truthy(r);
    throw compareError(a, b);
  }
  function gt(a, b) { return lt(b, a); }
  function ge(a, b) { return le(b, a); }
  function compareError(a, b) {
    var t1 = typeName(a), t2 = typeName(b);
    if (t1 === t2) return rterror('attempt to compare two ' + t1 + ' values');
    return rterror('attempt to compare ' + t1 + ' with ' + t2);
  }
  function truthy(v) { return v !== undefined && v !== false && v !== null; }

  // ------------------------------------------------------- indexing ----
  function index(o, k, desc) {
    if (o instanceof LuaTable) {
      var v = o.get(k);
      if (v !== undefined || o.mt === null) return v;
      return metaIndex(o, k, desc);
    }
    if (typeof o === 'string') return stringLib.get(k);
    return metaIndex(o, k, desc);
  }
  function metaIndex(o, k, desc) {
    for (var loop = 0; loop < 100; loop++) {
      var h;
      if (o instanceof LuaTable) {
        var v = o.get(k);
        if (v !== undefined) return v;
        if (o.mt === null) return undefined;
        h = o.mt.get('__index');
        if (h === undefined) return undefined;
      } else {
        var mt = metaOf(o);
        h = mt && mt.get('__index');
        if (h === undefined || h === null) {
          throw rterror('attempt to index a ' + typeName(o) + ' value' + (desc ? ' (' + desc + ')' : ''));
        }
      }
      if (typeof h === 'function') return first(h(o, k));
      o = h;
    }
    throw rterror("'__index' chain too long; possible loop");
  }
  function setindex(o, k, v, desc) {
    if (o instanceof LuaTable) {
      if (o.mt === null) { o.set(k, v); return; }
      var h = o.mt.get('__newindex');
      if (h === undefined || o.get(k) !== undefined) { o.set(k, v); return; }
      if (typeof h === 'function') { h(o, k, v); return; }
      return setindex(h, k, v);
    }
    throw rterror('attempt to index a ' + typeName(o) + ' value' + (desc ? ' (' + desc + ')' : ''));
  }

  function call(f, desc) {
    if (typeof f === 'function') return f;
    var mt = metaOf(f), h = mt && mt.get('__call');
    if (typeof h === 'function') return function () {
      var args = [f];
      for (var i = 0; i < arguments.length; i++) args.push(arguments[i]);
      return h.apply(null, args);
    };
    throw rterror('attempt to call a ' + typeName(f) + ' value' + (desc ? ' (' + desc + ')' : ''));
  }
  function method(o, name) {
    var f = index(o, name, 'method \'' + name + '\'');
    if (typeof f !== 'function') f = call(f, "method '" + name + "'");
    var args = [o];
    for (var i = 2; i < arguments.length; i++) args.push(arguments[i]);
    return f.apply(null, args);
  }

  function tbl(list, keyed) {
    var t = new LuaTable();
    if (list.length) {
      var a = list.slice();
      while (a.length && a[a.length - 1] === undefined) a.pop();
      t.arr = a;
    }
    if (keyed) {
      for (var i = 0; i < keyed.length; i += 2) {
        if (keyed[i] === undefined) throw rterror('table index is nil');
        if (keyed[i + 1] !== undefined) t.set(keyed[i], keyed[i + 1]);
      }
    }
    return t;
  }

  // ------------------------------------------------------- iteration ----
  function IpairsIter(t) { this.t = t; this.i = 0; this.a = undefined; this.b = undefined; }
  IpairsIter.prototype.step = function () {
    var i = this.i + 1, v = this.t.get(i);
    if (v === undefined) return false;
    this.i = i; this.a = i; this.b = v; return true;
  };
  function PairsIter(t) { this.t = t; this.i = 0; this.it = null; this.a = undefined; this.b = undefined; }
  PairsIter.prototype.step = function () {
    var arr = this.t.arr;
    while (this.it === null && this.i < arr.length) {
      var v = arr[this.i++];
      if (v !== undefined) { this.a = this.i; this.b = v; return true; }
    }
    if (this.it === null) {
      if (this.t.hash === null) return false;
      this.it = this.t.hash.entries();
    }
    var n = this.it.next();
    if (n.done) return false;
    this.a = n.value[0]; this.b = n.value[1];
    return true;
  };
  function GenIter(f, s, c) { this.f = call(f, 'for iterator'); this.s = s; this.c = c; this.a = undefined; this.b = undefined; this.v = NONE; }
  GenIter.prototype.step = function () {
    var r = this.f(this.s, this.c);
    var v = r instanceof Multi ? r.a : [r];
    if (v[0] === undefined) return false;
    this.c = v[0]; this.a = v[0]; this.b = v[1]; this.v = v;
    return true;
  };
  function iter(f, s, c) {
    if (f === ipairsAux && s instanceof LuaTable && s.mt === null) return new IpairsIter(s);
    if (f === luaNext && s instanceof LuaTable && c === undefined && s.mt === null) return new PairsIter(s);
    return new GenIter(f, s, c);
  }

  function forprep(a, b, c) {
    if (c === undefined) c = 1;
    if (!isNum(a)) throw rterror("'for' initial value must be a number");
    if (!isNum(b)) throw rterror("'for' limit must be a number");
    if (!isNum(c)) throw rterror("'for' step must be a number");
    var x = num(a), lim = num(b), st = num(c);
    if (st === 0) throw rterror("'for' step is zero");
    var intLoop = typeof a === 'number' && Number.isInteger(a) && typeof c === 'number' && Number.isInteger(c);
    if (intLoop) {
      if (!(typeof b === 'number' && Number.isInteger(b))) {
        if (lim !== lim) return [1, 0, 1, false];
        lim = st > 0 ? Math.floor(lim) : Math.ceil(lim);
      }
      return [x, lim, st, false];
    }
    return [x, lim, st, true];
  }

  // ------------------------------------------------------- tostring ----
  function tostring(v) {
    if (v === undefined || v === null) return 'nil';
    switch (typeof v) {
      case 'string': return v;
      case 'number': return numStr(v);
      case 'boolean': return v ? 'true' : 'false';
      case 'function': return 'function: ' + addressOf(v);
    }
    if (v instanceof LFloat) return floatStr(v.n);
    if (v instanceof LuaTable) {
      if (v.mt !== null) {
        var h = v.mt.get('__tostring');
        if (h !== undefined) {
          var s = first(call(h)(v));
          if (typeof s !== 'string') throw rterror("'__tostring' must return a string");
          return s;
        }
        var nm = v.mt.get('__name');
        if (typeof nm === 'string') return nm + ': ' + addressOf(v);
      }
      return 'table: ' + addressOf(v);
    }
    return 'userdata: ' + addressOf(v);
  }
  var addresses = new WeakMap(), nextAddress = 0x55d0c0de0000;
  function addressOf(o) {
    var a = addresses.get(o);
    if (a === undefined) { a = nextAddress; nextAddress += 0x40; addresses.set(o, a); }
    return '0x' + a.toString(16).padStart(14, '0');
  }

  // ===================================================== the library ======
  function argError(n, fname, msg) { return rterror("bad argument #" + n + " to '" + fname + "' (" + msg + ')'); }
  function checkTable(v, n, fname) {
    if (!(v instanceof LuaTable)) throw argError(n, fname, 'table expected, got ' + typeNameArg(v));
    return v;
  }
  function typeNameArg(v) { return v === undefined ? 'no value' : typeName(v); }
  function checkInt(v, n, fname) {
    if (typeof v === 'number' && Number.isInteger(v)) return v;
    if (v instanceof LFloat) return v.n;
    if (typeof v === 'string') { var x = str2num(v); if (x !== undefined) return checkInt(x, n, fname); }
    if (typeof v === 'number') throw argError(n, fname, 'number has no integer representation');
    throw argError(n, fname, 'number expected, got ' + typeNameArg(v));
  }
  function optInt(v, n, fname, d) { return v === undefined ? d : checkInt(v, n, fname); }
  function checkNum(v, n, fname) {
    if (typeof v === 'number') return v;
    if (v instanceof LFloat) return v.n;
    if (typeof v === 'string') { var x = str2num(v); if (x !== undefined) return num(x); }
    throw argError(n, fname, 'number expected, got ' + typeNameArg(v));
  }
  function checkStr(v, n, fname) {
    if (typeof v === 'string') return v;
    if (isNum(v)) return numStr(v);
    throw argError(n, fname, 'string expected, got ' + typeNameArg(v));
  }

  function rawLen(t) { return t instanceof LuaTable ? t.arr.length : (typeof t === 'string' ? t.length : 0); }

  // ---------------------------------------------------------- base ------
  function luaNext(t, k) {
    checkTable(t, 1, 'next');
    var arr = t.arr, i = 0;
    if (k !== undefined) {
      if (typeof k === 'number' && Number.isInteger(k) && k >= 1 && k <= arr.length) i = k;
      else if (k instanceof LFloat && k.n >= 1 && k.n <= arr.length) i = k.n;
      else i = -1;
    }
    if (i >= 0) {
      for (; i < arr.length; i++) if (arr[i] !== undefined) return new Multi([i + 1, arr[i]]);
      if (t.hash === null) return undefined;
      var it = t.hash.entries().next();
      return it.done ? undefined : new Multi([it.value[0], it.value[1]]);
    }
    if (t.hash === null) throw rterror("invalid key to 'next'");
    if (t._nkver !== t.hver || !t._nk) {
      t._nk = Array.from(t.hash.keys());
      t._nki = new Map();
      for (var j = 0; j < t._nk.length; j++) t._nki.set(t._nk[j], j);
      t._nkver = t.hver;
    }
    var key = k instanceof LFloat ? k.n : k;
    var pos = t._nki.get(key);
    if (pos === undefined) throw rterror("invalid key to 'next'");
    for (pos++; pos < t._nk.length; pos++) {
      var kk = t._nk[pos];
      if (t.hash.has(kk)) return new Multi([kk, t.hash.get(kk)]);
    }
    return undefined;
  }
  function ipairsAux(t, i) {
    i = i + 1;
    var v = index(t, i);
    return v === undefined ? undefined : new Multi([i, v]);
  }

  function makeEnv(host) {
    host = host || {};
    var G = new LuaTable();
    function reg(t, name, f) { t.set(name, f); }

    reg(G, 'print', function () {
      var parts = [];
      for (var i = 0; i < arguments.length; i++) parts.push(tostring(arguments[i]));
      (host.print || function (s) { console.log(s); })(parts.join('\t'));
      return NONE;
    });
    reg(G, 'type', function (v) {
      if (arguments.length === 0) throw argError(1, 'type', 'value expected');
      return typeName(v);
    });
    reg(G, 'tostring', function (v) { return tostring(v); });
    reg(G, 'tonumber', function (v, base) {
      if (base === undefined) {
        if (isNum(v)) return v;
        if (typeof v === 'string') return str2num(v);
        if (arguments.length === 0) throw argError(1, 'tonumber', 'value expected');
        return undefined;
      }
      var b = checkInt(base, 2, 'tonumber');
      var s = checkStr(v, 1, 'tonumber').replace(/^\s+|\s+$/g, '').toLowerCase();
      var neg = false;
      if (s[0] === '-') { neg = true; s = s.slice(1); }
      if (!s.length) return undefined;
      var n = 0;
      for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        var d = c >= 48 && c <= 57 ? c - 48 : (c >= 97 && c <= 122 ? c - 87 : 99);
        if (d >= b) return undefined;
        n = n * b + d;
      }
      return neg ? -n : n;
    });
    reg(G, 'ipairs', function (t) {
      if (arguments.length === 0) throw argError(1, 'ipairs', 'table expected, got no value');
      return new Multi([ipairsAux, t, 0]);
    });
    reg(G, 'pairs', function (t) {
      if (t instanceof LuaTable && t.mt !== null) {
        var h = t.mt.get('__pairs');
        if (h !== undefined) { var r = sp(call(h)(t)); return new Multi([r[0], r[1], r[2]]); }
      }
      checkTable(t, 1, 'pairs');
      return new Multi([luaNext, t, undefined]);
    });
    reg(G, 'next', luaNext);
    reg(G, 'select', function (n) {
      var count = arguments.length - 1;
      if (n === '#') return count;
      var i = checkInt(n, 1, 'select');
      if (i < 0) i = count + i; else if (i === 0) throw argError(1, 'select', 'index out of range');
      else i = i - 1;
      if (i < 0) throw argError(1, 'select', 'index out of range');
      var out = [];
      for (var j = i + 1; j < arguments.length; j++) out.push(arguments[j]);
      return ret(out);
    });
    reg(G, 'rawget', function (t, k) { checkTable(t, 1, 'rawget'); return t.get(k); });
    reg(G, 'rawset', function (t, k, v) { checkTable(t, 1, 'rawset'); t.set(k, v); return t; });
    reg(G, 'rawequal', function (a, b) { return a === b || (isNum(a) && isNum(b) && num(a) === num(b)); });
    reg(G, 'rawlen', function (t) { return rawLen(t); });
    reg(G, 'setmetatable', function (t, mt) {
      checkTable(t, 1, 'setmetatable');
      if (t.mt && t.mt.get('__metatable') !== undefined) throw rterror('cannot change a protected metatable');
      t.mt = mt === undefined ? null : mt;
      return t;
    });
    reg(G, 'getmetatable', function (v) {
      var mt = metaOf(v);
      if (!mt) return undefined;
      var p = mt.get('__metatable');
      return p !== undefined ? p : mt;
    });
    reg(G, 'assert', function (v, msg) {
      if (truthy(v)) { return ret(Array.prototype.slice.call(arguments)); }
      if (arguments.length < 1) throw argError(1, 'assert', 'value expected');
      throw new LuaError(arguments.length >= 2 ? msg : 'assertion failed!');
    });
    reg(G, 'error', function (v, level) {
      var lv = level === undefined ? 1 : num(level);
      if (typeof v === 'string' && lv > 0) v = luaPosition(lv + 1) + v;
      throw new LuaError(v);
    });
    reg(G, 'pcall', function (f) {
      var args = Array.prototype.slice.call(arguments, 1);
      try {
        var r = call(f).apply(null, args);
        return new Multi([true].concat(sp(r)));
      } catch (e) {
        return new Multi([false, errorValue(e)]);
      }
    });
    reg(G, 'xpcall', function (f, handler) {
      var args = Array.prototype.slice.call(arguments, 2);
      try {
        var r = call(f).apply(null, args);
        return new Multi([true].concat(sp(r)));
      } catch (e) {
        return new Multi([false].concat(sp(call(handler)(errorValue(e)))));
      }
    });
    reg(G, 'collectgarbage', function (opt) { return opt === 'count' ? mkf(1024) : 0; });
    reg(G, 'load', function (chunk, name, mode, env) {
      var src = chunk;
      if (typeof chunk === 'function') {
        var pieces = [], piece;
        while ((piece = first(chunk())) !== undefined && piece !== '') pieces.push(piece);
        src = pieces.join('');
      }
      try {
        return NS.load(src, typeof name === 'string' ? name.replace(/^[=@]/, '') : 'chunk', env || G);
      } catch (e) {
        return new Multi([undefined, errorValue(e)]);
      }
    });
    reg(G, 'loadfile', function (path, mode, env) {
      var src = host.readFile ? host.readFile(path) : null;
      if (src === null || src === undefined) return new Multi([undefined, 'cannot open ' + path]);
      try { return NS.load(src, path, env || G); }
      catch (e) { return new Multi([undefined, errorValue(e)]); }
    });
    reg(G, 'dofile', function (path) {
      var src = host.readFile ? host.readFile(path) : null;
      if (src === null || src === undefined) throw rterror('cannot open ' + path);
      return NS.load(src, path, G)();
    });
    reg(G, 'require', function (name) {
      var loaded = G.get('package').get('loaded');
      var v = loaded.get(name);
      if (v !== undefined) return v;
      if (!host.require) throw rterror("module '" + name + "' not found");
      v = host.require(name);
      loaded.set(name, v === undefined ? true : v);
      return v === undefined ? true : v;
    });
    var pkg = new LuaTable(); pkg.set('loaded', new LuaTable()); pkg.set('path', './?.lua');
    G.set('package', pkg);
    G.set('_G', G);
    G.set('_VERSION', 'Lua 5.4');

    G.set('string', stringLib);
    G.set('table', makeTableLib());
    G.set('math', makeMathLib());
    G.set('os', makeOsLib(host));
    G.set('io', makeIoLib(host));
    G.set('utf8', makeUtf8Lib());
    pkg.get('loaded').set('string', stringLib);
    pkg.get('loaded').set('_G', G);
    return G;
  }
  function errorValue(e) {
    if (e instanceof LuaError) return e.value;
    if (e instanceof RangeError) return 'stack overflow';
    if (e && e.name === 'LuaSyntaxError') return e.message;
    return String(e && e.message ? e.message : e);
  }

  // --------------------------------------------------------- table ------
  function makeTableLib() {
    var T = new LuaTable();
    T.set('insert', function (t, a, b) {
      checkTable(t, 1, 'insert');
      var e = len(t) + 1;
      if (arguments.length === 2) { setindex(t, e, a); return NONE; }
      if (arguments.length !== 3) throw rterror("wrong number of arguments to 'insert'");
      var pos = checkInt(a, 2, 'insert');
      if (pos < 1 || pos > e) throw argError(2, 'insert', 'position out of bounds');
      if (t.mt === null && e - 1 === t.arr.length) {
        t.arr.splice(pos - 1, 0, b);
        if (b === undefined) { while (t.arr.length && t.arr[t.arr.length - 1] === undefined) t.arr.pop(); }
        return NONE;
      }
      for (var i = e; i > pos; i--) setindex(t, i, index(t, i - 1));
      setindex(t, pos, b);
      return NONE;
    });
    T.set('remove', function (t, p) {
      checkTable(t, 1, 'remove');
      var size = len(t);
      var pos = p === undefined ? size : checkInt(p, 2, 'remove');
      if (p !== undefined && pos !== size && (pos < 1 || pos > size + 1)) throw argError(2, 'remove', 'position out of bounds');
      var result = index(t, pos);
      if (t.mt === null && size === t.arr.length && pos >= 1 && pos <= size) {
        t.arr.splice(pos - 1, 1);
        while (t.arr.length && t.arr[t.arr.length - 1] === undefined) t.arr.pop();
        return result;
      }
      for (; pos < size; pos++) setindex(t, pos, index(t, pos + 1));
      setindex(t, pos, undefined);
      return result;
    });
    T.set('concat', function (t, sep, i, j) {
      checkTable(t, 1, 'concat');
      sep = sep === undefined ? '' : checkStr(sep, 2, 'concat');
      var a = optInt(i, 3, 'concat', 1), b = j === undefined ? len(t) : checkInt(j, 4, 'concat');
      var parts = [];
      for (var k = a; k <= b; k++) {
        var v = index(t, k);
        if (typeof v === 'string') parts.push(v);
        else if (isNum(v)) parts.push(numStr(v));
        else throw rterror("invalid value (at index " + k + ") in table for 'concat'");
      }
      return parts.join(sep);
    });
    T.set('unpack', function (t, i, j) {
      var a = optInt(i, 2, 'unpack', 1), b = j === undefined ? len(t) : checkInt(j, 3, 'unpack');
      var out = [];
      for (var k = a; k <= b; k++) out.push(index(t, k));
      return ret(out);
    });
    T.set('pack', function () {
      var t = tbl(Array.prototype.slice.call(arguments));
      t.set('n', arguments.length);
      return t;
    });
    T.set('move', function (a1, f, e, t, a2) {
      if (a2 === undefined) a2 = a1;
      f = checkInt(f, 2, 'move'); e = checkInt(e, 3, 'move'); t = checkInt(t, 4, 'move');
      if (e >= f) {
        if (t > e || t <= f || a1 !== a2) for (var i = 0; i <= e - f; i++) setindex(a2, t + i, index(a1, f + i));
        else for (var k = e - f; k >= 0; k--) setindex(a2, t + k, index(a1, f + k));
      }
      return a2;
    });
    T.set('sort', function (t, comp) {
      checkTable(t, 1, 'sort');
      var n = len(t);
      if (n > 1) {
        var a = new Array(n + 1);
        for (var i = 1; i <= n; i++) a[i] = index(t, i);
        var less;
        if (comp !== undefined) {
          var cf = call(comp);
          less = function (x, y) { return truthy(first(cf(x, y))); };
        } else less = lt;
        auxsort(a, 1, n, 0, less);
        for (var j = 1; j <= n; j++) setindex(t, j, a[j]);
      }
      return NONE;
    });
    return T;
  }

  // Lua 5.4's ltablib.c sort, line for line: ties come out in the same
  // order as in the real Lua, which matters to engines that sort with them.
  var RANLIMIT = 100;
  function auxsort(a, lo, up, rnd, less) {
    var t;
    while (lo < up) {
      if (less(a[up], a[lo])) { t = a[lo]; a[lo] = a[up]; a[up] = t; }
      if (up - lo === 1) break;
      var p;
      if (up - lo < RANLIMIT || rnd === 0) p = Math.floor((lo + up) / 2);
      else { var r4 = Math.floor((up - lo) / 4); p = rnd % (r4 * 2) + (lo + r4); }
      if (less(a[p], a[lo])) { t = a[p]; a[p] = a[lo]; a[lo] = t; }
      else if (less(a[up], a[p])) { t = a[p]; a[p] = a[up]; a[up] = t; }
      if (up - lo === 2) break;
      var P = a[p];
      t = a[p]; a[p] = a[up - 1]; a[up - 1] = t;
      // partition
      var i = lo, j = up - 1;
      for (;;) {
        while (less(a[++i], P)) {
          if (i === up - 1) throw rterror('invalid order function for sorting');
        }
        while (less(P, a[--j])) {
          if (j < i) throw rterror('invalid order function for sorting');
        }
        if (j < i) { t = a[up - 1]; a[up - 1] = a[i]; a[i] = t; break; }
        t = a[i]; a[i] = a[j]; a[j] = t;
      }
      p = i;
      var n;
      if (p - lo < up - p) { auxsort(a, lo, p - 1, rnd, less); n = p - lo; lo = p + 1; }
      else { auxsort(a, p + 1, up, rnd, less); n = up - p; up = p - 1; }
      if ((up - lo) / 128 > n) rnd = 0x5bd1e995;   // real Lua randomises here
    }
  }

  // ---------------------------------------------------------- math ------
  function makeMathLib() {
    var M = new LuaTable();
    M.set('pi', Math.PI);
    M.set('huge', Infinity);
    M.set('maxinteger', 9223372036854775807);
    M.set('mininteger', -9223372036854775808);
    M.set('abs', function (x) {
      if (typeof x === 'number') return Number.isInteger(x) ? (x < 0 ? 0 - x : x) : Math.abs(x);
      if (x instanceof LFloat) return new LFloat(Math.abs(x.n));
      return mkfOrInt(Math.abs(checkNum(x, 1, 'abs')), x);
    });
    M.set('floor', function (x) {
      if (typeof x === 'number' && Number.isInteger(x)) return x;
      var r = Math.floor(checkNum(x, 1, 'floor'));
      return r === 0 ? 0 : r;
    });
    M.set('ceil', function (x) {
      if (typeof x === 'number' && Number.isInteger(x)) return x;
      var r = Math.ceil(checkNum(x, 1, 'ceil'));
      return r === 0 ? 0 : r;
    });
    function minmax(isMax, name) {
      return function () {
        if (arguments.length === 0) throw argError(1, name, 'number expected, got no value');
        var best = arguments[0]; checkNum(best, 1, name);
        for (var i = 1; i < arguments.length; i++) {
          var v = arguments[i]; checkNum(v, i + 1, name);
          if (isMax ? lt(best, v) : lt(v, best)) best = v;
        }
        return best;
      };
    }
    M.set('max', minmax(true, 'max'));
    M.set('min', minmax(false, 'min'));
    function fl(f, name) { return function (x) { return mkf(f(checkNum(x, 1, name))); }; }
    M.set('sqrt', fl(Math.sqrt, 'sqrt'));
    M.set('sin', fl(Math.sin, 'sin'));
    M.set('cos', fl(Math.cos, 'cos'));
    M.set('tan', fl(Math.tan, 'tan'));
    M.set('asin', fl(Math.asin, 'asin'));
    M.set('acos', fl(Math.acos, 'acos'));
    M.set('exp', fl(Math.exp, 'exp'));
    M.set('atan', function (y, x) { return mkf(Math.atan2(checkNum(y, 1, 'atan'), x === undefined ? 1 : checkNum(x, 2, 'atan'))); });
    M.set('log', function (x, base) {
      var v = checkNum(x, 1, 'log');
      if (base === undefined) return mkf(Math.log(v));
      var b = checkNum(base, 2, 'log');
      if (b === 2) return mkf(Math.log2(v));
      if (b === 10) return mkf(Math.log10(v));
      return mkf(Math.log(v) / Math.log(b));
    });
    M.set('fmod', function (a, b) {
      if (typeof a === 'number' && typeof b === 'number' && Number.isInteger(a) && Number.isInteger(b)) {
        if (b === 0) throw argError(2, 'fmod', 'zero');
        return a % b === 0 ? 0 : a % b;
      }
      return mkf(checkNum(a, 1, 'fmod') % checkNum(b, 2, 'fmod'));
    });
    M.set('modf', function (x) {
      var v = checkNum(x, 1, 'modf');
      var ip = v >= 0 ? Math.floor(v) : Math.ceil(v);
      var fp = (v === Infinity || v === -Infinity) ? 0 : v - ip;
      return new Multi([mkf(ip), mkf(fp)]);
    });
    M.set('tointeger', function (x) {
      if (typeof x === 'number' && Number.isInteger(x)) return x;
      if (x instanceof LFloat) return x.n;
      if (typeof x === 'string') { var n = str2num(x); return n === undefined ? undefined : (typeof n === 'number' && Number.isInteger(n) ? n : (n instanceof LFloat ? n.n : undefined)); }
      return undefined;
    });
    M.set('type', function (x) {
      if (arguments.length === 0) throw argError(1, 'type', 'value expected');
      if (typeof x === 'number') return Number.isInteger(x) ? 'integer' : 'float';
      if (x instanceof LFloat) return 'float';
      return undefined;
    });
    M.set('ult', function (a, b) {
      return BigInt.asUintN(64, BigInt(checkInt(a, 1, 'ult'))) < BigInt.asUintN(64, BigInt(checkInt(b, 2, 'ult')));
    });

    // xoshiro256**, as lmathlib.c has it, on 64-bit BigInts.
    var MASK = (1n << 64n) - 1n;
    var state = [0n, 0n, 0n, 0n];
    function rotl(x, n) { return ((x << BigInt(n)) | (x >> BigInt(64 - n))) & MASK; }
    function nextrand() {
      var s0 = state[0], s1 = state[1], s2 = state[2] ^ s0, s3 = state[3] ^ s1;
      var res = (rotl((s1 * 5n) & MASK, 7) * 9n) & MASK;
      state[0] = s0 ^ s3;
      state[1] = s1 ^ s2;
      state[2] = s2 ^ ((s1 << 17n) & MASK);
      state[3] = rotl(s3, 45);
      return res;
    }
    function setseed(n1, n2) {
      state = [BigInt.asUintN(64, n1), 0xffn, BigInt.asUintN(64, n2), 0n];
      for (var i = 0; i < 16; i++) nextrand();
    }
    setseed(BigInt(Date.now()), 0n);
    function project(ran, n) {
      if ((n & (n + 1n)) === 0n) return ran & n;
      var lim = n;
      lim |= lim >> 1n; lim |= lim >> 2n; lim |= lim >> 4n; lim |= lim >> 8n;
      lim |= lim >> 16n; lim |= lim >> 32n;
      while ((ran &= lim) > n) ran = nextrand();
      return ran;
    }
    M.set('random', function (m, n) {
      var rv = nextrand();
      var low, up;
      switch (arguments.length) {
        case 0: return mkf(Number(rv >> 11n) * Math.pow(2, -53));
        case 1:
          low = 1n; up = BigInt(checkInt(m, 1, 'random'));
          if (up === 0n) return fromInt64(rv);
          break;
        case 2:
          low = BigInt(checkInt(m, 1, 'random')); up = BigInt(checkInt(n, 2, 'random'));
          break;
        default: throw rterror('wrong number of arguments');
      }
      if (!(low <= up)) throw argError(1, 'random', 'interval is empty');
      var p = project(rv, BigInt.asUintN(64, up - low));
      return fromInt64(p + BigInt.asUintN(64, low));
    });
    M.set('randomseed', function (a, b) {
      if (arguments.length === 0) { setseed(BigInt(Date.now()), 0n); return; }
      var n1 = isFloatVal(a) ? BigInt(Math.trunc(num(a))) : BigInt(checkInt(a, 1, 'randomseed'));
      var n2 = b === undefined ? 0n : BigInt(checkInt(b, 2, 'randomseed'));
      setseed(n1, n2);
      return new Multi([fromInt64(n1), fromInt64(n2)]);
    });
    return M;
  }
  function mkfOrInt(r, orig) { return isFloatVal(orig) ? mkf(r) : r; }

  // ------------------------------------------------------------ os ------
  function makeOsLib(host) {
    var O = new LuaTable();
    var now = host.now || function () { return Date.now(); };
    O.set('time', function (t) {
      if (t === undefined) return Math.floor(now() / 1000);
      checkTable(t, 1, 'time');
      function field(k, d) {
        var v = t.get(k);
        if (v === undefined) { if (d === undefined) throw rterror("field '" + k + "' missing in date table"); return d; }
        return num(v);
      }
      var d = new Date(field('year'), field('month') - 1, field('day'), field('hour', 12), field('min', 0), field('sec', 0));
      return Math.floor(d.getTime() / 1000);
    });
    O.set('clock', function () {
      var p = (typeof performance !== 'undefined') ? performance.now() : Date.now();
      return mkf(p / 1000);
    });
    O.set('date', function (fmt, t) {
      fmt = fmt === undefined ? '%c' : checkStr(fmt, 1, 'date');
      var ms = t === undefined ? now() : num(t) * 1000;
      var utc = fmt[0] === '!';
      if (utc) fmt = fmt.slice(1);
      var d = new Date(ms);
      var g = utc
        ? { Y: d.getUTCFullYear(), m: d.getUTCMonth(), d: d.getUTCDate(), H: d.getUTCHours(), M: d.getUTCMinutes(), S: d.getUTCSeconds(), w: d.getUTCDay() }
        : { Y: d.getFullYear(), m: d.getMonth(), d: d.getDate(), H: d.getHours(), M: d.getMinutes(), S: d.getSeconds(), w: d.getDay() };
      var start = utc ? Date.UTC(g.Y, 0, 1) : new Date(g.Y, 0, 1).getTime();
      var cur = utc ? Date.UTC(g.Y, g.m, g.d) : new Date(g.Y, g.m, g.d).getTime();
      var yday = Math.round((cur - start) / 86400000) + 1;
      if (fmt.slice(0, 2) === '*t') {
        var r = new LuaTable();
        r.set('year', g.Y); r.set('month', g.m + 1); r.set('day', g.d);
        r.set('hour', g.H); r.set('min', g.M); r.set('sec', g.S);
        r.set('wday', g.w + 1); r.set('yday', yday); r.set('isdst', false);
        return r;
      }
      var DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      function p2(n) { return (n < 10 ? '0' : '') + n; }
      return fmt.replace(/%(.)/g, function (_, c) {
        switch (c) {
          case 'Y': return String(g.Y);
          case 'y': return p2(g.Y % 100);
          case 'm': return p2(g.m + 1);
          case 'd': return p2(g.d);
          case 'e': return (g.d < 10 ? ' ' : '') + g.d;
          case 'H': return p2(g.H);
          case 'I': return p2(((g.H + 11) % 12) + 1);
          case 'M': return p2(g.M);
          case 'S': return p2(g.S);
          case 'p': return g.H < 12 ? 'AM' : 'PM';
          case 'A': return DAYS[g.w];
          case 'a': return DAYS[g.w].slice(0, 3);
          case 'B': return MONTHS[g.m];
          case 'b': return MONTHS[g.m].slice(0, 3);
          case 'j': return String(yday).padStart(3, '0');
          case 'w': return String(g.w);
          case 'u': return String(g.w === 0 ? 7 : g.w);
          case 'x': return p2(g.m + 1) + '/' + p2(g.d) + '/' + p2(g.Y % 100);
          case 'X': return p2(g.H) + ':' + p2(g.M) + ':' + p2(g.S);
          case 'c': return DAYS[g.w].slice(0, 3) + ' ' + MONTHS[g.m].slice(0, 3) + ' ' + (g.d < 10 ? ' ' : '') + g.d + ' ' + p2(g.H) + ':' + p2(g.M) + ':' + p2(g.S) + ' ' + g.Y;
          case '%': return '%';
          default: return '%' + c;
        }
      });
    });
    O.set('getenv', function () { return undefined; });
    O.set('remove', function (path) {
      if (host.removeFile && host.removeFile(path)) return true;
      return new Multi([undefined, path + ': No such file or directory', 2]);
    });
    O.set('rename', function (a, b) {
      if (host.renameFile && host.renameFile(a, b)) return true;
      return new Multi([undefined, a + ': No such file or directory', 2]);
    });
    O.set('exit', function () { throw new LuaError('os.exit called'); });
    O.set('tmpname', function () { return '/tmp/lua_' + Math.random().toString(36).slice(2); });
    return O;
  }

  // ------------------------------------------------------------ io ------
  // Files live wherever the host keeps them (host.readFile / host.writeFile):
  // Battle Pass keeps its save file this way.
  function makeIoLib(host) {
    var IO = new LuaTable();
    var fileMeta = new LuaTable();
    var fileMethods = new LuaTable();
    fileMeta.set('__index', fileMethods);
    fileMeta.set('__name', 'FILE*');
    function newFile(path, mode, data) {
      var f = new LuaTable();
      f.mt = fileMeta;
      f._path = path; f._mode = mode; f._data = data; f._pos = 0; f._closed = false;
      return f;
    }
    IO.set('open', function (path, mode) {
      path = checkStr(path, 1, 'open');
      mode = mode === undefined ? 'r' : checkStr(mode, 2, 'open');
      var m = mode.replace('b', '');
      if (m[0] === 'r') {
        var data = host.readFile ? host.readFile(path) : null;
        if (data === null || data === undefined) return new Multi([undefined, path + ': No such file or directory', 2]);
        return newFile(path, m, data);
      }
      if (m[0] === 'w') return newFile(path, m, '');
      if (m[0] === 'a') {
        var old = host.readFile ? host.readFile(path) : null;
        var f = newFile(path, m, old || '');
        f._pos = f._data.length;
        return f;
      }
      throw argError(2, 'open', 'invalid mode');
    });
    fileMethods.set('read', function (f) {
      var fmts = Array.prototype.slice.call(arguments, 1);
      if (!fmts.length) fmts = ['l'];
      var out = [];
      for (var i = 0; i < fmts.length; i++) {
        var fm = fmts[i];
        if (isNum(fm)) {
          var n = num(fm);
          if (f._pos >= f._data.length && n > 0) { out.push(undefined); break; }
          out.push(f._data.substr(f._pos, n)); f._pos += n; continue;
        }
        fm = String(fm).replace(/^\*/, '');
        if (fm[0] === 'a') { out.push(f._data.slice(f._pos)); f._pos = f._data.length; continue; }
        if (fm[0] === 'l' || fm[0] === 'L') {
          if (f._pos >= f._data.length) { out.push(undefined); break; }
          var e = f._data.indexOf('\n', f._pos);
          var line = e < 0 ? f._data.slice(f._pos) : f._data.slice(f._pos, fm[0] === 'L' ? e + 1 : e);
          f._pos = e < 0 ? f._data.length : e + 1;
          out.push(line); continue;
        }
        if (fm[0] === 'n') {
          var m = /^\s*[-+]?(0[xX][0-9a-fA-F.]+|\d*\.?\d+(?:[eE][-+]?\d+)?)/.exec(f._data.slice(f._pos));
          if (!m) { out.push(undefined); break; }
          f._pos += m[0].length; out.push(str2num(m[0])); continue;
        }
      }
      return ret(out);
    });
    fileMethods.set('write', function (f) {
      for (var i = 1; i < arguments.length; i++) {
        var v = arguments[i];
        var s = typeof v === 'string' ? v : writeNum(v);
        f._data = f._data.slice(0, f._pos) + s + f._data.slice(f._pos + s.length);
        f._pos += s.length;
      }
      return f;
    });
    fileMethods.set('lines', function (f) {
      return function () { return first(fileMethods.get('read')(f, 'l')); };
    });
    fileMethods.set('seek', function (f, whence, off) {
      whence = whence || 'cur'; off = off === undefined ? 0 : num(off);
      if (whence === 'set') f._pos = off;
      else if (whence === 'end') f._pos = f._data.length + off;
      else f._pos += off;
      return f._pos;
    });
    fileMethods.set('flush', function (f) {
      if (f._mode[0] !== 'r' && host.writeFile) host.writeFile(f._path, f._data);
      return f;
    });
    fileMethods.set('close', function (f) {
      if (!f._closed && f._mode[0] !== 'r' && host.writeFile) host.writeFile(f._path, f._data);
      f._closed = true;
      return true;
    });
    fileMethods.set('setvbuf', function () { return true; });
    IO.set('write', function () {
      var s = '';
      for (var i = 0; i < arguments.length; i++) s += typeof arguments[i] === 'string' ? arguments[i] : writeNum(arguments[i]);
      (host.write || host.print || function (x) { if (typeof process !== 'undefined') process.stdout.write(x); })(s);
      return NONE;
    });
    IO.set('lines', function (path) {
      var data = host.readFile ? host.readFile(path) : null;
      if (data === null || data === undefined) throw rterror(path + ': No such file or directory');
      var f = newFile(path, 'r', data);
      return function () { return first(fileMethods.get('read')(f, 'l')); };
    });
    return IO;
  }

  // ---------------------------------------------------------- utf8 ------
  function makeUtf8Lib() {
    var U = new LuaTable();
    U.set('char', function () {
      var s = '';
      for (var i = 0; i < arguments.length; i++) s += NS.utf8Bytes(checkInt(arguments[i], i + 1, 'char'));
      return s;
    });
    U.set('charpattern', '[\x00-\x7F\xC2-\xFD][\x80-\xBF]*');
    function decodeAt(s, i) {   // i 0-based; returns [codepoint, length] or null
      var c = s.charCodeAt(i);
      if (c < 0x80) return [c, 1];
      var n = c >= 0xF0 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 0;
      if (!n) return null;
      var cp = c & (0x7F >> n);
      for (var k = 1; k < n; k++) {
        var cc = s.charCodeAt(i + k);
        if ((cc & 0xC0) !== 0x80) return null;
        cp = (cp << 6) | (cc & 0x3F);
      }
      return [cp, n];
    }
    U.set('len', function (s, i, j) {
      s = checkStr(s, 1, 'len');
      var a = (i === undefined ? 1 : num(i)) - 1, b = j === undefined ? s.length : num(j);
      var n = 0;
      while (a < b) {
        var d = decodeAt(s, a);
        if (!d) return new Multi([undefined, a + 1]);
        a += d[1]; n++;
      }
      return n;
    });
    U.set('codepoint', function (s, i, j) {
      s = checkStr(s, 1, 'codepoint');
      var a = (i === undefined ? 1 : num(i)), b = j === undefined ? a : num(j);
      var out = [], p = a - 1;
      while (p < b) {
        var d = decodeAt(s, p);
        if (!d) throw rterror('invalid UTF-8 code');
        out.push(d[0]); p += d[1];
      }
      return ret(out);
    });
    U.set('offset', function (s, n, i) {
      s = checkStr(s, 1, 'offset');
      n = num(n);
      var p = i === undefined ? (n >= 0 ? 1 : s.length + 1) : num(i);
      p -= 1;
      function cont(k) { return (s.charCodeAt(k) & 0xC0) === 0x80; }
      if (n === 0) { while (p > 0 && cont(p)) p--; return p + 1; }
      if (n > 0) { n--; while (n > 0 && p < s.length) { p++; while (cont(p)) p++; n--; } return n === 0 ? p + 1 : undefined; }
      while (n < 0 && p > 0) { p--; while (p > 0 && cont(p)) p--; n++; }
      return n === 0 ? p + 1 : undefined;
    });
    U.set('codes', function (s) {
      s = checkStr(s, 1, 'codes');
      return new Multi([function (str, i) {
        var p = num(i);
        if (p > 0) { var d0 = decodeAt(str, p - 1); p += d0 ? d0[1] - 1 : 0; }
        if (p >= str.length) return undefined;
        var d = decodeAt(str, p);
        if (!d) throw rterror('invalid UTF-8 code');
        return new Multi([p + 1, d[0]]);
      }, s, 0]);
    });
    return U;
  }

  // ======================================================== strings =======
  var stringLib = new LuaTable();
  var stringMeta = new LuaTable();
  stringMeta.set('__index', stringLib);

  function posrelatI(pos, l) {
    if (pos > 0) return pos;
    if (pos === 0) return 1;
    if (pos < -l) return 1;
    return l + pos + 1;
  }
  function getendpos(pos, l) {
    if (pos > l) return l;
    if (pos >= 0) return pos;
    if (pos < -l) return 0;
    return l + pos + 1;
  }
  stringLib.set('len', function (s) { return checkStr(s, 1, 'len').length; });
  stringLib.set('sub', function (s, i, j) {
    s = checkStr(s, 1, 'sub');
    var l = s.length;
    var st = posrelatI(checkInt(i === undefined ? 1 : i, 2, 'sub'), l);
    var en = getendpos(j === undefined ? -1 : checkInt(j, 3, 'sub'), l);
    if (st < 1) st = 1;
    if (en > l) en = l;
    return st <= en ? s.slice(st - 1, en) : '';
  });
  stringLib.set('upper', function (s) {
    s = checkStr(s, 1, 'upper');
    return s.replace(/[a-z]+/g, function (m) { return m.toUpperCase(); });
  });
  stringLib.set('lower', function (s) {
    s = checkStr(s, 1, 'lower');
    return s.replace(/[A-Z]+/g, function (m) { return m.toLowerCase(); });
  });
  stringLib.set('rep', function (s, n, sep) {
    s = checkStr(s, 1, 'rep'); n = checkInt(n, 2, 'rep');
    if (n <= 0) return '';
    if (sep === undefined || sep === '') return s.repeat(n);
    sep = checkStr(sep, 3, 'rep');
    return Array(n).fill(s).join(sep);
  });
  stringLib.set('reverse', function (s) { return checkStr(s, 1, 'reverse').split('').reverse().join(''); });
  stringLib.set('byte', function (s, i, j) {
    s = checkStr(s, 1, 'byte');
    var l = s.length;
    var pi = posrelatI(optInt(i, 2, 'byte', 1), l);
    var pe = getendpos(j === undefined ? pi : checkInt(j, 3, 'byte'), l);
    if (pi > pe) return undefined;
    var out = [];
    for (var k = pi; k <= pe; k++) out.push(s.charCodeAt(k - 1));
    return ret(out);
  });
  stringLib.set('char', function () {
    var out = '';
    for (var i = 0; i < arguments.length; i++) {
      var c = checkInt(arguments[i], i + 1, 'char');
      if (c < 0 || c > 255) throw argError(i + 1, 'char', 'value out of range');
      out += String.fromCharCode(c);
    }
    return out;
  });

  // string.format, with C's own rounding.
  stringLib.set('format', function (fmt) {
    fmt = checkStr(fmt, 1, 'format');
    var args = arguments, argi = 1;
    var out = '', i = 0, n = fmt.length;
    while (i < n) {
      var c = fmt[i++];
      if (c !== '%') { out += c; continue; }
      if (fmt[i] === '%') { out += '%'; i++; continue; }
      var m = /^([-+ #0]*)(\d*)(?:\.(\d*))?([a-zA-Z])/.exec(fmt.slice(i));
      if (!m) throw rterror("invalid conversion '%" + fmt.slice(i, i + 5) + "' to 'format'");
      i += m[0].length;
      var flags = m[1], width = m[2] ? Number(m[2]) : 0, prec = m[3] === undefined ? undefined : Number(m[3] || 0);
      var conv = m[4];
      var argn = ++argi;
      if (argn > args.length - 1 + 1 && conv !== '%') {
        if (args[argn - 1] === undefined && argn > args.length) throw argError(argn, 'format', 'no value');
      }
      var v = args[argn - 1], body, sign = '';
      switch (conv) {
        case 'd': case 'i': {
          var iv = checkInt(v, argn, 'format');
          body = String(Math.abs(iv) < 1e21 ? Math.abs(iv) : BigInt(iv) * (iv < 0 ? -1n : 1n));
          if (prec !== undefined) { body = body.padStart(prec, '0'); if (prec === 0 && iv === 0) body = ''; }
          sign = iv < 0 ? '-' : (flags.indexOf('+') >= 0 ? '+' : (flags.indexOf(' ') >= 0 ? ' ' : ''));
          out += pad(sign, body, width, flags, prec === undefined);
          break;
        }
        case 'u': {
          var uv = checkInt(v, argn, 'format');
          body = BigInt.asUintN(64, BigInt(uv)).toString();
          out += pad('', body, width, flags, true);
          break;
        }
        case 'c': out += pad('', String.fromCharCode(checkInt(v, argn, 'format')), width, flags.replace('0', ''), false); break;
        case 'x': case 'X': case 'o': {
          var xv = BigInt.asUintN(64, BigInt(checkInt(v, argn, 'format')));
          body = xv.toString(conv === 'o' ? 8 : 16);
          if (conv === 'X') body = body.toUpperCase();
          if (prec !== undefined) body = body.padStart(prec, '0');
          var pre = (flags.indexOf('#') >= 0 && xv !== 0n) ? (conv === 'o' ? '0' : (conv === 'x' ? '0x' : '0X')) : '';
          out += pad(pre, body, width, flags, prec === undefined);
          break;
        }
        case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A': {
          var fv = checkNum(v, argn, 'format');
          var neg = fv < 0 || (fv === 0 && 1 / fv < 0);
          var ax = Math.abs(fv);
          var up = conv === 'E' || conv === 'G' || conv === 'F' || conv === 'A';
          if (ax === Infinity || fv !== fv) {
            body = fv !== fv ? 'nan' : 'inf';
            if (up) body = body.toUpperCase();
            sign = neg && fv === fv ? '-' : (flags.indexOf('+') >= 0 ? '+' : (flags.indexOf(' ') >= 0 ? ' ' : ''));
            out += pad(sign, body, width, flags.replace('0', ''), false);
            break;
          }
          var p = prec === undefined ? 6 : prec;
          var alt = flags.indexOf('#') >= 0;
          if (conv === 'f' || conv === 'F') { body = fixedDigits(ax, p); if (alt && p === 0) body += '.'; }
          else if (conv === 'e' || conv === 'E') body = fmtExp(ax, p, up);
          else if (conv === 'g' || conv === 'G') body = fmtG(ax, p, up, alt);
          else body = hexFloat(ax, prec, up);
          sign = neg ? '-' : (flags.indexOf('+') >= 0 ? '+' : (flags.indexOf(' ') >= 0 ? ' ' : ''));
          out += pad(sign, body, width, flags, true);
          break;
        }
        case 's': {
          var sv = tostring(v);
          if (args.length < argn) throw argError(argn, 'format', 'no value');
          if (prec !== undefined) sv = sv.slice(0, prec);
          out += pad('', sv, width, flags.replace('0', ''), false);
          break;
        }
        case 'q': out += quoteString(v); break;
        default:
          throw rterror("invalid conversion '%" + m[0] + "' to 'format'");
      }
    }
    return out;
  });
  function pad(sign, body, width, flags, zeroOk) {
    var total = sign.length + body.length;
    if (total >= width) return sign + body;
    if (flags.indexOf('-') >= 0) return sign + body + ' '.repeat(width - total);
    if (zeroOk && flags.indexOf('0') >= 0) return sign + '0'.repeat(width - total) + body;
    return ' '.repeat(width - total) + sign + body;
  }
  function hexFloat(x, prec, up) {
    if (x === 0) return up ? '0X0P+0' : '0x0p+0';
    var e = Math.floor(Math.log2(x)), m = x / Math.pow(2, e);
    if (m >= 2) { m /= 2; e++; } else if (m < 1) { m *= 2; e--; }
    var frac = (m - 1).toString(16).slice(2);
    if (prec !== undefined) frac = frac.slice(0, prec).padEnd(prec, '0');
    var s = '0x1' + (frac ? '.' + frac : '') + 'p' + (e >= 0 ? '+' : '') + e;
    return up ? s.toUpperCase() : s;
  }
  function quoteString(v) {
    if (typeof v === 'string') {
      var o = '"';
      for (var i = 0; i < v.length; i++) {
        var c = v.charCodeAt(i), ch = v[i];
        if (ch === '"' || ch === '\\') o += '\\' + ch;
        else if (ch === '\n') o += '\\\n';
        else if (ch === '\r') o += '\\r';
        else if (c === 0) o += (i + 1 < v.length && /\d/.test(v[i + 1])) ? '\\000' : '\\0';
        else if (c < 32 || c === 127) o += '\\' + ((i + 1 < v.length && /\d/.test(v[i + 1])) ? String(c).padStart(3, '0') : c);
        else o += ch;
      }
      return o + '"';
    }
    if (typeof v === 'number' && Number.isInteger(v)) return intStr(v);
    if (isNum(v)) {
      var x = num(v);
      if (x === Infinity) return '1e9999';
      if (x === -Infinity) return '-1e9999';
      if (x !== x) return '(0/0)';
      if (x === Math.floor(x)) return (x < 0 ? '-' : '') + hexFloat(Math.abs(x)) ;
      return (x < 0 ? '-' : '') + hexFloat(Math.abs(x));
    }
    if (v === undefined || typeof v === 'boolean') return tostring(v);
    throw rterror("bad argument to 'format' (value has no literal form)");
  }

  // ----------------------------------------------------- patterns ------
  // lstrlib.c's matcher, ported line for line.
  var L_ESC = 37, CAP_UNFINISHED = -1, CAP_POSITION = -2, MAXCCALLS = 200, MAXCAPTURES = 32;
  function MatchState(src, pat) {
    this.src = src; this.pat = pat; this.level = 0; this.matchdepth = MAXCCALLS;
    this.capInit = new Array(MAXCAPTURES); this.capLen = new Array(MAXCAPTURES);
  }
  function classEnd(ms, p) {
    var pat = ms.pat, pe = pat.length;
    var c = pat.charCodeAt(p++);
    if (c === L_ESC) {
      if (p >= pe) throw rterror("malformed pattern (ends with '%')");
      return p + 1;
    }
    if (c === 91) {   // '['
      if (pat.charCodeAt(p) === 94) p++;
      do {
        if (p >= pe) throw rterror("malformed pattern (missing ']')");
        if (pat.charCodeAt(p++) === L_ESC && p < pe) p++;
      } while (pat.charCodeAt(p) !== 93);
      return p + 1;
    }
    return p;
  }
  function isalpha(c) { return (c >= 65 && c <= 90) || (c >= 97 && c <= 122); }
  function isdigit(c) { return c >= 48 && c <= 57; }
  function islower(c) { return c >= 97 && c <= 122; }
  function isupper(c) { return c >= 65 && c <= 90; }
  function isspace(c) { return c === 32 || (c >= 9 && c <= 13); }
  function iscntrl(c) { return c < 32 || c === 127; }
  function ispunct(c) { return c >= 33 && c <= 126 && !isalpha(c) && !isdigit(c); }
  function isxdigit(c) { return isdigit(c) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70); }
  function matchClass(c, cl) {
    var res;
    var low = cl >= 65 && cl <= 90 ? cl + 32 : cl;
    switch (low) {
      case 97: res = isalpha(c); break;            // a
      case 99: res = iscntrl(c); break;            // c
      case 100: res = isdigit(c); break;           // d
      case 103: res = c >= 33 && c <= 126; break;  // g
      case 108: res = islower(c); break;           // l
      case 112: res = ispunct(c); break;           // p
      case 115: res = isspace(c); break;           // s
      case 117: res = isupper(c); break;           // u
      case 119: res = isalpha(c) || isdigit(c); break; // w
      case 120: res = isxdigit(c); break;          // x
      default: return cl === c;
    }
    if (isupper(cl)) res = !res;
    return res;
  }
  function matchBracketClass(ms, c, p, ec) {
    var pat = ms.pat, sig = true;
    if (pat.charCodeAt(p + 1) === 94) { sig = false; p++; }
    while (++p < ec) {
      var pc = pat.charCodeAt(p);
      if (pc === L_ESC) {
        p++;
        if (matchClass(c, pat.charCodeAt(p))) return sig;
      } else if (pat.charCodeAt(p + 1) === 45 && p + 2 < ec) {
        p += 2;
        if (pat.charCodeAt(p - 2) <= c && c <= pat.charCodeAt(p)) return sig;
      } else if (pc === c) return sig;
    }
    return !sig;
  }
  function singleMatch(ms, s, p, ep) {
    if (s >= ms.src.length) return false;
    var c = ms.src.charCodeAt(s);
    var pc = ms.pat.charCodeAt(p);
    switch (pc) {
      case 46: return true;                                  // '.'
      case L_ESC: return matchClass(c, ms.pat.charCodeAt(p + 1));
      case 91: return matchBracketClass(ms, c, p, ep - 1);
      default: return pc === c;
    }
  }
  function matchBalance(ms, s, p) {
    if (p >= ms.pat.length - 1) throw rterror("malformed pattern (missing arguments to '%b')");
    var src = ms.src;
    if (src.charCodeAt(s) !== ms.pat.charCodeAt(p)) return -1;
    var b = ms.pat.charCodeAt(p), e = ms.pat.charCodeAt(p + 1), cont = 1;
    while (++s < src.length) {
      var c = src.charCodeAt(s);
      if (c === e) { if (--cont === 0) return s + 1; }
      else if (c === b) cont++;
    }
    return -1;
  }
  function maxExpand(ms, s, p, ep) {
    var i = 0;
    while (singleMatch(ms, s + i, p, ep)) i++;
    while (i >= 0) {
      var res = doMatch(ms, s + i, ep + 1);
      if (res !== -1) return res;
      i--;
    }
    return -1;
  }
  function minExpand(ms, s, p, ep) {
    for (;;) {
      var res = doMatch(ms, s, ep + 1);
      if (res !== -1) return res;
      else if (singleMatch(ms, s, p, ep)) s++;
      else return -1;
    }
  }
  function startCapture(ms, s, p, what) {
    var level = ms.level;
    if (level >= MAXCAPTURES) throw rterror('too many captures');
    ms.capInit[level] = s; ms.capLen[level] = what;
    ms.level = level + 1;
    var res = doMatch(ms, s, p);
    if (res === -1) ms.level--;
    return res;
  }
  function captureToClose(ms) {
    var level = ms.level;
    for (level--; level >= 0; level--) if (ms.capLen[level] === CAP_UNFINISHED) return level;
    throw rterror('invalid pattern capture');
  }
  function endCapture(ms, s, p) {
    var l = captureToClose(ms);
    ms.capLen[l] = s - ms.capInit[l];
    var res = doMatch(ms, s, p);
    if (res === -1) ms.capLen[l] = CAP_UNFINISHED;
    return res;
  }
  function checkCapture(ms, l) {
    l -= 49;
    if (l < 0 || l >= ms.level || ms.capLen[l] === CAP_UNFINISHED) throw rterror('invalid capture index %' + (l + 1));
    return l;
  }
  function matchCapture(ms, s, l) {
    l = checkCapture(ms, l);
    var len = ms.capLen[l];
    var cap = ms.src.substr(ms.capInit[l], len);
    if (ms.src.length - s >= len && ms.src.substr(s, len) === cap) return s + len;
    return -1;
  }
  function doMatch(ms, s, p) {
    if (ms.matchdepth-- === 0) throw rterror('pattern too complex');
    var pat = ms.pat, pe = pat.length;
    for (;;) {
      if (p === pe) break;
      var pc = pat.charCodeAt(p);
      if (pc === 40) {                                     // '('
        if (pat.charCodeAt(p + 1) === 41) s = startCapture(ms, s, p + 2, CAP_POSITION);
        else s = startCapture(ms, s, p + 1, CAP_UNFINISHED);
        break;
      }
      if (pc === 41) { s = endCapture(ms, s, p + 1); break; }   // ')'
      if (pc === 36 && p + 1 === pe) {                     // '$' at the end
        s = (s === ms.src.length) ? s : -1;
        break;
      }
      if (pc === L_ESC) {
        var nx = pat.charCodeAt(p + 1);
        if (nx === 98) {                                   // %b
          s = matchBalance(ms, s, p + 2);
          if (s !== -1) { p += 4; continue; }
          break;
        }
        if (nx === 102) {                                  // %f
          p += 2;
          if (pat.charCodeAt(p) !== 91) throw rterror("missing '[' after '%f' in pattern");
          var ep0 = classEnd(ms, p);
          var prev = (s === 0) ? 0 : ms.src.charCodeAt(s - 1);
          var cur = s < ms.src.length ? ms.src.charCodeAt(s) : 0;
          if (!matchBracketClass(ms, prev, p, ep0 - 1) && matchBracketClass(ms, cur, p, ep0 - 1)) { p = ep0; continue; }
          s = -1; break;
        }
        if (nx >= 48 && nx <= 57) {                        // %0-%9
          s = matchCapture(ms, s, nx);
          if (s !== -1) { p += 2; continue; }
          break;
        }
      }
      // default: a single class with an optional suffix
      var ep = classEnd(ms, p);
      var epc = pat.charCodeAt(ep);
      if (!singleMatch(ms, s, p, ep)) {
        if (epc === 42 || epc === 63 || epc === 45) { p = ep + 1; continue; }   // * ? -
        s = -1; break;
      }
      if (epc === 63) {                                    // ?
        var res = doMatch(ms, s + 1, ep + 1);
        if (res !== -1) { s = res; break; }
        p = ep + 1; continue;
      }
      if (epc === 43) { s = maxExpand(ms, s + 1, p, ep); break; }   // +
      if (epc === 42) { s = maxExpand(ms, s, p, ep); break; }       // *
      if (epc === 45) { s = minExpand(ms, s, p, ep); break; }       // -
      s++; p = ep;
    }
    ms.matchdepth++;
    return s;
  }
  function getCapture(ms, i, s, e) {
    if (i >= ms.level) {
      if (i !== 0) throw rterror('invalid capture index %' + (i + 1));
      return ms.src.slice(s, e);
    }
    var l = ms.capLen[i];
    if (l === CAP_UNFINISHED) throw rterror('unfinished capture');
    if (l === CAP_POSITION) return ms.capInit[i] + 1;
    return ms.src.substr(ms.capInit[i], l);
  }
  function captures(ms, s, e, wholeIfNone) {
    var n = (ms.level === 0 && wholeIfNone) ? 1 : ms.level;
    var out = [];
    for (var i = 0; i < n; i++) out.push(getCapture(ms, i, s, e));
    return out;
  }
  var SPECIALS = /[\^$*+?.()[\]%-]/;
  function strFindAux(find, s, p, init, plain, fname) {
    s = checkStr(s, 1, fname); p = checkStr(p, 2, fname);
    var ls = s.length;
    var st = posrelatI(optInt(init, 3, fname, 1), ls) - 1;
    if (st > ls) return undefined;
    if (find && (truthy(plain) || !SPECIALS.test(p))) {
      var idx = s.indexOf(p, st);
      if (idx >= 0) return new Multi([idx + 1, idx + p.length]);
      return undefined;
    }
    var anchor = p.charCodeAt(0) === 94;
    var pp = anchor ? p.slice(1) : p;
    var ms = new MatchState(s, pp);
    var s1 = st;
    do {
      ms.level = 0; ms.matchdepth = MAXCCALLS;
      var res = doMatch(ms, s1, 0);
      if (res !== -1) {
        if (find) return new Multi([s1 + 1, res].concat(captures(ms, -1, 0, false)));
        return ret(captures(ms, s1, res, true));
      }
    } while (s1++ < ls && !anchor);
    return undefined;
  }
  stringLib.set('find', function (s, p, init, plain) { return strFindAux(true, s, p, init, plain, 'find'); });
  stringLib.set('match', function (s, p, init) { return strFindAux(false, s, p, init, false, 'match'); });
  stringLib.set('gmatch', function (s, p, init) {
    s = checkStr(s, 1, 'gmatch'); p = checkStr(p, 2, 'gmatch');
    var ls = s.length;
    var src = posrelatI(optInt(init, 3, 'gmatch', 1), ls) - 1;
    if (src > ls) src = ls + 1;
    var ms = new MatchState(s, p), lastmatch = -1;
    return function () {
      for (; src <= ls; src++) {
        ms.level = 0; ms.matchdepth = MAXCCALLS;
        var e = doMatch(ms, src, 0);
        if (e !== -1 && e !== lastmatch) {
          var start = src;
          src = lastmatch = e;
          return ret(captures(ms, start, e, true));
        }
      }
      return undefined;
    };
  });
  stringLib.set('gsub', function (s, p, repl, maxn) {
    s = checkStr(s, 1, 'gsub'); p = checkStr(p, 2, 'gsub');
    var tr = typeName(repl);
    if (!(tr === 'number' || tr === 'string' || tr === 'table' || tr === 'function')) {
      throw argError(3, 'gsub', 'string/function/table expected, got ' + typeNameArg(repl));
    }
    var maxS = maxn === undefined ? s.length + 1 : checkInt(maxn, 4, 'gsub');
    var anchor = p.charCodeAt(0) === 94;
    var pp = anchor ? p.slice(1) : p;
    var ms = new MatchState(s, pp);
    var src = 0, lastmatch = -1, n = 0, out = '';
    var rs = tr === 'string' || tr === 'number' ? (typeof repl === 'string' ? repl : numStr(repl)) : null;
    while (n < maxS) {
      ms.level = 0; ms.matchdepth = MAXCCALLS;
      var e = doMatch(ms, src, 0);
      if (e !== -1 && e !== lastmatch) {
        n++;
        out += addValue(ms, src, e, repl, rs, tr);
        src = lastmatch = e;
      } else if (src < s.length) out += s[src++];
      else break;
      if (anchor) break;
    }
    if (src < s.length) out += s.slice(src);
    return new Multi([out, n]);
  });
  function addValue(ms, s, e, repl, rs, tr) {
    var whole = ms.src.slice(s, e), v;
    if (rs !== null) {
      var o = '';
      for (var i = 0; i < rs.length; i++) {
        var c = rs[i];
        if (c !== '%') { o += c; continue; }
        i++;
        var d = rs[i];
        if (d === '%') o += '%';
        else if (d !== undefined && d >= '0' && d <= '9') {
          var cap = d === '0' ? whole : getCapture(ms, d.charCodeAt(0) - 49, s, e);
          o += typeof cap === 'string' ? cap : numStr(cap);
        } else throw rterror("invalid use of '%' in replacement string");
      }
      return o;
    }
    var caps = captures(ms, s, e, true);
    if (tr === 'table') v = index(repl, caps[0]);
    else v = first(call(repl).apply(null, caps));
    if (v === undefined || v === false) return whole;
    if (typeof v === 'string') return v;
    if (isNum(v)) return numStr(v);
    throw rterror('invalid replacement value (a ' + typeName(v) + ')');
  }

  // ===================================================== conversion =======
  // Between JS values (UTF-16 strings, arrays, objects) and Lua values.
  var encoder = typeof TextEncoder !== 'undefined' ? new TextEncoder() : null;
  var decoder = typeof TextDecoder !== 'undefined' ? new TextDecoder('utf-8') : null;
  function toBytes(str) {        // JS string -> Lua byte string
    if (/^[\x00-\x7f]*$/.test(str)) return str;
    var b = encoder.encode(str), s = '';
    for (var i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
    return s;
  }
  function fromBytes(s) {        // Lua byte string -> JS string
    if (/^[\x00-\x7f]*$/.test(s)) return s;
    var b = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) b[i] = s.charCodeAt(i);
    return decoder.decode(b);
  }
  function toLua(v) {
    if (v === null || v === undefined) return undefined;
    if (typeof v === 'string') return toBytes(v);
    if (typeof v === 'number' || typeof v === 'boolean' || typeof v === 'function') return v;
    if (v instanceof LuaTable || v instanceof LFloat) return v;
    var t = new LuaTable();
    if (Array.isArray(v)) { for (var i = 0; i < v.length; i++) t.set(i + 1, toLua(v[i])); return t; }
    Object.keys(v).forEach(function (k) { t.set(toBytes(k), toLua(v[k])); });
    return t;
  }
  function toJS(v, seen) {
    if (v instanceof LFloat) return v.n;
    if (typeof v === 'string') return fromBytes(v);
    if (!(v instanceof LuaTable)) return v;
    seen = seen || new Map();
    if (seen.has(v)) return seen.get(v);
    var n = v.arr.length, hashSize = v.hash ? v.hash.size : 0;
    if (hashSize === 0) {
      var a = [];
      seen.set(v, a);
      for (var i = 0; i < n; i++) a.push(toJS(v.arr[i], seen));
      return a;
    }
    var o = {};
    seen.set(v, o);
    for (var j = 0; j < n; j++) if (v.arr[j] !== undefined) o[j + 1] = toJS(v.arr[j], seen);
    v.hash.forEach(function (val, key) {
      var k = typeof key === 'string' ? fromBytes(key) : (isNum(key) ? numStr(key) : tostring(key));
      o[k] = toJS(val, seen);
    });
    return o;
  }

  NS.LFloat = LFloat; NS.mkf = mkf; NS.Multi = Multi; NS.first = first; NS.sp = sp; NS.ret = ret;
  NS.LuaTable = LuaTable; NS.NONE = NONE; NS.LuaError = LuaError; NS.lineMaps = lineMaps;
  NS.add = add; NS.sub = sub; NS.mul = mul; NS.div = div; NS.idiv = idiv; NS.mod = mod; NS.pow = pow;
  NS.unm = unm; NS.band = band; NS.bor = bor; NS.bxor = bxor; NS.shl = shl; NS.shr = shr; NS.bnot = bnot;
  NS.concat = concat; NS.len = len; NS.eq = eq; NS.lt = lt; NS.le = le; NS.gt = gt; NS.ge = ge;
  NS.T = truthy; NS.index = index; NS.setindex = setindex; NS.call = call; NS.method = method;
  NS.tbl = tbl; NS.iter = iter; NS.forprep = forprep; NS.tostring = tostring; NS.typeName = typeName;
  NS.makeEnv = makeEnv; NS.toLua = toLua; NS.toJS = toJS; NS.toBytes = toBytes; NS.fromBytes = fromBytes;
  NS.numStr = numStr; NS.str2num = str2num; NS.errorValue = errorValue; NS.rterror = rterror;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawLua = globalThis.MiddawLua || {}))
  : (globalThis.MiddawLua = globalThis.MiddawLua || {}));


/* ---- kit/runtime/lua_compile.js ---- */
/* Middaw's Lua 5.4, part 2 of 3: syntax tree in, JavaScript out.
 *
 * Every Lua local becomes a JS `let` with a name of its own ($x, $x$2...), so
 * shadowing and closures behave as in Lua: a fresh binding per declaration,
 * and per loop iteration. Every operator goes through the runtime, so the
 * integer/float distinction and the error messages are Lua's. Each statement
 * starts a new line carrying a marker with its Lua line number, which is how
 * an error raised in the generated code is reported at the Lua line.
 */
(function (NS) {
  'use strict';

  var ARITH = { '+': 'add', '-': 'sub', '*': 'mul', '/': 'div', '%': 'mod', '^': 'pow', '//': 'idiv',
                '&': 'band', '|': 'bor', '~': 'bxor', '<<': 'shl', '>>': 'shr', '..': 'concat' };
  var COMPARE = { '==': 'eq', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge' };

  function compile(ast, chunk) {
    var consts = [];
    var nameCounts = Object.create(null);

    function uniqueName(luaName) {
      var n = (nameCounts[luaName] || 0) + 1;
      nameCounts[luaName] = n;
      return n === 1 ? '$' + luaName : '$' + luaName + '$' + n;
    }

    function FuncState(parent, vararg) {
      this.parent = parent; this.vararg = vararg; this.temps = 0; this.scopes = [];
    }
    var fs = null;
    var stmtUid = 0;

    function newTemp() { fs.temps++; return '$$' + fs.temps; }
    function lookup(name) {
      for (var f = fs; f; f = f.parent) {
        for (var i = f.scopes.length - 1; i >= 0; i--) {
          var js = f.scopes[i][name];
          if (js !== undefined) return js;
        }
      }
      return null;
    }
    function declare(name) {
      var js = uniqueName(name);
      fs.scopes[fs.scopes.length - 1][name] = js;
      return js;
    }
    function openScope() { fs.scopes.push(Object.create(null)); }
    function closeScope() { fs.scopes.pop(); }

    function err(msg, line) {
      throw new NS.LuaSyntaxError(msg, chunk, line || 0);
    }

    function str(s) { return JSON.stringify(s); }

    function numberLiteral(text) {
      var v;
      if (/^0[xX]/.test(text)) {
        if (/[.pP]/.test(text)) v = NS.str2num(text);
        else {
          var big = BigInt.asIntN(64, BigInt('0x' + text.slice(2)));
          return String(Number(big));
        }
      } else if (/[.eE]/.test(text)) {
        v = NS.mkf(Number(text));
      } else {
        var n = Number(text);
        if (Math.abs(n) > 9223372036854775807) v = NS.mkf(n);
        else return String(n);
      }
      if (v instanceof NS.LFloat) {
        var idx = consts.length;
        consts.push(v);
        return '$$K[' + idx + ']';
      }
      var s = String(v);
      return s === 'Infinity' ? 'Infinity' : (s === 'NaN' ? 'NaN' : (v < 0 ? '(' + s + ')' : s));
    }

    function describe(e) {
      if (e.k === 'Name') return lookup(e.name) ? "local '" + e.name + "'" : "global '" + e.name + "'";
      if (e.k === 'Index' && e.key.k === 'String') return "field '" + e.key.v + "'";
      if (e.k === 'Method') return "method '" + e.name + "'";
      return '';
    }

    function isMultiExpr(e) { return e.k === 'Call' || e.k === 'Method' || e.k === 'Vararg'; }

    // A JS expression for the raw result of a call: possibly a Multi.
    function callRaw(e) {
      if (e.k === 'Method') {
        var o = ex(e.obj);
        var args = argList(e.args);
        return 'L.method(' + o + ', ' + str(e.name) + (args ? ', ' + args : '') + ')';
      }
      var fn = ex(e.fn), a = argList(e.args), d = describe(e.fn);
      if (/^\$[A-Za-z_][\w$]*$/.test(fn)) {
        return '(typeof ' + fn + " === 'function' ? " + fn + ' : L.call(' + fn + ', ' + str(d) + '))(' + a + ')';
      }
      var t = newTemp();
      return '(typeof (' + t + ' = ' + fn + ") === 'function' ? " + t + ' : L.call(' + t + ', ' + str(d) + '))(' + a + ')';
    }

    function argList(exprs) {
      var out = [];
      for (var i = 0; i < exprs.length; i++) {
        var e = exprs[i], last = i === exprs.length - 1;
        if (last && (e.k === 'Call' || e.k === 'Method')) out.push('...L.sp(' + callRaw(e) + ')');
        else if (last && e.k === 'Vararg') { checkVararg(e); out.push('...$$va'); }
        else out.push(ex(e));
      }
      return out.join(', ');
    }
    function checkVararg(e) {
      if (!fs.vararg) err("cannot use '...' outside a vararg function", e.line);
    }

    // A JS expression for exactly one Lua value.
    function ex(e) {
      switch (e.k) {
        case 'Nil': return 'undefined';
        case 'True': return 'true';
        case 'False': return 'false';
        case 'Number': return numberLiteral(e.v);
        case 'String': return str(e.v);
        case 'Vararg': checkVararg(e); return '$$va[0]';
        case 'Function': return funcExpr(e);
        case 'Paren': return ex(e.expr);
        case 'Name': {
          var js = lookup(e.name);
          if (js) return js;
          return 'L.index($$G, ' + str(e.name) + ')';
        }
        case 'Index':
          return 'L.index(' + ex(e.obj) + ', ' + ex(e.key) + ', ' + str(describe(e.obj)) + ')';
        case 'Call': case 'Method':
          return 'L.first(' + callRaw(e) + ')';
        case 'Table': return tableExpr(e);
        case 'Unop': {
          if (e.op === 'not') return '!' + cond(e.expr);
          if (e.op === '-') {
            if (e.expr.k === 'Number') {
              var lit = numberLiteral(e.expr.v);
              if (/^\d+$/.test(lit)) return lit === '0' ? '0' : '(-' + lit + ')';
              if (/^[\d.e+-]+$/.test(lit)) return '(-' + lit + ')';
            }
            return 'L.unm(' + ex(e.expr) + ')';
          }
          if (e.op === '#') return 'L.len(' + ex(e.expr) + ')';
          if (e.op === '~') return 'L.bnot(' + ex(e.expr) + ')';
          break;
        }
        case 'Binop': {
          if (e.op === 'and') {
            var t = newTemp();
            return '(L.T(' + t + ' = ' + ex(e.left) + ') ? ' + ex(e.right) + ' : ' + t + ')';
          }
          if (e.op === 'or') {
            var t2 = newTemp();
            return '(L.T(' + t2 + ' = ' + ex(e.left) + ') ? ' + t2 + ' : ' + ex(e.right) + ')';
          }
          if (e.op === '~=') return '!L.eq(' + ex(e.left) + ', ' + ex(e.right) + ')';
          if (COMPARE[e.op]) return 'L.' + COMPARE[e.op] + '(' + ex(e.left) + ', ' + ex(e.right) + ')';
          return 'L.' + ARITH[e.op] + '(' + ex(e.left) + ', ' + ex(e.right) + ')';
        }
      }
      err('cannot compile expression ' + e.k, e.line);
    }

    // A JS boolean expression for Lua truth, without building a Lua value.
    function cond(e) {
      switch (e.k) {
        case 'True': return 'true';
        case 'False': case 'Nil': return 'false';
        case 'Paren': return cond(e.expr);
        case 'Unop': if (e.op === 'not') return '!' + cond(e.expr); break;
        case 'Binop':
          if (e.op === 'and') return '(' + cond(e.left) + ' && ' + cond(e.right) + ')';
          if (e.op === 'or') return '(' + cond(e.left) + ' || ' + cond(e.right) + ')';
          if (e.op === '~=' || COMPARE[e.op]) return ex(e);
          break;
      }
      return 'L.T(' + ex(e) + ')';
    }

    function tableExpr(e) {
      var pos = [], keyed = [];
      for (var i = 0; i < e.items.length; i++) {
        var it = e.items[i];
        if (it.kind === 'pos') {
          var lastPos = true;
          for (var j = i + 1; j < e.items.length; j++) if (e.items[j].kind === 'pos') { lastPos = false; break; }
          if (lastPos && (it.value.k === 'Call' || it.value.k === 'Method')) pos.push('...L.sp(' + callRaw(it.value) + ')');
          else if (lastPos && it.value.k === 'Vararg') { checkVararg(it.value); pos.push('...$$va'); }
          else pos.push(ex(it.value));
        } else {
          keyed.push(ex(it.key), ex(it.value));
        }
      }
      if (!keyed.length) return 'L.tbl([' + pos.join(', ') + '])';
      return 'L.tbl([' + pos.join(', ') + '], [' + keyed.join(', ') + '])';
    }

    function funcExpr(f) {
      var saved = fs;
      fs = new FuncState(saved, f.vararg);
      openScope();
      var params = f.params.map(function (p) { return declare(p); });
      if (f.vararg) params.push('...$$va');
      var body = block(f.body);
      closeScope();
      var temps = '';
      if (fs.temps) {
        var names = [];
        for (var i = 1; i <= fs.temps; i++) names.push('$$' + i);
        temps = 'let ' + names.join(', ') + ';';
      }
      fs = saved;
      return 'function (' + params.join(', ') + ') {' + temps + body + '\n/*@' + (f.endLine || f.line) + '*/return L.NONE;}';
    }

    function block(stmts) {
      var out = '';
      for (var i = 0; i < stmts.length; i++) out += statement(stmts[i]);
      return out;
    }
    function scoped(stmts) {
      openScope();
      var b = block(stmts);
      closeScope();
      return b;
    }

    function assignTo(target, value) {
      if (target.k === 'Name') {
        var js = lookup(target.name);
        if (js) return js + ' = ' + value + ';';
        return 'L.setindex($$G, ' + str(target.name) + ', ' + value + ');';
      }
      return 'L.setindex(' + ex(target.obj) + ', ' + ex(target.key) + ', ' + value + ', ' + str(describe(target.obj)) + ');';
    }

    function valuesArray(exprs) { return '[' + argList(exprs) + ']'; }

    function statement(s) {
      var mark = '\n/*@' + (s.line || 0) + '*/';
      switch (s.k) {
        case 'Local': {
          var attrs = s.attribs || [];
          attrs.forEach(function (a) {
            if (a && a !== 'const' && a !== 'close') err("unknown attribute '" + a + "'", s.line);
          });
          if (s.names.length === 1 && s.exprs.length <= 1) {
            var v = s.exprs.length ? ex(s.exprs[0]) : 'undefined';
            return mark + 'let ' + declare(s.names[0]) + ' = ' + v + ';';
          }
          if (s.exprs.length === s.names.length && !s.exprs.some(isMultiExpr)) {
            var vals = s.exprs.map(ex);
            var tmpNames = vals.map(function () { return '$$l' + (++stmtUid); });
            var pre = 'const ' + tmpNames.map(function (t, i) { return t + ' = ' + vals[i]; }).join(', ') + ';';
            var decl = s.names.map(function (n, i) { return declare(n) + ' = ' + tmpNames[i]; });
            return mark + pre + ' let ' + decl.join(', ') + ';';
          }
          var r = '$$r' + (++stmtUid);
          var code = 'const ' + r + ' = ' + valuesArray(s.exprs) + ';';
          var decls = s.names.map(function (n, i) { return declare(n) + ' = ' + r + '[' + i + ']'; });
          return mark + code + ' let ' + decls.join(', ') + ';';
        }
        case 'LocalFunction': {
          var name = declare(s.name);
          return mark + 'let ' + name + '; ' + name + ' = ' + funcExpr(s.func) + ';';
        }
        case 'Assign': {
          if (s.targets.length === 1 && s.exprs.length === 1) {
            return mark + assignTo(s.targets[0], ex(s.exprs[0]));
          }
          var rr = '$$r' + (++stmtUid);
          var c2 = 'const ' + rr + ' = ' + valuesArray(s.exprs) + ';';
          s.targets.forEach(function (t, i) { c2 += ' ' + assignTo(t, rr + '[' + i + ']'); });
          return mark + c2;
        }
        case 'ExprStat':
          return mark + callRaw(s.expr) + ';';
        case 'Do':
          return mark + '{' + scoped(s.body) + '\n}';
        case 'While':
          return mark + 'while (' + cond(s.cond) + ') {' + scoped(s.body) + '\n}';
        case 'Repeat': {
          openScope();
          var body = block(s.body);
          var cnd = cond(s.cond);
          closeScope();
          return mark + 'for (;;) {' + body + '\nif (' + cnd + ') break;\n}';
        }
        case 'If': {
          var o = mark;
          s.clauses.forEach(function (c, i) {
            o += (i ? ' else if (' : 'if (') + cond(c.cond) + ') {' + scoped(c.body) + '\n}';
          });
          if (s.orelse) o += ' else {' + scoped(s.orelse) + '\n}';
          return o;
        }
        case 'NumFor': {
          var u = ++stmtUid;
          var I = '$$i' + u, LIM = '$$m' + u, ST = '$$s' + u, FL = '$$f' + u;
          var start = ex(s.start), limit = ex(s.limit);
          var stepLit = !s.step ? 1 : (s.step.k === 'Number' && /^\d+$/.test(s.step.v) ? Number(s.step.v) : null);
          var step = s.step ? ex(s.step) : '1';
          var intStart = s.start.k === 'Number' && /^\d+$/.test(s.start.v);
          var test = stepLit !== null && stepLit > 0 ? I + ' <= ' + LIM : '(' + ST + ' > 0 ? ' + I + ' <= ' + LIM + ' : ' + I + ' >= ' + LIM + ')';
          openScope();
          var v2 = declare(s.name);
          var bindVal = (intStart && stepLit !== null) ? I : FL + ' ? L.mkf(' + I + ') : ' + I;
          var bd = block(s.body);
          closeScope();
          return mark + 'for (let [' + I + ', ' + LIM + ', ' + ST + ', ' + FL + '] = L.forprep(' + start + ', ' + limit + ', ' + step + '); ' +
                 test + '; ' + I + ' += ' + ST + ') { let ' + v2 + ' = ' + bindVal + ';' + bd + '\n}';
        }
        case 'GenFor': {
          var it = '$$it' + (++stmtUid);
          var head = 'const ' + it + ' = L.iter(' + argList(s.exprs) + ');';
          openScope();
          var binds = s.names.map(function (n, i) {
            var src = i === 0 ? it + '.a' : (i === 1 ? it + '.b' : it + '.v[' + i + ']');
            return declare(n) + ' = ' + src;
          });
          var gb = block(s.body);
          closeScope();
          return mark + '{' + head + ' while (' + it + '.step()) { let ' + binds.join(', ') + ';' + gb + '\n}}';
        }
        case 'Return': {
          var ex0 = s.exprs;
          if (!ex0.length) return mark + 'return L.NONE;';
          if (ex0.length === 1) {
            if (ex0[0].k === 'Call' || ex0[0].k === 'Method') return mark + 'return ' + callRaw(ex0[0]) + ';';
            if (ex0[0].k === 'Vararg') { checkVararg(ex0[0]); return mark + 'return L.ret($$va);'; }
            return mark + 'return ' + ex(ex0[0]) + ';';
          }
          return mark + 'return L.ret(' + valuesArray(ex0) + ');';
        }
        case 'Break': return mark + 'break;';
        case 'Goto': case 'Label':
          err('goto and labels are not supported by Middaw\'s Lua', s.line);
      }
      err('cannot compile statement ' + s.k, s.line);
    }

    fs = new FuncState(null, true);
    openScope();
    var body = block(ast.body);
    closeScope();
    var temps = '';
    if (fs.temps) {
      var names = [];
      for (var i = 1; i <= fs.temps; i++) names.push('$$' + i);
      temps = 'let ' + names.join(', ') + ';';
    }
    return { body: temps + body, consts: consts };
  }

  // The line the first line of a `new Function` body is reported as.
  var lineOffset = null;
  function probeOffset() {
    if (lineOffset !== null) return lineOffset;
    try {
      new Function('throw new Error("probe");\n//# sourceURL=lua:__probe__')();
    } catch (e) {
      var m = /lua:__probe__:(\d+)/.exec(e.stack || '');
      lineOffset = m ? Number(m[1]) - 1 : 0;
    }
    return lineOffset;
  }

  var chunkUid = 0;
  // Lua source (a byte string) -> a JS function, as `load` gives it.
  function load(src, chunkname, env) {
    var name = String(chunkname || 'chunk').replace(/[^A-Za-z0-9_.\/-]/g, '_');
    if (NS.lineMaps[name]) name = name + '#' + (++chunkUid);
    var ast = NS.parse(src, name);
    var out = compile(ast, name);
    var code = 'return function (...$$va) {' + out.body + '\nreturn L.NONE;\n};';
    var offset = probeOffset();
    var lines = code.split('\n'), map = [], cur = 0;
    for (var i = 0; i < offset; i++) map.push(0);
    for (var j = 0; j < lines.length; j++) {
      var m = /^\/\*@(\d+)\*\//.exec(lines[j]);
      if (m) cur = Number(m[1]);
      map.push(cur);
    }
    NS.lineMaps[name.replace(/#/g, '_')] = map;
    var factory = new Function('L', '$$G', '$$K', code + '\n//# sourceURL=lua:' + name.replace(/#/g, '_'));
    return factory(NS, env || NS.defaultEnv(), out.consts);
  }

  var sharedEnv = null;
  NS.defaultEnv = function () { return sharedEnv || (sharedEnv = NS.makeEnv()); };
  NS.compile = compile;
  NS.load = load;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawLua = globalThis.MiddawLua || {}))
  : (globalThis.MiddawLua = globalThis.MiddawLua || {}));


/* ---- kit/runtime/host.js ---- */
/* The family's Lua engines, spoken to in JSON.
 *
 * The native app runs this in JavaScriptCore, after the Lua runtime
 * (runtime/lua/), and calls `MiddawHost.call(method, argsJSON)`; the tests run
 * it in Node. It knows no browser and no files: the host hands it a
 * `readFile(path)` that returns the file's bytes as a string, one character
 * per byte, which is how Middaw's Lua keeps its strings.
 *
 * The adapters (Noterator's) are how the generators are spoken to - settings
 * in, notes out - the same protocol Miderator and Noterator use.
 */
(function (G) {
  'use strict';
  var L = G.MiddawLua;

  var FILES = [
    'good-idea/gi_theory.lua', 'good-idea/gi_idea.lua',
    'midi-catalogue/mc_theory.lua', 'midi-catalogue/mc_orchestra.lua', 'midi-catalogue/mc_catalogue.lua',
    'midi-suggester/ms_theory.lua', 'midi-suggester/ms_read.lua', 'midi-suggester/ms_harmony.lua', 'midi-suggester/ms_melody.lua',
    'midi-variator/mv_theory.lua', 'midi-variator/mv_vary.lua',
    'starting-blocks/sb_engine.lua',
    'adapters/common.lua', 'adapters/index.lua', 'adapters/good_idea.lua', 'adapters/midi_suggester.lua',
    'adapters/midi_variator.lua', 'adapters/starting_blocks.lua', 'adapters/midi_catalogue.lua',
    'notation/sb_notate.lua', 'notation/sb_draw.lua', 'notation/sb_glyphs.lua',
    'battle-pass/bp_theory.lua', 'battle-pass/bp_loot.lua', 'battle-pass/bp_game.lua',
    'orchestration/orchestration_data.lua', 'orchestration/orchestration_composers.lua'
  ];

  var readFile = null, modules = {}, env = null, log = function () {};

  function engine(name) {
    if (modules[name] === undefined) {
      var src = readFile(name);
      if (src === null || src === undefined) throw new Error("engine '" + name + "' is not there");
      var r = L.first(L.load(src, name, env)());
      modules[name] = r === undefined ? false : r;
    }
    return modules[name];
  }

  function init(reader, logger) {
    readFile = reader;
    if (logger) log = logger;
    modules = {};
    env = L.makeEnv({
      print: function (s) { log('[lua] ' + L.fromBytes(s)); },
      readFile: function () { return null; },
      writeFile: function () {}
    });
    env.set('engine', function (name) { return engine(name); });
    env.set('dofile', function (name) { return L.first(engine(String(name).replace(/^.*engines\//, ''))); });
    return true;
  }

  function call(mod, fname) {
    var m = typeof mod === 'string' ? engine(mod) : mod;
    var f = L.index(m, fname);
    var args = [];
    for (var i = 2; i < arguments.length; i++) {
      var a = arguments[i];
      args.push(a instanceof L.LuaTable ? a : L.toLua(a));
    }
    return L.first(L.call(f).apply(null, args));
  }
  function js(v) { return L.toJS(v); }
  function list(x) { return !x ? [] : Array.isArray(x) ? x : Object.keys(x).map(function (k) { return x[k]; }); }

  // --------------------------------------------------------- generators --
  var adapters = null;
  function gens() {
    if (adapters) return adapters;
    adapters = list(js(engine('adapters/index.lua'))).map(function (path) {
      var A = engine(path);
      return { id: js(L.index(A, 'id')), name: js(L.index(A, 'name')), description: js(L.index(A, 'description')) || '',
               input: js(L.index(A, 'input')), panel: js(L.index(A, 'panel')) || null, A: A, path: path };
    });
    return adapters;
  }
  function gen(id) {
    var l = gens();
    for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i];
    throw new Error('no generator ' + id);
  }

  // A generator's settings live in Lua, as the engine left them.
  var sessions = {}, nextSession = 1;
  function session(id) { var s = sessions[id]; if (!s) throw new Error('no session ' + id); return s; }
  function normalise(r) {
    r = r || { results: [] };
    r.results = list(r.results);
    r.results.forEach(function (res) {
      res.parts = list(res.parts);
      res.parts.forEach(function (p) { p.notes = list(p.notes); });
    });
    return r;
  }

  // ------------------------------------------------------------- theory --
  // Chord names are ScaleView's, read by Midi Variator's port of it.
  // mv_theory knows the seven-note scales; anything else names chords
  // against the parallel major or minor. Indexed by ScaleView's scale (1-16).
  var MV_SCALE = [1, 2, 3, 1, 4, 5, 6, 7, 2, 1, 2, 1, 2, 1, 2, 1];
  var keyCache = {};
  function luaKey(key) {
    var k = key.root + ':' + key.scale;
    if (!keyCache[k]) keyCache[k] = call('midi-variator/mv_theory.lua', 'key', key.root, MV_SCALE[key.scale - 1] || 1);
    return keyCache[k];
  }

  // -------------------------------------------------------- orchestra ----
  // Noterator's instruments beyond the orchestra (Source/Core/Instruments.cpp).
  var EXTRA = [
    { id: 'asax', name: 'Alto Saxophone', family: 'Woodwind', low: 49, high: 80, sweet: [53, 76], poly: 1, fast: 0.09, leap: 12 },
    { id: 'tsax', name: 'Tenor Saxophone', family: 'Woodwind', low: 44, high: 75, sweet: [48, 70], poly: 1, fast: 0.09, leap: 12 },
    { id: 'bsax', name: 'Baritone Saxophone', family: 'Woodwind', low: 36, high: 69, sweet: [40, 62], poly: 1, fast: 0.10, leap: 12 },
    { id: 'vib', name: 'Vibraphone', family: 'Percussion', low: 53, high: 89, sweet: [55, 84], poly: 4, fast: 0.09, leap: 12 },
    { id: 'sop', name: 'Soprano', family: 'Voices', low: 60, high: 81, sweet: [64, 77], poly: 1, fast: 0.15, leap: 9 },
    { id: 'alto', name: 'Alto', family: 'Voices', low: 53, high: 74, sweet: [57, 69], poly: 1, fast: 0.15, leap: 9 },
    { id: 'ten', name: 'Tenor', family: 'Voices', low: 48, high: 69, sweet: [50, 65], poly: 1, fast: 0.15, leap: 9 },
    { id: 'bass', name: 'Bass', family: 'Voices', low: 40, high: 64, sweet: [43, 60], poly: 1, fast: 0.15, leap: 9 },
    { id: 'gtr', name: 'Guitar', family: 'Band', low: 40, high: 83, sweet: [45, 76], poly: 6, fast: 0.08, leap: 12 },
    { id: 'ebass', name: 'Bass Guitar', family: 'Band', low: 28, high: 67, sweet: [28, 55], poly: 1, fast: 0.09, leap: 12 },
    { id: 'ubass', name: 'Upright Bass', family: 'Band', low: 28, high: 67, sweet: [28, 55], poly: 1, fast: 0.10, leap: 12 },
    { id: 'synth', name: 'Synth', family: 'Band', low: 24, high: 108, sweet: [36, 96], poly: 16, fast: 0.03, leap: 48 },
    { id: 'kit', name: 'Drum Kit', family: 'Band', low: 35, high: 81, sweet: [35, 81], poly: 4, fast: 0.05, leap: 127, drums: true }
  ];

  // ----------------------------------------------------------- notation --
  var notate = null;
  function notation() {
    if (notate) return notate;
    var N = engine('notation/sb_notate.lua'), D = engine('notation/sb_draw.lua'), Gl = engine('notation/sb_glyphs.lua');
    L.call(L.index(D, 'setNotate'))(N);
    L.call(L.index(D, 'setGlyphs'))(Gl);
    notate = { N: N, D: D, E: engine('starting-blocks/sb_engine.lua') };
    return notate;
  }
  // A pen that records what Starting Blocks Notation draws, for the native
  // side to replay. sb_draw.lua uses four calls; colours arrive as the ids
  // given to it (1 ink, 2 staff, 3 ground, 4 accent):
  //   ["line", x1, y1, x2, y2, colour, thickness]
  //   ["poly", [x, y, x, y, ...], colour]
  //   ["circle", x, y, r, colour, filled]
  //   ["text", x, y, colour, text, size, centred]
  function num(v) { return v instanceof L.LFloat ? v.n : +v; }
  function colour(c) { return c instanceof L.LuaTable ? js(c) : num(c); }
  function recordingPen(ops) {
    var pen = new L.LuaTable();
    pen.set('line', function (x1, y1, x2, y2, col, th) {
      ops.push(['line', num(x1), num(y1), num(x2), num(y2), colour(col), th === undefined ? 1 : num(th)]); return L.NONE;
    });
    pen.set('poly', function (pts, col) {
      ops.push(['poly', pts.arr.map(num), colour(col)]); return L.NONE;
    });
    pen.set('circle', function (x, y, r, col, filled) {
      ops.push(['circle', num(x), num(y), num(r), colour(col), !!L.T(filled)]); return L.NONE;
    });
    pen.set('text', function (x, y, col, str, size, center) {
      ops.push(['text', num(x), num(y), colour(col), L.fromBytes(L.tostring(str)), num(size), !!L.T(center)]); return L.NONE;
    });
    return pen;
  }

  // ---------------------------------------------------------- the pass ---
  var pass = null, passState = null, passSession = null;
  function battlePass() {
    if (pass) return pass;
    var T = engine('battle-pass/bp_theory.lua');
    var Lt = L.first(L.call(L.index(engine('battle-pass/bp_loot.lua'), 'init'))(T));
    var Gm = L.first(L.call(L.index(engine('battle-pass/bp_game.lua'), 'init'))(Lt));
    pass = { G: Gm, L: Lt, T: T };
    return pass;
  }

  // ------------------------------------------------------------- methods -
  var M = {
    generators: function () {
      return gens().map(function (g) { return { id: g.id, name: g.name, description: g.description, input: g.input, panel: g.panel }; });
    },
    newSession: function (a) {
      var g = gen(a.generator), id = nextSession++;
      sessions[id] = { g: g, st: L.first(L.call(L.index(g.A, 'newState'))()) };
      return id;
    },
    useKey: function (a) { var s = session(a.session); call(s.g.A, 'useKey', s.st, a.key.root, a.key.scale); return true; },
    settings: function (a) { var s = session(a.session); return list(js(call(s.g.A, 'settings', s.st, L.toLua(a.context || {})))); },
    set: function (a) { var s = session(a.session); call(s.g.A, 'set', s.st, a.setting, a.index, L.toLua(a.context || {})); return true; },
    generate: function (a) {
      var s = session(a.session);
      return normalise(js(call(s.g.A, 'generate', s.st, L.toLua(a.context || {}), a.seed || 1, a.count || 6)));
    },
    snapshot: function (a) { return js(session(a.session).st); },
    restore: function (a) {
      var s = session(a.session);
      Object.keys(a.state || {}).forEach(function (k) { L.setindex(s.st, L.toBytes(k), L.toLua(a.state[k])); });
      return true;
    },
    closeSession: function (a) { delete sessions[a.session]; return true; },

    nameChord: function (a) {
      if (!a.pitches || a.pitches.length < 2) return '';
      var r = L.call(L.index(engine('midi-variator/mv_theory.lua'), 'nameChord'))(L.toLua(a.pitches), luaKey(a.key));
      return js(L.first(r)) || '';
    },
    noteNames: function (a) {
      var k = js(L.index(luaKey(a.key), 'names')), out = [];
      for (var pc = 0; pc < 12; pc++) out.push(k[pc] || k[String(pc)] || '');
      return out;
    },
    // Midi Variator's key finder (ScaleView's), as Miderator's key lane uses it.
    detectKey: function (a) {
      var notes = (a.notes || []).slice().sort(function (x, y) { return x.start - y.start; });
      if (!notes.length) return null;
      var r = list(js(call('midi-variator/mv_theory.lua', 'detectKey',
        notes.map(function (n) { return { pitch: n.pitch, start: n.start, len: n.len }; }),
        notes[0].pitch % 12, notes[notes.length - 1].pitch % 12)));
      if (!r.length) return null;
      return { root: r[0].root, scale: r[0].scale === 2 ? 2 : 1 };
    },
    // Midi Catalogue's orchestra, plus Noterator's band and voices.
    instruments: function () {
      return list(js(L.index(engine('midi-catalogue/mc_orchestra.lua'), 'INSTRUMENTS'))).concat(EXTRA);
    },
    orchestration: function () {
      var A = js(engine('orchestration/orchestration_data.lua'));
      var B = js(engine('orchestration/orchestration_composers.lua'));
      return { entries: list(A.ENTRIES).concat(list(B && B.ENTRIES)),
               sources: Object.assign({}, (B && B.SOURCES) || {}, A.SOURCES || {}) };
    },

    // A part engraved by Starting Blocks Notation: its height and the drawing,
    // as a list of pen calls in staff spaces of `space` points.
    engrave: function (a) {
      var nt = notation();
      var st = L.first(L.call(L.index(nt.E, 'newState'))());
      st.set('root', a.key.root); st.set('scale', a.key.scale); st.set('barBeats', a.barBeats);
      var ctx = L.first(L.call(L.index(nt.N, 'context'))(nt.E, st));
      var block = L.toLua({ notes: a.notes, beats: a.beats, name: a.name || '' });
      var opts = L.toLua({ barBeats: a.barBeats, tsNum: a.meter[0], tsDen: a.meter[1], width: a.width,
                           drums: !!a.drums, grid: a.drums ? 0.25 : undefined,
                           // a clip is as played, so its silences are rests (Starting Blocks Notation 0019)
                           rests: !a.drums });
      opts.set('ctx', ctx);
      var doc = L.first(L.call(L.index(nt.N, 'layout'))(block, opts));
      var height = +L.first(L.call(L.index(nt.D, 'height'))(doc, a.space));
      var ops = [];
      var colours = L.toLua({ ink: 1, staff: 2, ground: 3, accent: 4 });
      var popts = new L.LuaTable();
      if (a.highlight !== undefined && a.highlight >= 0) {
        var at = a.highlight * 960;
        popts.set('highlight', function (el) {
          var abs = L.index(el, 'abs'), ticks = L.index(el, 'ticks');
          return abs !== undefined && at >= +abs && at < +abs + +ticks;
        });
      }
      L.call(L.index(nt.D, 'page'))(recordingPen(ops), doc, 0, 0, a.space, colours, popts);
      return { height: height, ops: ops };
    },

    // The Battle Pass, unchanged: its state is the game's own text.
    // `clock` is seconds of activity time, `epoch` the wall clock in seconds.
    passStart: function (a) {
      var Gm = battlePass().G;
      passState = a.saved ? L.first(L.call(L.index(Gm, 'deserialize'))(L.toBytes(a.saved))) : undefined;
      if (!passState) passState = L.first(L.call(L.index(Gm, 'newState'))(a.epoch));
      L.call(L.index(Gm, 'clampState'))(passState, a.epoch);
      passSession = L.first(L.call(L.index(Gm, 'newSession'))(passState, a.clock, a.epoch));
      L.call(L.index(Gm, 'refresh'))(passState, passSession, a.epoch, new L.LuaTable());
      return true;
    },
    // Any bp_game function; "$state" and "$session" in `args` stand for the
    // game's own tables.
    passCall: function (a) {
      var args = (a.args || []).map(function (x) {
        return x === '$state' ? passState : x === '$session' ? passSession : L.toLua(x);
      });
      return js(L.first(L.call(L.index(battlePass().G, a.fn)).apply(null, args)));
    },
    // What the game wants celebrated since last asked, then forgotten.
    passNotices: function () {
      var l = L.index(passSession, 'notices');
      if (!l || !l.arr || !l.arr.length) return [];
      var out = l.arr.map(function (n) { return js(n); });
      l.arr.length = 0;
      return out;
    },
    passGet: function (a) {
      var v = passState;
      String(a.path).split('.').forEach(function (k) { v = v === undefined ? undefined : L.index(v, isNaN(+k) ? k : +k); });
      return v instanceof L.LFloat ? v.n : js(v);
    },
    // Middaw's composer (runtime/composer/, the port of middaw/): a sentence
    // in, the song's five parts out, exactly as `python3 -m middaw --json`
    // answers. composerLoad takes data/vocab/tags.json and drums.json as text.
    composerLoad: function (a) {
      if (!G.MiddawComposer || !G.MiddawComposer.load) throw new Error('the composer is not loaded');
      G.MiddawComposer.load(JSON.parse(a.tags), JSON.parse(a.drums));
      return true;
    },
    compose: function (a) {
      var C = G.MiddawComposer;
      if (!C || !C.vocabulary) throw new Error('the composer has no vocabulary');
      return C.compose(String(a.prompt || ''), a.seed === undefined || a.seed === null ? undefined : a.seed);
    },

    // The game's own tables that are not state: the shop, the check-in
    // calendar, the rarities (module 'loot').
    passConst: function (a) {
      var P = battlePass();
      var v = L.index(a.module === 'loot' ? P.L : P.G, String(a.name));
      // a list that is also indexed by name (G.SHOP[id]) is its list
      if (v instanceof L.LuaTable && L.index(v, 1) != null) {
        var out = [];
        for (var i = 1; L.index(v, i) != null; i++) out.push(js(L.index(v, i)));
        return out;
      }
      return js(v);
    },
    passSave: function () { return L.fromBytes(L.first(L.call(L.index(battlePass().G, 'serialize'))(passState))); },

    // AutoCC (the JSFX, unchanged) run over a clip's notes: the curves it
    // would play, as controller lanes {number: [[beat, value], ...]}. Only a
    // point where the value turns is kept, not every step.
    autoCC: function (a) {
      var J = G.MiddawJSFX;
      if (!J) throw new Error('the JSFX runtime is not loaded');
      var fx = new J.JSFX(a.source, {});
      Object.keys(a.sliders || {}).forEach(function (k) { fx.setSliderByIndex(Number(k), a.sliders[k]); });
      var sr = 48000, bs = 256;
      fx.init(sr);
      fx.setTime({ tempo: a.tempo, playState: 1, num: a.meter[0], den: a.meter[1] });
      var ev = [];
      (a.notes || []).forEach(function (n) {
        ev.push([n.start, [0x90, n.pitch, n.vel]]);
        ev.push([n.start + n.len, [0x80, n.pitch, 0]]);
      });
      ev.sort(function (x, y) { return x[0] - y[0]; });
      var spb = sr * 60 / a.tempo, total = Math.ceil(a.length * spb / bs) + 8, k = 0, lanes = {};
      for (var b = 0; b < total; b++) {
        var midi = [];
        while (k < ev.length && ev[k][0] * spb < (b + 1) * bs) {
          midi.push({ offset: Math.max(0, Math.round(ev[k][0] * spb - b * bs)), data: ev[k][1] }); k++;
        }
        fx.setTime({ beat: b * bs / spb, seconds: b * bs / sr });
        fx.process(bs, null, null, midi).forEach(function (m) {
          if ((m.data[0] & 0xF0) !== 0xB0) return;
          var beat = (b * bs + m.offset) / spb;
          if (beat > a.length) return;
          (lanes[m.data[1]] = lanes[m.data[1]] || []).push([Math.round(beat * 1000) / 1000, m.data[2]]);
        });
      }
      Object.keys(lanes).forEach(function (num) {
        var pts = lanes[num], out = [];
        pts.forEach(function (pt, i) {
          var prev = out[out.length - 1];
          if (!prev || i === pts.length - 1 || Math.abs(pt[1] - prev[1]) >= 2) out.push(pt);
        });
        lanes[num] = out;
      });
      return lanes;
    }
  };

  G.MiddawHost = {
    FILES: FILES,
    init: init,
    // The one entry point the native side uses: JSON in, JSON out, errors
    // returned rather than thrown so they cross the bridge as text.
    call: function (method, argsJSON) {
      try {
        if (!M[method]) throw new Error('no method ' + method);
        var r = M[method](argsJSON ? JSON.parse(argsJSON) : {});
        return JSON.stringify({ ok: true, value: r === undefined ? null : r });
      } catch (e) {
        var msg = e && (e.message || (e.value !== undefined ? String(L.tostring ? L.tostring(e.value) : e.value) : String(e)));
        return JSON.stringify({ ok: false, error: msg || 'error' });
      }
    },
    methods: M
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);


/* ---- kit/ui.js ---- */
/* The family's look, drawn with Max's mgraphics in a [v8ui].
 *
 * Colours are Palette's (palette.js), after Ableton Live 8: neutral greys,
 * the amber accent for what is on, every word 7:1 on its surface. A control
 * registers its rectangle while it is painted, so a click goes to whatever
 * was drawn under it last paint - no layout is kept twice.
 */
var UI = (function () {
  'use strict';
  function rgb(hex, a) {
    return [((hex >> 16) & 255) / 255, ((hex >> 8) & 255) / 255, (hex & 255) / 255, a === undefined ? 1 : a];
  }
  // The colours are Palette's (palette.js): Live 8's neutral greys and amber.
  var P = Palette.C;
  var C = {
    accent: rgb(P.accent), accentHeld: rgb(P.accentHeld), control: rgb(P.control), controlHeld: rgb(P.controlHeld),
    ground: rgb(P.ground), raised: rgb(P.raised), sunken: rgb(P.sunken), rule: rgb(P.rule),
    edge: rgb(P.edge), ink: rgb(P.ink), text: rgb(P.text), dim: rgb(P.dim),
    label: rgb(P.label), warn: rgb(P.warn), warnText: rgb(P.warnText), mark: rgb(P.mark), note: rgb(P.note)
  };

  var g = null, hits = [], drag = null, FONT = 'Arial';

  function begin(graphics) {
    g = graphics;
    hits = [];
    g.select_font_face(FONT);
  }
  function fill(c) { g.set_source_rgba(c[0], c[1], c[2], c[3]); }
  function rect(x, y, w, h, c) { fill(c); g.rectangle(x, y, w, h); g.fill(); }
  function round(x, y, w, h, r, c) { fill(c); g.rectangle_rounded(x, y, w, h, r, r); g.fill(); }
  function frame(x, y, w, h, c) { fill(c); g.set_line_width(1); g.rectangle(x + 0.5, y + 0.5, w - 1, h - 1); g.stroke(); }
  function measure(s, size) { g.set_font_size(size || 10); var m = g.text_measure(String(s)); return m[0]; }

  // Text cut to fit, with an ellipsis, so a long name never runs into the next control.
  function fit(s, w, size) {
    s = String(s);
    if (measure(s, size) <= w) return s;
    while (s.length > 1 && measure(s + '…', size) > w) s = s.slice(0, -1);
    return s + '…';
  }
  // align: 0 left, 1 centre, 2 right; y is the box top, h its height.
  function text(s, x, y, w, h, c, size, align, bold) {
    size = size || 10;
    g.select_font_face(FONT, 'normal', bold ? 'bold' : 'normal');
    g.set_font_size(size);
    var t = fit(s, w, size), tw = measure(t, size);
    var tx = align === 1 ? x + (w - tw) / 2 : align === 2 ? x + w - tw : x;
    fill(c);
    g.move_to(tx, y + h / 2 + size * 0.36);
    g.show_text(t);
    g.select_font_face(FONT, 'normal', 'normal');
  }

  function hit(x, y, w, h, handler) { hits.push({ x: x, y: y, w: w, h: h, fn: handler }); }
  function find(px, py) {
    for (var i = hits.length - 1; i >= 0; i--) {
      var r = hits[i];
      if (px >= r.x && px < r.x + r.w && py >= r.y && py < r.y + r.h) return r;
    }
    return null;
  }

  // A push button: title-style words, ink on the control grey, accent when on.
  function button(label, x, y, w, h, on, handler, enabled) {
    var off = enabled === false;
    round(x, y, w, h, 3, off ? C.raised : on ? C.accent : C.control);
    text(label, x + 4, y, w - 8, h, off ? C.dim : C.ink, 10, 1, true);
    if (!off) hit(x, y, w, h, { click: handler });
  }

  // A value chosen from a list: click the left third for the one before, the
  // rest for the one after, or drag up and down through them.
  function stepper(label, names, index, x, y, w, onChange) {
    text(label, x, y, w, 12, C.label, 9, 0);
    var by = y + 13, bh = 18;
    round(x, by, w, bh, 3, C.sunken);
    frame(x, by, w, bh, C.rule);
    text('‹', x + 3, by, 8, bh, C.dim, 11, 1);
    text('›', x + w - 11, by, 8, bh, C.dim, 11, 1);
    text(names[index - 1] === undefined ? '' : names[index - 1], x + 12, by, w - 24, bh, C.text, 10, 1);
    var n = names.length;
    var last = index;
    function to(i) { i = Math.max(1, Math.min(n, i)); if (i !== last) { last = i; onChange(i); } }
    hit(x, by, w, bh, {
      click: function (px) { to(px < x + w / 3 ? index - 1 : index + 1); },
      drag: function (dy) { to(index - Math.round(dy / 8)); }
    });
  }

  // The same, in one line for a small panel (a MIDI Tool's): the label at
  // the left, the value at the right, the arrows at the ends.
  function row(label, names, index, x, y, w, h, onChange) {
    round(x, y, w, h, 3, C.sunken);
    frame(x, y, w, h, C.rule);
    text('‹', x + 1, y, 8, h, C.dim, 10, 1);
    text('›', x + w - 9, y, 8, h, C.dim, 10, 1);
    var lw = Math.round((w - 18) * 0.42);
    text(label, x + 10, y, lw - 2, h, C.label, 9, 0);
    text(names[index - 1] === undefined ? '' : names[index - 1], x + 10 + lw, y, w - 20 - lw, h, C.text, 9, 2);
    var n = names.length, last = index;
    function to(i) { i = Math.max(1, Math.min(n, i)); if (i !== last) { last = i; onChange(i); } }
    hit(x, y, w, h, {
      click: function (px) { to(px < x + w / 3 ? index - 1 : index + 1); },
      drag: function (dy) { to(index - Math.round(dy / 8)); }
    });
  }

  function toggle(label, on, x, y, w, h, onChange) {
    round(x, y, w, h, 3, on ? C.accent : C.control);
    text(label, x + 4, y, w - 8, h, C.ink, 10, 1, true);
    hit(x, y, w, h, { click: function () { onChange(!on); } });
  }

  // Mouse, as [v8ui] delivers it: onclick then ondrag until the button is up.
  function click(px, py) {
    var r = find(px, py);
    drag = null;
    if (!r) return false;
    if (r.fn.drag) drag = { r: r, y0: py, moved: false };
    else if (r.fn.click) r.fn.click(px, py);
    return true;
  }
  function dragTo(px, py, down) {
    if (!drag) return;
    var dy = drag.y0 - py;
    if (down) {
      if (Math.abs(dy) >= 4) drag.moved = true;
      if (drag.moved) drag.r.fn.drag(dy);
    } else {
      if (!drag.moved && drag.r.fn.click) drag.r.fn.click(px, py);
      drag = null;
    }
  }

  return { C: C, begin: begin, rect: rect, round: round, frame: frame, text: text, fit: fit, measure: measure,
           hit: hit, button: button, stepper: stepper, row: row, toggle: toggle, click: click, dragTo: dragTo, find: find };
})();


/* ---- kit/live.js ---- */
/* The Live set, as the family's devices need it: the song's tempo, meter and
 * scale, the notes of the clip being edited, somewhere to put new notes, and
 * a way to hear notes before they are used.
 *
 * Everything goes through the Live Object Model (LiveAPI). Times are beats,
 * which in Live are quarter notes - the unit every family engine already
 * speaks - so nothing is converted but the field names.
 */
var Live = (function () {
  'use strict';
  function api(path) { return new LiveAPI(null, path); }
  function one(a, prop) { var v = a.get(prop); return Array.isArray(v) ? v[0] : v; }
  function exists(a) { return a && Number(a.id) !== 0; }
  function json(v) {
    if (typeof v === 'string') return JSON.parse(v);
    if (Array.isArray(v) && typeof v[0] === 'string' && v.length === 1) return JSON.parse(v[0]);
    return v;
  }

  // Live 12's scale names, as ScaleView numbers its scales (1-16). A scale
  // ScaleView has no name for is left out: the device keeps its own key.
  var SCALE = {
    'Major': 1, 'Minor': 2, 'Harmonic Minor': 3, 'Dorian': 5, 'Phrygian': 6, 'Lydian': 7,
    'Mixolydian': 8, 'Major Pentatonic': 10, 'Minor Pentatonic': 11, 'Minor Blues': 13,
    'Whole Tone': 14, 'Whole-half Dim.': 15, 'Half-whole Dim.': 16
  };
  // ScaleView's eighteen roots, and the spelling a key on each pitch class
  // takes: flats for the major side, sharps where a minor key has them.
  var ROOTS = ['C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B', 'Cb'];
  var MAJOR_SIDE = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
  var MINOR_SIDE = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'];
  var MINORISH = { 2: 1, 3: 1, 5: 1, 6: 1, 11: 1, 13: 1 };
  var SCALE_NAMES = ['Major', 'Minor (Natural)', 'Harmonic Minor', 'Ionian', 'Dorian', 'Phrygian', 'Lydian',
                     'Mixolydian', 'Aeolian', 'Major Pentatonic', 'Minor Pentatonic', 'Major Blues', 'Minor Blues',
                     'Whole Tone', 'Diminished Whole-Half', 'Diminished Half-Whole'];

  // Live's scale (a root pitch class and a name) as the family's key, or
  // null for a scale ScaleView does not have.
  function keyOf(pc, name) {
    var sc = SCALE[String(name)];
    if (!sc) return null;
    return { root: ROOTS.indexOf((MINORISH[sc] ? MINOR_SIDE : MAJOR_SIDE)[((+pc % 12) + 12) % 12]) + 1, scale: sc };
  }

  function song() {
    var s = api('live_set');
    var out = { tempo: +one(s, 'tempo') || 120, num: +one(s, 'signature_numerator') || 4,
                den: +one(s, 'signature_denominator') || 4, playing: !!+one(s, 'is_playing'),
                position: +one(s, 'current_song_time') || 0, key: null };
    var mode = s.get('scale_mode');
    if (mode !== undefined && mode !== null) {
      var name = String(one(s, 'scale_name')), pc = +one(s, 'root_note');
      out.liveScale = { on: !!+(Array.isArray(mode) ? mode[0] : mode), name: name, root: pc };
      out.key = keyOf(pc, name);
    }
    return out;
  }

  function detailClip() {
    var c = api('live_set view detail_clip');
    if (!exists(c) || !+one(c, 'is_midi_clip')) return null;
    return c;
  }

  // The clip being edited: its selected notes if any are selected, else every
  // note in its loop. Starts are from the start of what was taken.
  function clipNotes() {
    var c = detailClip();
    if (!c) return null;
    var from = +one(c, 'loop_start') || 0, to = +one(c, 'loop_end') || 0;
    var raw = null, selected = false;
    try { raw = json(c.call('get_selected_notes_extended')); selected = raw && raw.notes && raw.notes.length > 0; } catch (e) { raw = null; }
    if (!selected) raw = json(c.call('get_notes_extended', 0, 128, from, Math.max(0, to - from)));
    var notes = ((raw && raw.notes) || []).filter(function (n) { return !n.mute; }).map(function (n) {
      return { start: n.start_time, len: n.duration, pitch: n.pitch, vel: Math.round(n.velocity) };
    });
    var first = selected && notes.length ? Math.min.apply(null, notes.map(function (n) { return n.start; })) : from;
    var beats = to - from;
    if (selected) {
      var bar = 4, end = 0;
      notes.forEach(function (n) { end = Math.max(end, n.start + n.len); });
      first = Math.floor(first / bar) * bar;
      beats = Math.ceil((end - first) / bar) * bar;
    }
    notes.forEach(function (n) { n.start -= first; });
    notes.sort(function (a, b) { return a.start - b.start || a.pitch - b.pitch; });
    return { notes: notes, beats: beats, name: String(one(c, 'name') || ''), selected: selected, drums: drumTrack() };
  }

  // A track whose instrument is a Drum Rack plays drums: its note numbers name
  // drums, not pitches, and the engines treat them that way.
  function drumTrack() {
    try {
      var track = api('this_device canonical_parent'), n = track.getcount('devices');
      for (var i = 0; i < n; i++) if (+one(api(track.unquotedpath + ' devices ' + i), 'can_have_drum_pads')) return true;
    } catch (e) { /* not known: not drums */ }
    return false;
  }

  function liveNotes(notes) {
    return { notes: notes.map(function (n) {
      return { pitch: Math.max(0, Math.min(127, Math.round(n.pitch))), start_time: Math.max(0, n.start),
               duration: Math.max(1 / 128, n.len), velocity: Math.max(1, Math.min(127, Math.round(n.vel || 100))), mute: 0 };
    }) };
  }

  function undoable(fn) {
    var s = api('live_set');
    try { s.call('begin_undo_step'); } catch (e) { /* Live before 11.1 */ }
    try { return fn(); } finally { try { s.call('end_undo_step'); } catch (e2) { /* as above */ } }
  }

  function show(clip) {
    try { api('live_set view').set('detail_clip', 'id', Number(clip.id)); } catch (e) { /* the clip is made either way */ }
  }

  function selectedScene() {
    var scene = api('live_set view selected_scene'), n = api('live_set').getcount('scenes');
    for (var i = 0; i < n; i++) if (Number(api('live_set scenes ' + i).id) === Number(scene.id)) return i;
    return 0;
  }
  function thisTrack() {
    var track = api('this_device canonical_parent');
    if (!exists(track) || !+one(track, 'has_midi_input')) return null;
    return track;
  }
  // Where this device's track is in the set, for putting new tracks beside it.
  function trackIndex(track) {
    var n = api('live_set').getcount('tracks');
    for (var i = 0; i < n; i++) if (Number(api('live_set tracks ' + i).id) === Number(track.id)) return i;
    return n - 1;
  }
  function clipInSlot(slot, notes, beats, name) {
    slot.call('create_clip', Math.max(1, beats));
    var clip = api(slot.unquotedpath + ' clip');
    if (name) clip.set('name', name);
    clip.call('add_new_notes', liveNotes(notes));
    return clip;
  }
  function freeSlot(track, from) {
    var n = track.getcount('clip_slots');
    for (var k = 0; k < n; k++) {
      var at = (from + k) % n, slot = api(track.unquotedpath + ' clip_slots ' + at);
      if (!+one(slot, 'has_clip')) return { slot: slot, at: at };
    }
    return null;
  }
  function arrangementClipOn(track, notes, beats, name, at) {
    var before = track.getcount('arrangement_clips');
    try { track.call('create_midi_clip', at, Math.max(1, beats)); } catch (e) { /* checked below */ }
    var count = track.getcount('arrangement_clips');
    if (!(count > before)) return false;
    for (var i = 0; i < count; i++) {
      var clip = api(track.unquotedpath + ' arrangement_clips ' + i);
      if (Math.abs((+one(clip, 'start_time') || 0) - at) < 1e-6) {
        if (name) clip.set('name', name);
        clip.call('add_new_notes', liveNotes(notes));
        return true;
      }
    }
    return false;
  }

  // New notes, as a new clip in the first free slot on this device's track,
  // from the selected scene down. `more` are further parts ({name, notes}),
  // each on a new MIDI track after this one, in the same scene. Returns what
  // happened, for the status line.
  function newClip(notes, beats, name, more) {
    var track = thisTrack();
    if (!track) return { ok: false, message: 'This device needs to be on a MIDI track.' };
    var free = freeSlot(track, selectedScene());
    if (!free) return { ok: false, message: 'Every clip slot on this track is full. Add a scene, then try again.' };
    return undoable(function () {
      var clip = clipInSlot(free.slot, notes, beats, name);
      var made = newTracks(track, more, function (t) {
        clipInSlot(api(t.unquotedpath + ' clip_slots ' + free.at), this.notes, beats, this.name);
      });
      show(clip);
      return { ok: true, message: 'Added a clip in scene ' + (free.at + 1) + (made ? ', and ' + made + ' on new tracks beside it.' : '.') };
    });
  }

  // New notes on a new MIDI track beside this one, in the selected scene:
  // a suggestion goes with the music it was made for, not over it.
  function newTrackClip(notes, beats, name, more) {
    var track = thisTrack();
    if (!track) return { ok: false, message: 'This device needs to be on a MIDI track.' };
    var scene = selectedScene();
    return undoable(function () {
      var parts = [{ name: name, notes: notes }].concat(more || []);
      newTracks(track, parts, function (t) { show(clipInSlot(api(t.unquotedpath + ' clip_slots ' + scene), this.notes, beats, this.name)); });
      return { ok: true, message: parts.length === 1 ? 'Added a track beside this one, with the clip in scene ' + (scene + 1) + '.'
                                                     : 'Added ' + parts.length + ' tracks beside this one, with the clips in scene ' + (scene + 1) + '.' };
    });
  }

  // Each further part on a new MIDI track, in order, after this one.
  function newTracks(track, more, put) {
    if (!more || !more.length) return '';
    var at = trackIndex(track), song = api('live_set');
    more.forEach(function (part, k) {
      song.call('create_midi_track', at + 1 + k);
      var t = api('live_set tracks ' + (at + 1 + k));
      t.set('name', part.name);
      put.call(part, t);
    });
    return more.length === 1 ? 'one more part' : more.length + ' more parts';
  }

  // New notes in place of the notes of the clip being edited, from its loop start.
  function replaceInClip(notes, beats) {
    var c = detailClip();
    if (!c) return { ok: false, message: 'No MIDI clip is open. Open one in Detail View, then try again.' };
    var from = +one(c, 'loop_start') || 0;
    return undoable(function () {
      var span = Math.max(beats, (+one(c, 'loop_end') || 0) - from);
      c.call('remove_notes_extended', 0, 128, from, span);
      c.call('add_new_notes', liveNotes(notes.map(function (n) {
        return { start: n.start + from, len: n.len, pitch: n.pitch, vel: n.vel };
      })));
      if ((+one(c, 'loop_end') || 0) < from + beats) c.set('loop_end', from + beats);
      return { ok: true, message: 'Replaced the notes in “' + (String(one(c, 'name') || '') || 'the clip') + '”.' };
    });
  }

  // New notes in the Arrangement at the insert marker, on this device's track
  // (Track.create_midi_clip, Live 12.2 and later); further parts as above.
  function arrangementClip(notes, beats, name, more) {
    var track = thisTrack();
    if (!track) return { ok: false, message: 'This device needs to be on a MIDI track.' };
    var at = +one(api('live_set'), 'current_song_time') || 0;
    return undoable(function () {
      if (!arrangementClipOn(track, notes, beats, name, at)) {
        return { ok: false, message: 'This version of Live can\u2019t add Arrangement clips from a device. Choose New Clip instead.' };
      }
      var made = newTracks(track, more, function (t) { arrangementClipOn(t, this.notes, beats, this.name, at); });
      return { ok: true, message: 'Added a clip to the Arrangement at beat ' + (Math.round(at * 100) / 100 + 1) +
               (made ? ', and ' + made + ' on new tracks beside it.' : '.') };
    });
  }

  // ------------------------------------------------------------ player ---
  // Notes heard through this device's MIDI out: the instrument after it on
  // the track plays them. A Task ticks every few milliseconds and sends what
  // is due; nothing waits on the transport.
  function Player(send) {
    this.send = send; this.events = []; this.pos = 0; this.t0 = 0; this.task = null; this.sounding = {};
    this.onEnd = null;
  }
  Player.prototype.play = function (notes, tempo, onEnd) {
    this.stop();
    var ms = 60000 / (tempo || 120), ev = [];
    notes.forEach(function (n) {
      ev.push({ t: n.start * ms, on: true, pitch: n.pitch, vel: n.vel || 100 });
      ev.push({ t: (n.start + n.len) * ms - 1, on: false, pitch: n.pitch });
    });
    ev.sort(function (a, b) { return a.t - b.t || (a.on === b.on ? 0 : a.on ? 1 : -1); });
    this.events = ev; this.pos = 0; this.t0 = Date.now(); this.onEnd = onEnd || null;
    var self = this;
    this.task = new Task(function () { self.tick(); }, this);
    this.task.interval = 4;
    this.task.repeat();
    this.tick();
  };
  Player.prototype.tick = function () {
    var now = Date.now() - this.t0;
    while (this.pos < this.events.length && this.events[this.pos].t <= now) {
      var e = this.events[this.pos++];
      if (e.on) { this.sounding[e.pitch] = (this.sounding[e.pitch] || 0) + 1; this.send([0x90, e.pitch, Math.max(1, Math.min(127, Math.round(e.vel)))]); }
      else if (this.sounding[e.pitch]) { this.sounding[e.pitch]--; this.send([0x80, e.pitch, 0]); }
    }
    if (this.pos >= this.events.length) {
      var end = this.onEnd;
      this.stop();
      if (end) end();
    }
  };
  Player.prototype.playing = function () { return !!this.task; };
  Player.prototype.stop = function () {
    if (this.task) { this.task.cancel(); this.task.freepeer && this.task.freepeer(); this.task = null; }
    var self = this;
    Object.keys(this.sounding).forEach(function (p) {
      for (var i = 0; i < self.sounding[p]; i++) self.send([0x80, +p, 0]);
    });
    this.sounding = {};
    this.onEnd = null;
  };

  return { song: song, clipNotes: clipNotes, newClip: newClip, newTrackClip: newTrackClip, replaceInClip: replaceInClip,
           arrangementClip: arrangementClip, drumTrack: drumTrack, Player: Player, ROOTS: ROOTS, SCALE_NAMES: SCALE_NAMES,
           keyOf: keyOf };
})();


/* ---- battlepass.js ---- */
/* DAW Battle Pass as a Max for Live device.
 *
 * The game is reascripts/bp_game.lua, bp_loot.lua and bp_theory.lua,
 * unchanged, on Middaw's Lua 5.4 runtime, driven through Middaw's host the
 * way Middaw's own Battle Pass window drives it (passStart, passCall,
 * passGet, passNotices, passSave). What bp_watch.lua does in REAPER is done
 * here with the Live Object Model: every second the game is told whether
 * anyone is there (something in the set changed, or Live is playing or
 * recording), and every two seconds the set is compared with what was seen
 * last - new tracks, clips, devices, notes in the clip being edited, locators
 * and recorded clips - and each becomes the game's event.
 *
 * The game is the musician's, not the set's: it is saved in a file beside
 * the device (DAW Battle Pass save.txt) as well as with the set, and the
 * newer of the two is used.
 *
 * Expects, before it: UI, Live, MiddawHost, DEVICE = { files }.
 * Outlets: 0 MIDI bytes (MIDI passes through), 1 the state to [pattr].
 */
inlets = 1;
outlets = 2;
mgraphics.init();
mgraphics.relative_coords = 0;
mgraphics.autofill = 0;

var H = MiddawHost;
H.init(function (p) { return DEVICE.files[p] === undefined ? null : DEVICE.files[p]; }, function (s) { post(s + '\n'); });
function call(method, args) {
  var r = JSON.parse(H.call(method, args === undefined ? '' : JSON.stringify(args)));
  if (!r.ok) throw new Error(r.error);
  return r.value;
}
function game(fn) { return call('passCall', { fn: fn, args: Array.prototype.slice.call(arguments, 1) }); }
function get(path) { return call('passGet', { path: path }); }
function epoch() { return Math.floor(Date.now() / 1000); }

var P = {
  started: false, t0: Date.now(), scope: 'daily', status: '', lastChange: 0, seen: null, saved: '', fileSaved: '',
  tier: 0, frac: 0, level: 1, xp: 0, need: 200, coins: 0, quests: [], crates: [], rarity: [], tokens: {}, checkin: false
};
function clock() { return (Date.now() - P.t0) / 1000; }
function say(s) { P.status = s || ''; }

// --------------------------------------------------------------- saving --
function savePath() {
  try {
    var fp = typeof patcher !== 'undefined' && patcher.filepath ? String(patcher.filepath) : '';
    if (!fp) return null;
    return fp.replace(/[^\/:]*$/, '') + 'DAW Battle Pass save.txt';
  } catch (e) { return null; }
}
function readFileText(path) {
  try {
    var f = new File(path, 'read');
    if (!f.isopen) return null;
    var out = '';
    while (f.position < f.eof) out += f.readstring(Math.min(16384, f.eof - f.position));
    f.close();
    return out || null;
  } catch (e) { return null; }
}
function writeFileText(path, text) {
  try {
    var f = new File(path, 'write', 'TEXT');
    if (!f.isopen) return false;
    f.eof = 0;
    for (var i = 0; i < text.length; i += 16384) f.writestring(text.slice(i, i + 16384));
    f.close();
    return true;
  } catch (e) { return false; }
}
// The saved game with the most time in it: the file's, or the set's.
function newer(a, b) {
  function active(s) { var m = /active\s*=\s*([\d.]+)/.exec(s || ''); return m ? +m[1] : -1; }
  return active(a) >= active(b) ? a : b;
}
function save(force) {
  if (!P.started) return;
  var s = call('passSave');
  if (s !== P.saved || force) { P.saved = s; outlet(1, 'set', s); }
  var path = savePath();
  if (path && s !== P.fileSaved && writeFileText(path, s)) P.fileSaved = s;
}

// -------------------------------------------------------------- the game --
function start(savedFromSet) {
  if (P.started) return;
  var path = savePath(), fromFile = path ? readFileText(path) : null;
  var saved = fromFile && savedFromSet ? newer(fromFile, savedFromSet) : (fromFile || savedFromSet || null);
  call('passStart', { epoch: epoch(), clock: clock(), saved: saved });
  P.started = true;
  P.seen = scan();
  read();
}
function read() {
  P.tier = get('pass.tier') || 0;
  P.frac = Math.min(1, (get('pass.secs') || 0) / (call('passConst', { name: 'TIER_SECONDS' }) || 900));
  P.level = Math.max(1, get('level') || 1);
  P.xp = Math.floor(get('xp') || 0);
  P.need = game('levelNeed', P.level);
  P.coins = Math.floor(get('coins') || 0);
  P.quests = get(P.scope + '.quests') || [];
  if (!Array.isArray(P.quests)) P.quests = Object.keys(P.quests).map(function (k) { return P.quests[k]; });
  var c = get('inv.crates') || [];
  P.crates = Array.isArray(c) ? c : Object.keys(c).map(function (k) { return c[k]; });
  P.tokens = get('inv.tokens') || {};
  P.checkin = !!game('checkinAvailable', '$state', epoch());
  if (!P.rarity.length) P.rarity = (call('passConst', { name: 'RARITY', module: 'loot' }) || []).map(function (r) { return r.name; });
}
function drain() {
  (call('passNotices') || []).forEach(function (n) {
    if (n.kind === 'tier') say('Battle Pass: tier ' + get('pass.tier') + ' unlocked.');
    else if (n.kind === 'level') say('Level ' + get('level') + ' — a crate is waiting.');
    else if (n.kind === 'quest') say('Quest done: ' + (n.text || n.name || '') + '.');
    else if (n.kind === 'claim') say('Claimed: ' + (n.coins || 0) + ' coins, ' + (n.xp || 0) + ' XP.');
    else if (n.kind === 'crate') say('Opened a crate: ' + (n.drops ? (Array.isArray(n.drops) ? n.drops.length : Object.keys(n.drops).length) : 0) + ' things.');
    else if (n.kind === 'season') say('A new season of the Battle Pass has started.');
    else if (n.kind === 'toast' && n.text) say(n.text + (n.sub ? ' — ' + n.sub : ''));
  });
}

// ------------------------------------------------------------ the watch --
// The set as counts and names, cheap enough to read every two seconds.
function api(path) { return new LiveAPI(null, path); }
function one(a, p) { var v = a.get(p); return Array.isArray(v) ? v[0] : v; }
function scan() {
  var s = { tracks: 0, clips: 0, devices: {}, cues: 0, notes: 0, recorded: 0 };
  try {
    var song = api('live_set'), n = song.getcount('tracks');
    s.tracks = n;
    s.cues = song.getcount('cue_points');
    for (var t = 0; t < n; t++) {
      var tp = 'live_set tracks ' + t, track = api(tp);
      var slots = track.getcount('clip_slots');
      for (var k = 0; k < slots; k++) if (+one(api(tp + ' clip_slots ' + k), 'has_clip')) s.clips++;
      s.clips += track.getcount('arrangement_clips');
      var nd = track.getcount('devices');
      for (var d = 0; d < nd; d++) {
        var dev = api(tp + ' devices ' + d);
        s.devices[dev.id] = { name: String(one(dev, 'name') || ''), instrument: +one(dev, 'type') === 1 };
      }
    }
    var c = Live.clipNotes();
    s.notes = c ? c.notes.length : 0;
    s.clip = c ? c.name : null;
  } catch (e) { /* not in Live */ }
  return s;
}
function watch() {
  var now = scan(), was = P.seen, changed = false;
  P.seen = now;
  if (!was) return;
  function ev(kind, n, info) {
    if (n <= 0) return;
    changed = true;
    game('event', '$state', '$session', kind, n, info || {});
  }
  ev('track', now.tracks - was.tracks);
  ev('item', now.clips - was.clips);
  ev('marker', now.cues - was.cues);
  if (now.clip === was.clip) ev('notes', now.notes - was.notes);
  Object.keys(now.devices).forEach(function (id) {
    if (was.devices[id]) return;
    var d = now.devices[id];
    ev('fx', 1, { name: d.name, norm: d.name.toLowerCase(), instrument: d.instrument });
  });
  var song = Live.song();
  if (song.playing && isRecording() && now.clips > was.clips) ev('take', now.clips - was.clips);
  if (changed) { game('event', '$state', '$session', 'edit', 1, {}); P.lastChange = Date.now(); }
}
function isRecording() {
  try { var s = api('live_set'); return !!+one(s, 'record_mode') || !!+one(s, 'session_record'); } catch (e) { return false; }
}

var ticks = 0;
function tick() {
  if (!P.started) return;
  var song = Live.song(), rec = isRecording();
  var signals = { input: Date.now() - P.lastChange < 90000 || song.playing, playing: song.playing, recording: rec && song.playing, project: 'Live Set' };
  game('tick', '$state', '$session', clock(), epoch(), signals);
  game('refresh', '$state', '$session', epoch(), {});
  game('checkAchievements', '$state', '$session');
  if (ticks % 2 === 0) watch();
  if (ticks % 30 === 0) save();
  ticks++;
  drain();
  read();
  mgraphics.redraw();
}

// ------------------------------------------------------------- actions --
function act(fn) {
  var args = Array.prototype.slice.call(arguments, 1);
  try { game.apply(null, [fn].concat(args)); } catch (e) { say(String(e.message || e)); }
  drain(); read(); save(); mgraphics.redraw();
}

// ------------------------------------------------------------ messages --
var timer = null, pendingSet = null;
function bang() {
  start(pendingSet);
  if (!timer) { timer = new Task(tick, this); timer.interval = 1000; timer.repeat(); }
  mgraphics.redraw();
}
function restore(text) {
  var s = String(text);
  if (!P.started) { pendingSet = s; return; }
}
function msg_int(b) { outlet(0, b); }

// --------------------------------------------------------------- paint --
function bar(x, y, w, h, frac, col) {
  UI.round(x, y, w, h, 3, UI.C.sunken);
  if (frac > 0) UI.round(x, y, Math.max(4, w * Math.min(1, frac)), h, 3, col || UI.C.accent);
}
function paint() {
  var sz = (typeof box !== 'undefined' && box.rect) ? [box.rect[2] - box.rect[0], box.rect[3] - box.rect[1]] : [900, 169];
  var W = sz[0], Ht = sz[1];
  UI.begin(mgraphics);
  UI.rect(0, 0, W, Ht, UI.C.ground);
  UI.text(P.status || 'DAW Battle Pass — make music to unlock tiers', 6, 1, W - 12, 16, UI.C.dim, 10, 0);
  if (!P.started) return;
  // the pass, the level, the coins
  UI.text('Tier ' + P.tier, 6, 20, 120, 14, UI.C.text, 11, 0, true);
  UI.text(Math.floor((1 - P.frac) * 15) + ' min to the next', 100, 20, 106, 14, UI.C.dim, 9, 2);
  bar(6, 36, 200, 8, P.frac);
  UI.text('Level ' + P.level, 6, 50, 120, 14, UI.C.text, 11, 0, true);
  UI.text(P.xp + ' / ' + P.need + ' XP', 100, 50, 106, 14, UI.C.dim, 9, 2);
  bar(6, 66, 200, 8, P.xp / Math.max(1, P.need), UI.C.control);
  UI.text(P.coins + ' coins · ' + (P.tokens.reroll || 0) + ' rerolls', 6, 80, 200, 14, UI.C.label, 10, 0);
  UI.button(P.checkin ? 'Check In' : 'Checked In Today', 6, 100, 200, 20, false, function () { act('checkin', '$state', '$session', epoch()); }, P.checkin);
  UI.button('Use a Boost (' + (P.tokens.boost || 0) + ')', 6, 126, 200, 20, false, function () { act('useBoost', '$state', '$session'); }, (P.tokens.boost || 0) > 0);

  // the quests
  var qx = 216, qw = W - qx - 252;
  UI.button('Daily', qx, 20, 70, 18, P.scope === 'daily', function () { P.scope = 'daily'; read(); mgraphics.redraw(); });
  UI.button('Weekly', qx + 74, 20, 70, 18, P.scope === 'weekly', function () { P.scope = 'weekly'; read(); mgraphics.redraw(); });
  P.quests.slice(0, 4).forEach(function (q, i) {
    var y = 44 + i * 30;
    UI.rect(qx, y, qw, 26, UI.C.raised);
    if (q.claimed) UI.rect(qx, y, 3, 26, UI.C.accent);
    UI.text(q.text || '', qx + 8, y, qw - 170, 26, q.claimed ? UI.C.dim : UI.C.text, 10, 0);
    var timed = q.kind === 'minutes' || q.kind === 'session';   // counted in seconds, read in minutes
    var have = Math.min(q.progress || 0, q.target), of = q.target;
    UI.text(timed ? Math.floor(have / 60) + ' / ' + Math.round(of / 60) + ' min' : Math.floor(have) + ' / ' + of, qx + qw - 160, y, 70, 26, UI.C.dim, 9, 2);
    var bx = qx + qw - 82;
    if (q.claimed) UI.text('Claimed', bx, y + 4, 76, 18, UI.C.dim, 10, 1);
    else if (q.done) UI.button('Claim', bx, y + 4, 76, 18, true, function () { act('claimQuest', '$state', '$session', P.scope, i + 1); });
    else UI.button('Reroll', bx, y + 4, 76, 18, false, function () { act('reroll', '$state', '$session', P.scope, i + 1); }, !!game('canReroll', '$state', P.scope));
  });

  // the crates
  var cx = W - 244;
  UI.text('Crates', cx, 20, 230, 16, UI.C.text, 11, 0, true);
  var row = 0;
  P.crates.forEach(function (n, r) {
    if (!(n > 0) || row >= 4) return;
    var y = 40 + row * 24; row++;
    UI.text((P.rarity[r] || 'Crate') + ' × ' + n, cx, y, 150, 20, UI.C.label, 10, 0);
    UI.button('Open', cx + 160, y, 70, 20, false, function () { act('openCrate', '$state', '$session', r + 1); });
  });
  if (!row) UI.text('None yet. Each level brings one.', cx, 40, 236, 20, UI.C.dim, 10, 0);
}
function onclick(x, y) { if (UI.click(x, y)) mgraphics.redraw(); }
function ondrag(x, y, but) { UI.dragTo(x, y, !!but); }

