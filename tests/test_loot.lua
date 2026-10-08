--[[ Thousands of rewards, every one checked: every kind of idea at every
     rarity, gear, cosmetics, crates, rarity rolls and the season track.

       lua5.4 tests/test_loot.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local C = dofile(HERE .. "/check.lua")
local ok, eq = C.ok, C.eq
local T = dofile(C.SCRIPTS .. "bp_theory.lua")
local L = dofile(C.SCRIPTS .. "bp_loot.lua").init(T)

-- A rule broken many times is reported once, with a count and its first
-- example, so a broken generator is one readable line.
local tally = {}
local function rule(cond, name, example)
  local t = tally[name]
  if not t then t = { n = 0, bad = 0 }; tally[name] = t; tally[#tally + 1] = name end
  t.n = t.n + 1
  if not cond then
    t.bad = t.bad + 1
    t.example = t.example or example
  end
end
local function report()
  for _, name in ipairs(tally) do
    local t = tally[name]
    ok(t.bad == 0, string.format("%s (%d of %d broke it, e.g. %s)", name, t.bad, t.n, tostring(t.example)))
  end
  tally = {}
end

------------------------------------------------------------------------------
-- The dice
------------------------------------------------------------------------------

local a, b = L.random(7), L.random(7)
local same = true
for _ = 1, 20 do if a() ~= b() then same = false end end
ok(same, "the same seed gives the same numbers")
local r1 = L.random(7)()
local r2 = L.random(8)()
ok(r1 ~= r2, "neighbouring seeds differ")
eq(L.seedOf("tier", 10, 37), L.seedOf("tier", 10, 37), "seedOf is stable")
ok(L.seedOf("tier", 10, 37) ~= L.seedOf("tier", 10, 38), "and tells tiers apart")
local inRange = true
local rnd = L.random(99)
for _ = 1, 10000 do local x = rnd(); if x < 0 or x >= 1 then inRange = false end end
ok(inRange, "the dice stay in [0, 1)")

------------------------------------------------------------------------------
-- Rarity
------------------------------------------------------------------------------

eq(#L.RARITY, 7, "seven rarities, Poor to Mythic")
eq(L.RARITY[1].name, "Poor", "the bottom is Poor")
eq(L.RARITY[7].name, "Mythic", "the top is Mythic")
for i = 2, 7 do
  ok(L.RARITY[i].coins[1] > L.RARITY[i - 1].coins[1], L.RARITY[i].name .. " coins beat " .. L.RARITY[i - 1].name)
  ok(L.RARITY[i].sell > L.RARITY[i - 1].sell, L.RARITY[i].name .. " sells for more")
end

local function meanRarity(luck)
  local rr, sum = L.random(5), 0
  for _ = 1, 20000 do sum = sum + L.rollRarity(rr, 1, 7, luck) end
  return sum / 20000
end
local plain, lucky = meanRarity(0), meanRarity(100)
ok(lucky > plain + 0.2, string.format("luck raises the rarity (%.2f against %.2f)", lucky, plain))
local counts = {}
rnd = L.random(11)
for _ = 1, 50000 do local x = L.rollRarity(rnd, 1, 7); counts[x] = (counts[x] or 0) + 1 end
for i = 3, 7 do ok((counts[i] or 0) < (counts[i - 1] or 0), L.RARITY[i].name .. " is rarer than " .. L.RARITY[i - 1].name) end
ok((counts[7] or 0) > 0, "Mythic does happen")
rnd = L.random(12)
for _ = 1, 2000 do
  local x = L.rollRarity(rnd, 4, 6, 50)
  rule(x >= 4 and x <= 6, "rollRarity keeps inside its bounds", x)
end
report()

------------------------------------------------------------------------------
-- Ideas
------------------------------------------------------------------------------

local function checkBlock(block, where)
  rule(type(block.name) == "string" and block.name ~= "", "a block has a name", where)
  rule(block.beats > 0, "a block has a length", where)
  rule(#block.notes > 0, "a block has notes", where)
  for _, n in ipairs(block.notes) do
    rule(n.pitch >= 0 and n.pitch <= 127 and math.floor(n.pitch) == n.pitch, "pitches are MIDI notes", where .. " " .. tostring(n.pitch))
    rule(n.start >= 0 and n.len > 0, "notes start in the block and have length", where)
    rule(n.start + n.len <= block.beats + 1e-6, "notes end inside the block", where .. " " .. (n.start + n.len) .. ">" .. block.beats)
    rule((n.vel or 100) >= 1 and (n.vel or 100) <= 127, "velocities are 1-127", where)
  end
end

for _, def in ipairs(L.IDEAS) do
  for r = 1, 7 do
    for s = 1, 60 do
      local where = def.id .. "/" .. L.RARITY[r].name .. "/" .. s
      local d = L.makeIdea(L.random(L.seedOf(def.id, r, s)), def.id, r)
      rule(type(d.text) == "string" and #d.text > 0, "every idea has words", where)
      rule(not d.text:find("%%%a") and not (d.sub or ""):find("%%%a"), "no template marks left in an idea", where .. ": " .. d.text)
      rule(not d.text:find("nil") and not d.text:find("table:"), "no nil or table in an idea", where .. ": " .. d.text)
      if def.id ~= "chords" and def.id ~= "melody" and def.id ~= "seed" then
        rule(not (" " .. d.text .. " " .. d.sub):find("[ ][Aa] [AEIOUaeiou]"), "a/an agree", where .. ": " .. d.text .. " " .. d.sub)
      end
      rule(d.rarity == r and d.type == "idea" and d.kind == def.id, "an idea knows its kind and rarity", where)
      if def.midi then
        rule(d.data.block ~= nil, "a MIDI idea carries a block", where)
        if d.data.block then checkBlock(d.data.block, where) end
      end
      local again = L.makeIdea(L.random(L.seedOf(def.id, r, s)), def.id, r)
      rule(again.text == d.text and again.sub == d.sub, "an idea is a function of its seed", where)
    end
  end
end
report()

-- Chords: more of them and richer the rarer they are.
for r = 1, 7 do
  for s = 1, 80 do
    local p = L.progression(L.random(L.seedOf("prog", r, s)), r)
    local want = (r >= L.LEGENDARY) and 8 or ((r >= L.EPIC) and 6 or 4)
    rule(#p.chords == want, "a " .. L.RARITY[r].name .. " progression has " .. want .. " chords", #p.chords)
    for _, c in ipairs(p.chords) do
      rule(c.name:match("^[A-G][#b]?") ~= nil, "chord names start with a note", c.name)
      rule(not c.name:find("bb") and not c.name:find("x"), "no double flats or sharps in chord names", c.name)
      rule(#c.pcs >= 3, "chords have three notes or more", c.name)
    end
    if r >= L.EPIC then
      local sevenths = 0
      for _, c in ipairs(p.chords) do if #c.pcs >= 4 then sevenths = sevenths + 1 end end
      rule(sevenths >= #p.chords / 2, "Epic and better progressions are mostly sevenths", sevenths)
    end
  end
end
report()

local anyBorrowed, anyApplied = false, false
for s = 1, 200 do
  local p = L.progression(L.random(L.seedOf("rich", s)), L.LEGENDARY)
  for _, c in ipairs(p.chords) do
    if c.borrowed then anyBorrowed = true end
    if c.applied then anyApplied = true end
  end
end
ok(anyBorrowed, "Legendary progressions borrow chords")
ok(anyApplied, "Legendary progressions use secondary dominants")

-- A secondary dominant is the dominant seventh a fifth above its target.
for s = 1, 200 do
  local p = L.progression(L.random(L.seedOf("applied", s)), L.LEGENDARY)
  for i, c in ipairs(p.chords) do
    if c.applied then
      local target = p.chords[i + 1]
      rule((c.root - target.root) % 12 == 7, "V7/x is a fifth above x", c.name .. " " .. target.name)
      rule(c.name:sub(-1) == "7", "V7/x is a seventh chord", c.name)
    end
  end
end
report()

-- Drums: whole bars, a kick, a tempo from the style.
for r = 1, 7 do
  for s = 1, 60 do
    local p = L.drumPattern(L.random(L.seedOf("drums", r, s)), r)
    local where = p.style .. "/" .. L.RARITY[r].name
    rule(p.steps == p.bars * 16, "a pattern is whole bars of sixteenths", where)
    local hasKick = false
    for _, row in ipairs(p.rows) do
      rule(#row.steps == p.steps, "every row is as long as the pattern", where .. " " .. row.name)
      if row.id == "kick" then hasKick = true end
    end
    rule(hasKick, "every pattern has a kick", where)
    local style
    for _, st in ipairs(L.DRUM_STYLES) do if st.name == p.style then style = st end end
    rule(p.bpm >= style.bpm[1] and p.bpm <= style.bpm[2], "the tempo suits the style", where .. " " .. p.bpm)
    checkBlock(L.drumBlock(p, "Drums"), where)
  end
end
report()

-- Melodies: in the key, ending home.
for r = 1, 7 do
  for s = 1, 60 do
    local m = L.melody(L.random(L.seedOf("melody", r, s)), r)
    local where = m.keyName .. "/" .. L.RARITY[r].name .. "/" .. s
    local scale = {}
    for _, iv in ipairs(T.SCALES[m.key.scale].iv) do scale[(T.rootPc(m.key) + iv) % 12] = true end
    for _, n in ipairs(m.notes) do rule(scale[n.pitch % 12], "melody notes are in the key", where .. " " .. n.pitch) end
    rule(m.notes[#m.notes].pitch % 12 == T.rootPc(m.key), "a melody ends on its key note", where)
    rule(m.notes[1].pitch >= 48 and m.notes[#m.notes].pitch <= 96, "a melody sits around middle C", where)
  end
end
report()

------------------------------------------------------------------------------
-- Gear
------------------------------------------------------------------------------

local AFFIX_COUNT = { 0, 0, 1, 2, 3, 3, 4 }
local scoreByRarity = {}
for r = 1, 7 do
  local total = 0
  for s = 1, 150 do
    local g = L.makeGear(L.random(L.seedOf("gear", r, s)), r, 20)
    local where = L.RARITY[r].name .. " " .. g.name
    rule(#g.affixes == AFFIX_COUNT[r], L.RARITY[r].name .. " gear has " .. AFFIX_COUNT[r] .. " affixes", where)
    local seen = { [g.implicit.id] = true }
    for _, a in ipairs(g.affixes) do
      rule(not seen[a.id], "no affix twice on an item, nor its implicit again", where .. " " .. a.id)
      seen[a.id] = true
      rule(a.value >= 1, "affixes roll at least 1", where)
    end
    rule((g.power ~= nil) == (r >= L.LEGENDARY), "only Legendary and Mythic gear has a power", where)
    rule(type(g.name) == "string" and #g.name > 2 and not g.name:find("nil"), "gear has a name", where)
    rule(L.SLOTS[g.slot] ~= nil, "gear fits a slot", where)
    total = total + L.gearScore(g)
  end
  scoreByRarity[r] = total / 150
end
report()
for r = 2, 7 do
  ok(scoreByRarity[r] > scoreByRarity[r - 1], string.format("%s gear scores higher than %s on average (%.1f > %.1f)",
     L.RARITY[r].name, L.RARITY[r - 1].name, scoreByRarity[r], scoreByRarity[r - 1]))
end
local slotGear = L.makeGear(L.random(3), 4, 10, "mic")
eq(slotGear.slot, "mic", "gear can be made for a chosen slot")
eq(slotGear.implicit.id, "rec", "a microphone's implicit is recording XP")
ok(L.sellValue(L.makeGear(L.random(4), 7, 50)) > L.sellValue(L.makeGear(L.random(4), 2, 50)), "Mythic sells for more than Common")
ok(L.statLine("xp", 5) == "+5% XP from everything", "stat lines read as sentences")
local hi = L.makeGear(L.random(5), 5, 100)
local lo = L.makeGear(L.random(5), 5, 1)
ok(L.gearScore(hi) >= L.gearScore(lo), "a higher item level never scores lower, same dice")

------------------------------------------------------------------------------
-- Drops, crates, cosmetics
------------------------------------------------------------------------------

for _, pool in ipairs({ "tier", "crate", "deal" }) do
  for s = 1, 300 do
    local r = (s % 7) + 1
    local d = L.makeDrop(L.random(L.seedOf(pool, s)), r, pool, { ilvl = 5 })
    rule(d.type and d.rarity and d.text and d.text ~= "", "every " .. pool .. " drop is complete", s)
    rule(d.rarity >= 1 and d.rarity <= 7, "drop rarities are on the ladder", d.rarity)
  end
end
report()

for r = 2, 7 do
  for s = 1, 60 do
    local list = L.crateContents(L.random(L.seedOf("crate", r, s)), r, 0, (s % 3 == 0) and 1 or 0, { ilvl = 3 })
    rule(#list == ((s % 3 == 0) and 4 or 3), "a crate holds three, plus extras", #list)
    rule(list[1].rarity >= r, "a crate's first item is at least its rarity", list[1].rarity .. " < " .. r)
    for _, d in ipairs(list) do rule(d.rarity >= math.max(1, r - 2), "nothing more than two steps under the crate", d.rarity) end
  end
end
report()

for r = 1, 7 do
  local t = L.makeTitle(L.random(r), r)
  ok(t.type == "title" and #t.text > 0, L.RARITY[r].name .. " title: " .. t.text)
  local b = L.makeBanner(L.random(r), r)
  ok(b.type == "banner" and b.data.shape ~= nil, L.RARITY[r].name .. " banner: " .. b.text)
end
ok(L.makeBanner(L.random(1), 7).data.spin, "Mythic banners spin")
ok(not L.makeBanner(L.random(1), 3).data.glow, "Uncommon banners don't glow")

eq(L.articles("A anxious song"), "An anxious song", "a becomes an before a vowel")
eq(L.articles("Design a pad"), "Design a pad", "and stays a before a consonant")

------------------------------------------------------------------------------
-- The season track
------------------------------------------------------------------------------

eq(L.tierKind(1), "small", "tier 1 is small")
eq(L.tierKind(4), "big", "every fourth tier - each hour - is big")
eq(L.tierKind(10), "milestone", "every tenth is a milestone")
eq(L.tierKind(25), "legendary", "every 25th is legendary")
eq(L.tierKind(100), "finale", "tier 100 is the finale")
eq(L.tierKind(104), "big", "bonus tiers go on: 104 is an hour")
eq(L.tierKind(110), "small", "and bonus tiers have no milestones")
eq(L.seasonId(2026, 10), 10, "October 2026 is season 10")
eq(L.seasonId(2027, 1), 13, "January 2027 is season 13")
eq(L.seasonName(10), L.seasonName(10), "a season's name is fixed")

for season = 10, 12 do
  for tier = 1, 120 do
    local list, kind = L.tierRewards(season, tier, 10)
    local again = L.tierRewards(season, tier, 10)
    rule(#list == #again and list[#list].text == again[#again].text, "a tier's rewards are a function of season and tier", season .. "/" .. tier)
    rule(#list >= 2, "every tier gives at least two things", tier)
    if kind == "big" then
      local crate = false
      for _, d in ipairs(list) do if d.type == "crate" then crate = d.rarity >= L.RARE end end
      rule(crate, "every hour gives a Rare or better crate", tier)
    end
    if kind == "finale" then
      local mythic = false
      for _, d in ipairs(list) do if d.type == "gear" and d.rarity == L.MYTHIC then mythic = true end end
      rule(mythic, "the finale gives Mythic gear", tier)
    end
    local best = L.tierHeadline(season, tier, 10)
    for _, d in ipairs(list) do rule(best.rarity >= d.rarity, "the headline is the best reward", tier) end
  end
end
report()

C.done()
