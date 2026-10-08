--[[ What the loot table makes, printed: every kind of idea at every rarity,
     gear, cosmetics, and the start of this season's track. Read it before
     and after changing a generator or a word list.

       lua5.4 tools/demo.lua [seed]
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local S = HERE .. "/../reascripts/"
local T = dofile(S .. "bp_theory.lua")
local L = dofile(S .. "bp_loot.lua").init(T)
local seed = tonumber(arg and arg[1]) or 42
local rnd = L.random(seed)

for _, d in ipairs(L.IDEAS) do
  print(("== %s"):format(d.label))
  for r = 1, 7 do
    local i = L.makeIdea(rnd, d.id, r)
    print(("  %-9s %s"):format(L.RARITY[r].name, i.text))
    if i.sub ~= "" then print(("  %-9s   %s"):format("", i.sub)) end
    if i.data.text then for line in i.data.text:gmatch("[^\n]+") do print("              " .. line) end end
  end
end

print("== Gear (item level 20)")
for r = 1, 7 do
  local g = L.makeGear(rnd, r, 20)
  print(("  %-9s %s  [%s, score %d]"):format(L.RARITY[r].name, g.name, L.SLOTS[g.slot].name, L.gearScore(g)))
  print("              " .. L.statLine(g.implicit.id, g.implicit.value) .. " (implicit)")
  for _, a in ipairs(g.affixes) do print("              " .. L.statLine(a.id, a.value)) end
  if g.power then print("              Power: " .. L.POWERS[g.power].name .. " - " .. L.POWERS[g.power].text) end
end

print("== Titles and banners")
for r = 1, 7 do print(("  %-9s %s  /  banner: %s"):format(L.RARITY[r].name, L.makeTitle(rnd, r).text, L.makeBanner(rnd, r).text)) end

local d = os.date("*t")
local season = L.seasonId(d.year, d.month)
print(("== Season %d: %s - the first twelve tiers"):format(season, L.seasonName(season)))
for tier = 1, 12 do
  local list, kind = L.tierRewards(season, tier, 10)
  local parts = {}
  for _, x in ipairs(list) do parts[#parts + 1] = L.RARITY[x.rarity].name .. " " .. (x.type == "coins" and x.text or (x.type == "crate" and "Crate" or x.name)) end
  print(("  %3d %-9s %s"):format(tier, kind, table.concat(parts, ", ")))
end
