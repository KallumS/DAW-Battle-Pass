--[[ The theory copied from the sister repos still says what they say, and
     the little the battle pass adds names chords correctly.

       lua5.4 tests/test_theory.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local C = dofile(HERE .. "/check.lua")
local ok, eq = C.ok, C.eq
local T = dofile(C.SCRIPTS .. "bp_theory.lua")

------------------------------------------------------------------------------
-- The copies: ScaleView's roots and scales, Starting Blocks' chord table,
-- exactly as Good Idea and Midi Catalogue carry them (read off Good Idea on
-- 2026-10-08). If one of these fails, the copy has drifted from the family.
------------------------------------------------------------------------------

local roots = {}
for _, r in ipairs(T.ROOTS) do roots[#roots + 1] = r.name .. r.letter .. r.acc end
eq(table.concat(roots, " "),
   "C00 C#01 Db1-1 D10 D#11 Eb2-1 E20 F30 F#31 Gb4-1 G40 G#41 Ab5-1 A50 A#51 Bb6-1 B60 Cb0-1",
   "the roots are ScaleView's")

local scales = {}
for _, s in ipairs(T.SCALES) do scales[#scales + 1] = s.name .. ":" .. table.concat(s.iv, ",") end
eq(table.concat(scales, " "),
   "Major:0,2,4,5,7,9,11 Minor:0,2,3,5,7,8,10 Harm Minor:0,2,3,5,7,8,11 Ionian:0,2,4,5,7,9,11 " ..
   "Dorian:0,2,3,5,7,9,10 Phrygian:0,1,3,5,7,8,10 Lydian:0,2,4,6,7,9,11 Mixolydian:0,2,4,5,7,9,10 " ..
   "Aeolian:0,2,3,5,7,8,10 Maj Pent:0,2,4,7,9 Min Pent:0,3,5,7,10 Maj Blues:0,2,3,4,7,9 " ..
   "Min Blues:0,3,5,6,7,10 Whole Tone:0,2,4,6,8,10 Dim W-H:0,2,3,5,6,8,9,11 Dim H-W:0,1,3,4,6,7,9,10",
   "the scales are ScaleView's")
eq(#T.CHORDS, 78, "Starting Blocks' 78 chords")

------------------------------------------------------------------------------
-- Spelling and naming
------------------------------------------------------------------------------

local function names(rootName, scaleName, sevenths)
  local key = T.key(nil, T.scaleIndex(scaleName))
  for i, r in ipairs(T.ROOTS) do if r.name == rootName then key.root = i end end
  local out = {}
  for d = 0, 6 do out[#out + 1] = T.degreeChord(key, d, sevenths).name end
  return table.concat(out, " ")
end

eq(names("C", "Major"), "C Dm Em F G Am Bdim", "C major's triads")
eq(names("A", "Minor"), "Am Bdim C Dm Em F G", "A minor's triads")
eq(names("F#", "Major"), "F# G#m A#m B C# D#m E#dim", "F# major spells its seventh E#, not F")
eq(names("Eb", "Major"), "Eb Fm Gm Ab Bb Cm Ddim", "Eb major in flats")
eq(names("C", "Major", true), "Cmaj7 Dm7 Em7 Fmaj7 G7 Am7 Bm7b5", "C major's sevenths")
eq(names("A", "Harm Minor"), "Am Bdim Caug Dm E F G#dim", "harmonic minor's major V and augmented III")

local key = T.key(nil, T.scaleIndex("Minor"))
key.root = T.rootFor(9)
eq(T.degreeChord(key, 0).numeral, "i", "minor tonic numeral")
eq(T.degreeChord(key, 5).numeral, "VI", "minor's VI is major")
eq(T.degreeChord(key, 1).numeral, "ii\u{00B0}", "minor's ii is diminished")

for pc = 0, 11 do
  local r = T.ROOTS[T.rootFor(pc)]
  ok(r ~= nil, "every pitch class has a preferred spelling (" .. pc .. ")")
  eq(T.rootPc(T.key(T.rootFor(pc), 1)), pc, "and it is that pitch class (" .. pc .. ")")
end

-- Every reward scale exists.
for _, s in ipairs(T.REWARD_SCALES) do ok(T.scaleIndex(s[1]) ~= nil, "reward scale " .. s[1] .. " is in the table") end

C.done()
