--[[ The rules: the clock and idling, tiers, levels, quests, check-ins, the
     shop, crates, gear, achievements, seasons and saving - a week of play in
     a second, because the time is always passed in.

       lua5.4 tests/test_game.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local C = dofile(HERE .. "/check.lua")
local ok, eq = C.ok, C.eq
local T = dofile(C.SCRIPTS .. "bp_theory.lua")
local L = dofile(C.SCRIPTS .. "bp_loot.lua").init(T)
local G = dofile(C.SCRIPTS .. "bp_game.lua").init(L)

-- Thursday 8 October 2026, 8pm.
local START = os.time({ year = 2026, month = 10, day = 8, hour = 20, min = 0, sec = 0 })

local function fresh(epoch)
  epoch = epoch or START
  local st = G.clampState(G.newState(epoch), epoch)
  local ss = G.newSession(st, 1000, epoch)
  ss.rnd = L.random(42)
  return st, ss, { tp = 1000, epoch = epoch }
end

-- Runs the clock for `secs`, one tick a second. input: how often something
-- happens (every n seconds), or false for nothing at all.
local function run(st, ss, clock, secs, input, extra)
  for i = 1, secs do
    clock.tp, clock.epoch = clock.tp + 1, clock.epoch + 1
    local sig = { input = input and (i % input == 0) or false, playing = extra and extra.playing,
                  recording = extra and extra.recording, project = extra and extra.project or "song" }
    G.tick(st, ss, clock.tp, clock.epoch, sig)
  end
end

local function kinds(ss, kind)
  local n = 0
  for _, x in ipairs(ss.notices) do if x.kind == kind then n = n + 1 end end
  return n
end

------------------------------------------------------------------------------
-- Dates
------------------------------------------------------------------------------

eq(G.dayKey(START), "2026-10-08", "8pm is today")
eq(G.dayKey(os.time({ year = 2026, month = 10, day = 9, hour = 2 })), "2026-10-08", "2am still counts as the day before")
eq(G.dayKey(os.time({ year = 2026, month = 10, day = 9, hour = 5 })), "2026-10-09", "5am is the new day")
eq(G.weekKey(START), "2026-10-05", "a week is named for its Monday")
eq(G.weekKey(os.time({ year = 2026, month = 10, day = 11, hour = 23 })), "2026-10-05", "Sunday night is the same week")
eq(G.weekKey(os.time({ year = 2026, month = 10, day = 12, hour = 9 })), "2026-10-12", "Monday morning is a new week")
eq(G.daysBetween("2026-10-08", "2026-10-09"), 1, "one day apart")
eq(G.daysBetween("2026-12-31", "2027-01-02"), 2, "across the new year")
eq(G.seasonOf(START), 10, "October 2026 is season 10")
ok(G.secsToNextDay(START) == 8 * 3600, "the day turns at 4am")

------------------------------------------------------------------------------
-- The clock: tiers every fifteen active minutes, a pause when idle
------------------------------------------------------------------------------

do
  local st, ss, clock = fresh()
  G.refresh(st, ss, clock.epoch, {})
  run(st, ss, clock, 15 * 60 + 1, 20)
  eq(st.pass.tier, 1, "fifteen active minutes unlock a tier")
  eq(kinds(ss, "tier"), 1, "and say so")
  run(st, ss, clock, 45 * 60, 20)
  eq(st.pass.tier, 4, "an hour is four tiers")
  local last
  for _, n in ipairs(ss.notices) do if n.kind == "tier" then last = n end end
  eq(last.tierKind, "big", "and the fourth is the big one")
  ok(#last.drops >= 3, "a big tier gives at least three things")
  ok(st.stats.active >= 3599, "an hour of active time is counted")
  ok(st.level > 1, "an hour's minutes level you up")
end

do
  local st, ss, clock = fresh()
  run(st, ss, clock, 60, 10)
  local before = st.stats.active
  run(st, ss, clock, 30 * 60, false)
  local counted = st.stats.active - before
  ok(counted <= G.IDLE_SECONDS + 1, string.format("with nothing happening the clock stops after the idle time (%d s counted)", counted))
  ok(ss.idle, "and you are idle")
  eq(kinds(ss, "idle"), 1, "said once")
  run(st, ss, clock, 5, 1)
  ok(not ss.idle, "anything happening brings you back")
  eq(kinds(ss, "active"), 1, "and says welcome back")
end

do
  local st, ss, clock = fresh()
  run(st, ss, clock, 60, 10)
  run(st, ss, clock, 400, false, { playing = true })
  ok(not ss.idle, "playback lets you listen for longer than the idle time")
  run(st, ss, clock, 200, false, { playing = true })
  ok(ss.idle, "but not for ever")
  run(st, ss, clock, 1200, false, { recording = true })
  ok(not ss.idle, "recording always counts")
end

do
  local st, ss, clock = fresh()
  st.settings.idle = 600
  run(st, ss, clock, 60, 10)
  run(st, ss, clock, 500, false)
  ok(not ss.idle, "the idle time is a setting")
  st.gear.equipped.charm = { slot = "charm", rarity = 6, affixes = {}, implicit = { id = "grace", value = 0 }, power = "deep_focus" }
  eq(G.idleLimit(st, false), 600 + 180, "Deep Focus adds three minutes")
end

------------------------------------------------------------------------------
-- XP and levels
------------------------------------------------------------------------------

do
  local st, ss = fresh()
  eq(G.levelNeed(1), 200, "level 1 needs 200 XP")
  ok(G.levelNeed(10) > G.levelNeed(9), "each level needs more")
  G.addXp(st, ss, 200, "quest")
  eq(st.level, 2, "200 XP is level 2")
  eq(kinds(ss, "level"), 1, "level up is announced")
  local crates = 0
  for r = 1, 7 do crates = crates + st.inv.crates[r] end
  eq(crates, 1, "and gives a crate")
  st.level = 4
  st.xp = 0
  G.addXp(st, ss, G.levelNeed(4), "quest")
  eq(st.inv.crates[4] >= 1, true, "level 5 gives a Rare crate")
  st.boost = 100
  local got = G.addXp(st, ss, 10, "quest")
  eq(got, 20, "a boost doubles XP")
end

do
  local st, ss, clock = fresh()
  ss.now = clock.tp
  local total = 0
  for _ = 1, 500 do total = total + G.addXp(st, ss, 1, "edit") end
  eq(total, G.ACTION_XP_CAP, "editing XP is capped per minute")
  ss.now = clock.tp + 61
  ok(G.addXp(st, ss, 1, "edit") > 0, "and the cap resets a minute later")
  ok(G.addXp(st, ss, 50, "quest") == 50, "quests are not capped")
end

------------------------------------------------------------------------------
-- Events from REAPER
------------------------------------------------------------------------------

do
  local st, ss = fresh()
  G.event(st, ss, "track", 2)
  eq(st.stats.tracks, 2, "tracks are counted")
  G.event(st, ss, "fx", 1, { name = "VST3i: Serum (Xfer Records)" })
  eq(st.plugins.serum, 1, "plugins are counted by their plain name")
  eq(kinds(ss, "toast"), 1, "a first-time plugin is a discovery")
  G.event(st, ss, "fx", 1, { name = "VST: Serum (Xfer Records) (x64)" })
  eq(st.plugins.serum, 2, "the same plugin in another format is the same plugin")
  eq(kinds(ss, "toast"), 1, "and is not discovered twice")
end

local norm, display, inst = G.normFx("VST3i: Serum (Xfer Records)")
eq(norm, "serum", "normFx strips the format and the maker")
eq(display, "Serum", "and keeps the name as written")
eq(inst, true, "and knows an instrument")
norm, display, inst = G.normFx("CLAP: Pro-Q 3 (FabFilter)")
eq(norm, "pro-q 3", "a CLAP effect")
eq(inst, false, "is not an instrument")
eq((G.normFx("JS: ReaEQ")), "reaeq", "a JS effect")
eq((G.normFx("ReaComp")), "reacomp", "a bare name stays as it is")
ok(G.inCategory({ norm = "pro-q 3" }, "eq"), "Pro-Q is an EQ")
ok(G.inCategory({ norm = "valhalla vintageverb" }, "verb"), "VintageVerb is a reverb")
ok(G.inCategory({ norm = "serum", instrument = true }, "inst"), "Serum is an instrument")
ok(not G.inCategory({ norm = "serum", instrument = true }, "comp"), "Serum is not a compressor")

------------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------------

local PLUGINS = { { norm = "serum", display = "Serum" }, { norm = "pro-q 3", display = "Pro-Q 3" } }

for s = 1, 50 do
  local rnd = L.random(s)
  local d = G.makeQuests(rnd, "daily", PLUGINS)
  local w = G.makeQuests(rnd, "weekly", PLUGINS)
  local kd, kw = {}, {}
  for _, q in ipairs(d) do kd[q.kind] = (kd[q.kind] or 0) + 1 end
  for _, q in ipairs(w) do kw[q.kind] = (kw[q.kind] or 0) + 1 end
  if not (#d == 3 and #w == 4 and kd.minutes == 1 and kw.minutes == 1 and kw.dailies == 1) then
    ok(false, "three daily quests with a time one, four weekly with time and dailies (seed " .. s .. ")")
  end
  for k, n in pairs(kd) do if n > 1 then ok(false, "no daily quest kind twice: " .. k) end end
  for _, q in ipairs(d) do
    if q.kind == "dailies" or q.kind == "checkins" or q.kind == "projects" then ok(false, "weekly-only quests stay weekly: " .. q.kind) end
  end
end
local noPlug = false
for s = 1, 50 do
  for _, q in ipairs(G.makeQuests(L.random(s), "daily", {})) do if q.kind == "plugin" then noPlug = true end end
end
ok(not noPlug, "no plugin quests without plugins")

do
  local st, ss, clock = fresh()
  G.refresh(st, ss, clock.epoch, PLUGINS)
  eq(#st.daily.quests, 3, "three daily quests")
  eq(#st.weekly.quests, 4, "four weekly quests")
  eq(#st.shop.deals, 3, "three daily deals")
  -- A plugin quest of our own.
  st.daily.quests[2] = { kind = "plugin", target = 2, progress = 0, done = false, claimed = false, scope = "daily",
                         seen = {}, param = "Serum", match = "serum", text = "Use Serum on 2 tracks", coins = 50, xp = 100, rarity = 3 }
  st.daily.quests[3] = { kind = "category", target = 1, progress = 0, done = false, claimed = false, scope = "daily",
                         seen = {}, param = "eq", text = "Use an EQ", coins = 50, xp = 100, rarity = 3 }
  G.event(st, ss, "fx", 1, { name = "VST3i: Serum (Xfer Records)" })
  eq(st.daily.quests[2].progress, 1, "using Serum counts for a Serum quest")
  G.event(st, ss, "fx", 1, { name = "VST: ReaEQ (Cockos)" })
  eq(st.daily.quests[2].progress, 1, "ReaEQ does not")
  ok(st.daily.quests[3].done, "but it does for an EQ quest")
  G.event(st, ss, "fx", 1, { name = "VST3i: Serum (Xfer Records)" })
  ok(st.daily.quests[2].done, "the Serum quest is done")
  eq(kinds(ss, "quest"), 2, "each completion is announced")
  local coins = st.coins
  ok(G.claimQuest(st, ss, "daily", 2), "a done quest can be claimed")
  ok(st.coins > coins, "for coins")
  ok(not G.claimQuest(st, ss, "daily", 2), "but only once")
  ok(not G.claimQuest(st, ss, "daily", 1), "an unfinished quest cannot be claimed")
  -- Finish the time quest too, and claim everything for the bonus.
  run(st, ss, clock, st.daily.quests[1].target + 5, 10)
  ok(st.daily.quests[1].done, "the time quest finishes with time")
  G.claimQuest(st, ss, "daily", 1)
  local unc = st.inv.crates[3]
  G.claimQuest(st, ss, "daily", 3)
  eq(st.inv.crates[3], unc + 1, "claiming all three dailies gives an Uncommon crate")
  ok(st.daily.bonus, "once")
  ok(st.weekly.quests[2].progress >= 3, "and every finished daily counts towards the weekly one")
end

do
  local st, ss, clock = fresh()
  G.refresh(st, ss, clock.epoch, PLUGINS)
  st.inv.tokens.reroll = 1
  local old = st.daily.quests[2].text
  ok(G.reroll(st, ss, "daily", 2, PLUGINS), "a reroll swaps a quest")
  eq(st.inv.tokens.reroll, 0, "and uses the token")
  ok(not G.reroll(st, ss, "daily", 3, PLUGINS), "no token, no reroll")
  local kinds2 = {}
  for _, q in ipairs(st.daily.quests) do kinds2[q.kind] = (kinds2[q.kind] or 0) + 1 end
  local dup = false
  for _, n in pairs(kinds2) do if n > 1 then dup = true end end
  ok(not dup, "a reroll doesn't duplicate a quest kind (was " .. old .. ")")
end

do
  local st, ss, clock = fresh()
  G.refresh(st, ss, clock.epoch, PLUGINS)
  local q = st.daily.quests[1]
  q.progress, q.done = q.target, true
  local coins = st.coins
  G.refresh(st, ss, clock.epoch + 86400, PLUGINS)
  ok(st.coins > coins, "a finished quest left unclaimed is claimed when the day turns")
  ok(st.daily.key == G.dayKey(clock.epoch + 86400), "and the new day has new quests")
end

------------------------------------------------------------------------------
-- Check-in
------------------------------------------------------------------------------

do
  local st, ss = fresh()
  ok(G.checkinAvailable(st, START), "check-in is open on a new day")
  local g = G.checkin(st, ss, START)
  eq(g.streak, 1, "the first check-in starts a streak")
  eq(g.day, 1, "on day 1")
  ok(not G.checkinAvailable(st, START + 3600), "only once a day")
  eq(G.checkin(st, ss, START + 3600), nil, "a second check-in does nothing")
  g = G.checkin(st, ss, START + 86400)
  eq(g.streak, 2, "the next day continues it")
  local e = START + 86400
  for i = 3, 7 do e = e + 86400; g = G.checkin(st, ss, e) end
  eq(g.day, 7, "day 7")
  ok(g.crate == 5, "day 7 gives an Epic crate")
  e = e + 86400
  eq(G.checkin(st, ss, e).day, 1, "and the calendar goes round")
  e = e + 3 * 86400
  g = G.checkin(st, ss, e)
  eq(g.streak, 1, "missing days breaks the streak")
  ok(g.broke, "and says so")
  eq(st.checkin.best, 8, "the best streak is kept")
  st.inv.tokens.freeze = 2
  e = e + 86400
  G.checkin(st, ss, e)
  e = e + 3 * 86400
  g = G.checkin(st, ss, e)
  eq(g.streak, 3, "Streak Freezes cover missed days")
  eq(g.freezes, 2, "one for each missed day")
  eq(st.inv.tokens.freeze, 0, "and are used up")
end

------------------------------------------------------------------------------
-- The shop
------------------------------------------------------------------------------

do
  local st, ss, clock = fresh()
  G.refresh(st, ss, clock.epoch, {})
  ok(not G.buy(st, ss, "takeaway"), "no coins, no takeaway")
  st.coins = 5000
  ok(G.buy(st, ss, "takeaway"), "a takeaway pass can be bought")
  eq(st.coins, 5000 - G.SHOP.takeaway.price, "for its price")
  eq(st.inv.passes.takeaway, 1, "and is in the inventory")
  ok(G.redeem(st, ss, "takeaway", clock.epoch), "and redeemed")
  eq(st.inv.passes.takeaway, 0, "once")
  eq(st.log[1].name, "Takeaway Pass", "and remembered")
  ok(not G.redeem(st, ss, "takeaway", clock.epoch), "you can't redeem what you haven't got")
  ok(G.buy(st, ss, "boost"), "a boost token can be bought")
  ok(G.useBoost(st, ss), "and used")
  eq(st.boost, G.BOOST_SECONDS, "for thirty minutes")
  ok(G.buy(st, ss, "crate5"), "an Epic crate can be bought")
  eq(st.inv.crates[5], 1, "and is a crate")
  st.coins = 100000
  local deal = st.shop.deals[1]
  ok(G.buyDeal(st, ss, 1), "a daily deal can be bought")
  ok(deal.bought and not G.buyDeal(st, ss, 1), "once")
  local deals1 = G.serialize(st.shop.deals)
  G.refresh(st, ss, clock.epoch + 3600, {})
  eq(G.serialize(st.shop.deals), deals1, "the deals don't change during the day")
  G.refresh(st, ss, clock.epoch + 86400, {})
  ok(G.serialize(st.shop.deals) ~= deals1, "and do the next day")
end

------------------------------------------------------------------------------
-- Crates and gear
------------------------------------------------------------------------------

do
  local st, ss = fresh()
  eq(G.openCrate(st, ss, 4), nil, "no crate, nothing to open")
  st.inv.crates[4] = 1
  local drops = G.openCrate(st, ss, 4)
  eq(#drops, 3, "a crate holds three things")
  eq(st.inv.crates[4], 0, "and is gone")
  eq(kinds(ss, "crate"), 1, "opening is announced")
  st.gear.equipped.phones = { slot = "phones", rarity = 6, affixes = {}, implicit = { id = "xp", value = 1 }, power = "hoarder" }
  st.inv.crates[4] = 1
  eq(#G.openCrate(st, ss, 4), 4, "Hoarder adds an item")
end

do
  local st, ss = fresh()
  local a = L.makeGear(L.random(1), 4, 10, "phones")
  local b = L.makeGear(L.random(2), 5, 10, "phones")
  G.grant(st, ss, a)
  G.grant(st, ss, b)
  eq(#st.gear.stash, 2, "gear goes to the stash")
  ok(G.equip(st, ss, a.uid), "and can be equipped")
  eq(st.gear.equipped.phones, a, "into its slot")
  eq(#st.gear.stash, 1, "leaving the stash")
  local xp = G.bonus(st, "xp")
  ok(xp >= a.implicit.value, "headphones' implicit XP counts as a bonus")
  G.equip(st, ss, b.uid)
  eq(st.gear.equipped.phones, b, "equipping another swaps")
  eq(st.gear.stash[1], a, "the old one back in the stash")
  local coins = st.coins
  ok(G.salvage(st, ss, a.uid) > 0, "salvaging sells")
  ok(st.coins > coins and #st.gear.stash == 0, "for coins")
  ok(G.unequip(st, ss, "phones") and #st.gear.stash == 1, "unequipping puts it back")
  for i = 1, G.STASH_MAX + 3 do G.grant(st, ss, L.makeGear(L.random(100 + i), 1 + i % 5, 5)) end
  eq(#st.gear.stash, G.STASH_MAX, "the stash never overflows: the weakest is sold")
  local n, total = G.salvageUpTo(st, ss, 2)
  ok(n > 0 and total > 0, "junk can be sold in one go")
  for _, it in ipairs(st.gear.stash) do if it.rarity <= 2 then ok(false, "no junk left") end end
end

------------------------------------------------------------------------------
-- Achievements
------------------------------------------------------------------------------

do
  local st, ss = fresh()
  G.checkAchievements(st, ss)
  eq(kinds(ss, "ach"), 0, "nothing unlocked at the start")
  st.stats.active = 3600 * 5
  G.checkAchievements(st, ss)
  eq(st.ach.hours, 2, "five hours unlocks the first two tiers of Time in the Studio")
  eq(kinds(ss, "ach"), 2, "each announced")
  G.checkAchievements(st, ss)
  eq(kinds(ss, "ach"), 2, "and only once")
  st.stats.mythics = 25
  G.checkAchievements(st, ss)
  local titled = false
  for _, t in ipairs(st.cos.titles) do if t.text == "The Mythic" then titled = true end end
  ok(titled, "finishing a series gives its title")
  local have, all = G.achievementTotals(st)
  ok(have >= 5 and all > 100, "totals add up (" .. have .. " of " .. all .. ")")
end

------------------------------------------------------------------------------
-- Seasons
------------------------------------------------------------------------------

do
  local st, ss, clock = fresh()
  G.refresh(st, ss, clock.epoch, {})
  eq(st.pass.season, 10, "the first season is today's")
  eq(kinds(ss, "season"), 0, "the first season isn't announced as new")
  st.pass.tier, st.pass.secs = 37, 300
  local nov = os.time({ year = 2026, month = 11, day = 1, hour = 12 })
  G.refresh(st, ss, nov, {})
  eq(st.pass.season, 11, "November is a new season")
  eq(st.pass.tier, 0, "the track starts again")
  eq(st.pass.secs, 300, "the minutes towards the next tier carry over")
  eq(st.seasons["10"], 37, "last season's tier is remembered")
  eq(kinds(ss, "season"), 1, "and the new season is announced")
end

------------------------------------------------------------------------------
-- Saving
------------------------------------------------------------------------------

do
  local st, ss, clock = fresh()
  G.refresh(st, ss, clock.epoch, PLUGINS)
  run(st, ss, clock, 3600, 10)
  for r = 2, 7 do st.inv.crates[r] = 1; G.openCrate(st, ss, r) end
  local s = G.serialize(st)
  local back = G.clampState(G.deserialize(s), clock.epoch)
  eq(G.serialize(back), s, "the state survives a save and a load exactly")
  _G.PWNED = nil
  G.deserialize("{ (function() PWNED = true end)() }")
  eq(_G.PWNED, nil, "a save can't reach anything outside itself")
  eq(G.deserialize("{ os.remove('x') }"), nil, "nor call the system")
  eq(G.deserialize("not lua at all"), nil, "a broken save is refused, not crashed on")
  eq(G.deserialize(""), nil, "an empty save is no save")
  local weird = G.clampState({ coins = -5, level = "x", inv = { crates = { 1 } }, settings = { idle = 5 } }, START)
  eq(weird.coins, 0, "negative coins are put right")
  eq(weird.level, 1, "a nonsense level is level 1")
  eq(#weird.inv.crates, 7, "short crate lists are filled out")
  eq(weird.settings.idle, 60, "the idle time is at least a minute")
  ok(type(weird.daily.quests) == "table" and type(weird.gear.stash) == "table", "missing parts are filled in")
  local ser = G.serialize({ ["end"] = 1, _runtime = 2, list = { 1, 2 } })
  ok(ser:find('%["end"%]') and not ser:find("_runtime"), "reserved words are quoted and underscore keys skipped")
end

C.done()
