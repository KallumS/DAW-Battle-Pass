--[[ DAW Battle Pass - keys, scales and chord names.

     Pure Lua. Nothing in this file touches REAPER or ImGui.

     The battle pass hands out musical ideas as rewards (chord progressions,
     melodies, song seeds), and they should name their notes and chords the
     way the sister apps do. So everything here is Good Idea's theory file -
     which is Midi Catalogue's, ScaleView's and Starting Blocks' - copied
     unchanged and cut down to what the rewards use: the keys, positions and
     spelling, the degree numerals, and Starting Blocks' chord table for
     naming. tests/test_theory.lua checks the copies still say what the
     originals say. Do not tidy them independently.

     Two ways of naming a note run through it:

       - a MIDI pitch, 0..127;
       - a scale position, an integer counting scale notes from the key's root
         in MIDI octave -1. A third above is +2, whatever the scale.
]]

local M = {}


------------------------------------------------------------------------------
-- Keys
--
-- ScaleView for REAPER's roots and scales, unchanged, the same tables Starting
-- Blocks copies, so all three apps agree on what a scale is and what to call
-- its notes. test_theory.lua asserts they still match. Do not tidy them
-- independently.
------------------------------------------------------------------------------

local LETTER_PC  = { 0, 2, 4, 5, 7, 9, 11 }        -- C D E F G A B
local LETTERS    = { "C", "D", "E", "F", "G", "A", "B" }
local ACCIDENTAL = { [-2] = "bb", [-1] = "b", [0] = "", [1] = "#", [2] = "x" }

M.ROOTS = {
  { name = "C",  letter = 0, acc =  0 }, { name = "C#", letter = 0, acc =  1 },
  { name = "Db", letter = 1, acc = -1 }, { name = "D",  letter = 1, acc =  0 },
  { name = "D#", letter = 1, acc =  1 }, { name = "Eb", letter = 2, acc = -1 },
  { name = "E",  letter = 2, acc =  0 }, { name = "F",  letter = 3, acc =  0 },
  { name = "F#", letter = 3, acc =  1 }, { name = "Gb", letter = 4, acc = -1 },
  { name = "G",  letter = 4, acc =  0 }, { name = "G#", letter = 4, acc =  1 },
  { name = "Ab", letter = 5, acc = -1 }, { name = "A",  letter = 5, acc =  0 },
  { name = "A#", letter = 5, acc =  1 }, { name = "Bb", letter = 6, acc = -1 },
  { name = "B",  letter = 6, acc =  0 }, { name = "Cb", letter = 0, acc = -1 },
}

M.SCALES = {
  { name = "Major",      iv = {0,2,4,5,7,9,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Minor",      iv = {0,2,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Harm Minor", iv = {0,2,3,5,7,8,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Ionian",     iv = {0,2,4,5,7,9,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Dorian",     iv = {0,2,3,5,7,9,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Phrygian",   iv = {0,1,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Lydian",     iv = {0,2,4,6,7,9,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Mixolydian", iv = {0,2,4,5,7,9,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Aeolian",    iv = {0,2,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Maj Pent",   iv = {0,2,4,7,9},        letters = {0,1,2,4,5} },
  { name = "Min Pent",   iv = {0,3,5,7,10},       letters = {0,2,3,4,6} },
  { name = "Maj Blues",  iv = {0,2,3,4,7,9},      letters = {0,1,2,2,4,5} },
  { name = "Min Blues",  iv = {0,3,5,6,7,10},     letters = {0,2,3,4,4,6} },
  { name = "Whole Tone", iv = {0,2,4,6,8,10},     letters = {0,1,2,3,4,5} },
  { name = "Dim W-H",    iv = {0,2,3,5,6,8,9,11}, letters = {0,1,2,3,4,5,5,6} },
  { name = "Dim H-W",    iv = {0,1,3,4,6,7,9,10}, letters = {0,1,2,2,3,4,5,6} },
}

local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

-- A key is the pair of indices the window picks. A chord scale (M.chordKey)
-- is a key that also carries its own intervals: the same scale with a note
-- or two bent to the chord sounding over it.
function M.key(root, scale) return { root = root or 1, scale = scale or 1 } end

local function ivOf(key) return key.iv or M.SCALES[key.scale].iv end

M.ivOf = ivOf

function M.scaleLen(key) return #ivOf(key) end

function M.rootPc(key)
  local rt = M.ROOTS[key.root]
  return (LETTER_PC[rt.letter + 1] + rt.acc + 12) % 12
end

------------------------------------------------------------------------------
-- Positions and pitches
------------------------------------------------------------------------------

-- The MIDI pitch of a scale position.
function M.pitch(key, pos)
  local iv  = ivOf(key)
  local n   = #iv
  local oct = math.floor(pos / n)
  local k   = pos - oct * n
  return M.rootPc(key) + (key.lift or 0) + iv[k + 1] + 12 * oct
end

-- The highest position at or below a pitch. Every pitch has one, because the
-- root is in every octave.
function M.floorPos(key, midi)
  local iv   = ivOf(key)
  local n    = #iv
  local root = M.rootPc(key) + (key.lift or 0)
  local oct  = math.floor((midi - root) / 12)
  local kmax = 0
  for k = 1, n do
    if root + iv[k] + 12 * oct <= midi then kmax = k - 1 end
  end
  return oct * n + kmax
end

-- The position of a pitch that is in the scale, or nil for one that is not.
function M.posOf(key, midi)
  local s = M.floorPos(key, midi)
  if M.pitch(key, s) == midi then return s end
  return nil
end

-- The nearest position to any pitch. A pitch exactly between two scale notes
-- goes the way `lean` says (+1 up, -1 down), and down when it says nothing.
function M.nearestPos(key, midi, lean)
  local lo = M.floorPos(key, midi)
  if M.pitch(key, lo) == midi then return lo end
  local dLo = midi - M.pitch(key, lo)
  local dHi = M.pitch(key, lo + 1) - midi
  if dLo < dHi then return lo end
  if dHi < dLo then return lo + 1 end
  return (lean or -1) > 0 and lo + 1 or lo
end

function M.pc(key, pos) return M.pitch(key, pos) % 12 end

-- Spelled for the key: the seventh of F# major comes out E#, not F.
function M.noteName(key, pos)
  local sc  = M.SCALES[key.scale]
  local n   = #ivOf(key)
  local oct = math.floor(pos / n)
  local k   = pos - oct * n
  local letter = (M.ROOTS[key.root].letter + sc.letters[k + 1]) % 7
  local acc = M.pitch(key, pos) % 12 - LETTER_PC[letter + 1]
  if acc >  6 then acc = acc - 12 end
  if acc < -6 then acc = acc + 12 end
  return LETTERS[letter + 1] .. (ACCIDENTAL[acc] or "?")
end

-- A pitch named with its octave, C4 being middle C (60). Out of the key, the
-- sharp spelling.
local SHARP_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
function M.pitchName(midi, key)
  local oct = math.floor(midi / 12) - 1
  if key then
    local s = M.posOf(key, midi)
    if s then return M.noteName(key, s) .. oct end
  end
  return SHARP_NAMES[midi % 12 + 1] .. oct
end

------------------------------------------------------------------------------
-- Degrees
------------------------------------------------------------------------------

-- Read off the scale rather than assumed, so the modes and the blues scales
-- come out right: the vii of major is diminished, the III of minor is major.
function M.degreeQuality(key, degree)
  local p  = M.pitch(key, degree)
  local r3 = M.pitch(key, degree + 2) - p
  local r5 = M.pitch(key, degree + 4) - p
  if r3 == 4 and r5 == 7 then return "major"      end
  if r3 == 3 and r5 == 7 then return "minor"      end
  if r3 == 3 and r5 == 6 then return "diminished" end
  if r3 == 4 and r5 == 8 then return "augmented"  end
  return "other"
end

function M.degreeNumeral(key, degree, ascii)
  local q = M.degreeQuality(key, degree)
  local n = NUMERALS[(degree % 8) + 1]
  if q == "minor" or q == "diminished" then n = n:lower() end
  if q == "diminished" then n = n .. (ascii and "dim" or "\u{00B0}") end
  if q == "augmented"  then n = n .. (ascii and "aug" or "+") end
  return n
end


------------------------------------------------------------------------------
-- Chords
--
-- Starting Blocks' chord tables, copied unchanged: one row per chord carrying
-- its own name, symbol and intervals (semitones from the chord's root), in
-- the families of Wikipedia's list of chords. Here they only name what the
-- scale builds (Good Idea's chords are always in key). Do not tidy them
-- independently of Starting Blocks.
------------------------------------------------------------------------------

M.FAMILIES = { "Diatonic", "Triads", "6ths & 7ths", "Extended", "Altered",
               "Sus & Add", "Quartal", "Named" }

local TR, S7, EX, AL, SA, QU, NA = 2, 3, 4, 5, 6, 7, 8   -- indices into FAMILIES

M.CHORDS = {
  { sym="maj",  name="Major",                  iv={0,4,7},          fam=TR },
  { sym="m",    name="Minor",                  iv={0,3,7},          fam=TR },
  { sym="dim",  name="Diminished",             iv={0,3,6},          fam=TR },
  { sym="aug",  name="Augmented",              iv={0,4,8},          fam=TR },
  { sym="b5",   name="Flat Five",              iv={0,4,6},          fam=TR },
  { sym="5",    name="Fifth (Power)",          iv={0,7},            fam=TR },

  { sym="6",       name="Sixth",                    iv={0,4,7,9},     fam=S7 },
  { sym="m6",      name="Minor Sixth",              iv={0,3,7,9},     fam=S7 },
  { sym="6/9",     name="Six-Nine",                 iv={0,4,7,9,14},  fam=S7 },
  { sym="m6/9",    name="Minor Six-Nine",           iv={0,3,7,9,14},  fam=S7 },
  { sym="7",       name="Dominant Seventh",         iv={0,4,7,10},    fam=S7 },
  { sym="maj7",    name="Major Seventh",            iv={0,4,7,11},    fam=S7 },
  { sym="m7",      name="Minor Seventh",            iv={0,3,7,10},    fam=S7 },
  { sym="mMaj7",   name="Minor-Major Seventh",      iv={0,3,7,11},    fam=S7 },
  { sym="m7b5",    name="Half-Diminished Seventh",  iv={0,3,6,10},    fam=S7 },
  { sym="dim7",    name="Diminished Seventh",       iv={0,3,6,9},     fam=S7 },
  { sym="7#5",     name="Augmented Seventh",        iv={0,4,8,10},    fam=S7 },
  { sym="maj7#5",  name="Augmented Major Seventh",  iv={0,4,8,11},    fam=S7 },
  { sym="7b5",     name="Seventh Flat Five",        iv={0,4,6,10},    fam=S7 },
  { sym="dimMaj7", name="Diminished Major Seventh", iv={0,3,6,11},    fam=S7 },
  { sym="7/6",     name="Seven Six",                iv={0,4,7,9,10},  fam=S7 },

  { sym="9",     name="Ninth",               iv={0,4,7,10,14},       fam=EX },
  { sym="maj9",  name="Major Ninth",         iv={0,4,7,11,14},       fam=EX },
  { sym="m9",    name="Minor Ninth",         iv={0,3,7,10,14},       fam=EX },
  { sym="mMaj9", name="Minor-Major Ninth",   iv={0,3,7,11,14},       fam=EX },
  { sym="11",    name="Eleventh",            iv={0,4,7,10,14,17},    fam=EX },
  { sym="maj11", name="Major Eleventh",      iv={0,4,7,11,14,17},    fam=EX },
  { sym="m11",   name="Minor Eleventh",      iv={0,3,7,10,14,17},    fam=EX },
  { sym="13",    name="Thirteenth",          iv={0,4,7,10,14,17,21}, fam=EX },
  { sym="maj13", name="Major Thirteenth",    iv={0,4,7,11,14,17,21}, fam=EX },
  { sym="m13",   name="Minor Thirteenth",    iv={0,3,7,10,14,17,21}, fam=EX },

  { sym="7b9",       name="Seventh Flat Nine",             iv={0,4,7,10,13},    fam=AL },
  { sym="7#9",       name="Seventh Sharp Nine",            iv={0,4,7,10,15},    fam=AL },
  { sym="7#11",      name="Seventh Sharp Eleven",          iv={0,4,7,10,18},    fam=AL },
  { sym="7b13",      name="Seventh Flat Thirteen",         iv={0,4,7,10,20},    fam=AL },
  { sym="7#5b9",     name="Seventh Sharp Five Flat Nine",  iv={0,4,8,10,13},    fam=AL },
  { sym="7#5#9",     name="Seventh Sharp Five Sharp Nine", iv={0,4,8,10,15},    fam=AL },
  { sym="7b5b9",     name="Seventh Flat Five Flat Nine",   iv={0,4,6,10,13},    fam=AL },
  { sym="7alt",      name="Altered Dominant",              iv={0,4,8,10,13,15}, fam=AL },
  { sym="13b9",      name="Thirteenth Flat Nine",          iv={0,4,7,10,13,21}, fam=AL },
  { sym="maj7#11",   name="Major Seventh Sharp Eleven",    iv={0,4,7,11,18},    fam=AL },
  { sym="m9b5",      name="Minor Ninth Flat Five",         iv={0,3,6,10,14},    fam=AL },
  { sym="9#5",       name="Ninth Augmented Fifth",         iv={0,4,8,10,14},    fam=AL },
  { sym="9b5",       name="Ninth Flat Fifth",              iv={0,4,6,10,14},    fam=AL },
  { sym="9#11",      name="Augmented Eleventh",            iv={0,4,7,10,14,18}, fam=AL },
  { sym="maj7#5#11", name="Augmented Major Seventh Sharp Eleven", iv={0,4,8,11,18}, fam=AL },
  { sym="13b9b5",    name="Thirteenth Flat Nine Flat Five", iv={0,4,6,10,13,21}, fam=AL },

  { sym="sus2",     name="Suspended Second",             iv={0,2,7},       fam=SA },
  { sym="sus4",     name="Suspended Fourth",             iv={0,5,7},       fam=SA },
  { sym="7sus4",    name="Seventh Suspended Fourth",     iv={0,5,7,10},    fam=SA },
  { sym="9sus4",    name="Ninth Suspended Fourth",       iv={0,5,7,10,14}, fam=SA },
  { sym="maj7sus4", name="Major Seventh Suspended Fourth", iv={0,5,7,11},  fam=SA },
  { sym="add9",     name="Added Ninth",                  iv={0,4,7,14},    fam=SA },
  { sym="m(add9)",  name="Minor Added Ninth",            iv={0,3,7,14},    fam=SA },
  { sym="add4",     name="Added Fourth",                 iv={0,4,5,7},     fam=SA },
  { sym="add11",    name="Added Eleventh",               iv={0,4,7,17},    fam=SA },
  { sym="add13",    name="Added Thirteenth",             iv={0,4,7,21},    fam=SA },
  { sym="add2",     name="Added Second",                 iv={0,2,4,7},     fam=SA },
  { sym="m(add2)",  name="Minor Added Second",           iv={0,2,3,7},     fam=SA },

  { sym="Q4/3",    name="Quartal Triad",       iv={0,5,10},    fam=QU },
  { sym="Q4/4",    name="Quartal Tetrad",      iv={0,5,10,15}, fam=QU },
  { sym="Q5/3",    name="Quintal Triad",       iv={0,7,14},    fam=QU },
  { sym="WT3",     name="Whole-Tone Trichord", iv={0,2,4},     fam=QU },
  { sym="cluster", name="Chromatic Cluster",   iv={0,1,2},     fam=QU },
  { sym="dia-cl",  name="Diatonic Cluster",    iv={0,2,4,5},   fam=QU },

  -- Voiced as they stand rather than reduced to a pitch-class set: the list
  -- gives the Tristan chord as 0 3 6 10, which makes it a half-diminished
  -- seventh and indistinguishable from one.
  { sym="Mystic",    name="Mystic (Scriabin)",   iv={0,6,10,16,21,26}, fam=NA },
  { sym="Petrushka", name="Petrushka",           iv={0,4,6,7,10,13},   fam=NA },
  { sym="Tristan",   name="Tristan",             iv={0,6,10,15},       fam=NA },
  { sym="So What",   name="So What",             iv={0,5,10,15,19},    fam=NA },
  { sym="Dream",     name="Dream",               iv={0,5,6,7},         fam=NA },
  { sym="Vienna",    name="Viennese Trichord",   iv={0,1,6},           fam=NA },
  { sym="Vienna II", name="Viennese Trichord II", iv={0,6,7},          fam=NA },
  { sym="Napoleon",  name="Ode-to-Napoleon",     iv={0,1,4,5,8,9},     fam=NA },
  { sym="Elektra",   name="Elektra",             iv={0,7,9,13,16},     fam=NA },
  { sym="Farben",    name="Farben",              iv={0,8,11,16,21},    fam=NA },
  { sym="It+6",      name="Italian Sixth",       iv={0,4,10},          fam=NA },
  { sym="Fr+6",      name="French Sixth",        iv={0,4,6,10},        fam=NA },
  { sym="Ger+6",     name="German Sixth",        iv={0,4,7,10},        fam=NA },
}



-- The symbol a set of pitch classes goes by, read off the chord tables: the
-- first chord whose notes are exactly these, from this root. "" for a major
-- triad, nil for a set with no name here.
function M.symbolOf(pcs, root)
  local want = {}
  for _, pc in ipairs(pcs) do want[(pc - root) % 12] = true end
  local n = 0
  for _ in pairs(want) do n = n + 1 end
  for _, c in ipairs(M.CHORDS) do
    local have, m = {}, 0
    for _, iv in ipairs(c.iv) do
      if not have[iv % 12] then have[iv % 12] = true; m = m + 1 end
    end
    if m == n then
      local same = true
      for k in pairs(want) do if not have[k] then same = false end end
      if same then return (c.sym == "maj") and "" or c.sym end
    end
  end
  return nil
end

------------------------------------------------------------------------------
-- What the battle pass adds
------------------------------------------------------------------------------

-- The scales a reward may be written in, by name. The common ones come up
-- far more often: a reward should be useful before it is exotic.
M.REWARD_SCALES = {
  { "Major", 30 }, { "Minor", 30 }, { "Dorian", 10 }, { "Mixolydian", 8 },
  { "Harm Minor", 6 }, { "Lydian", 5 }, { "Phrygian", 4 },
}

function M.scaleIndex(name)
  for i, s in ipairs(M.SCALES) do if s.name == name then return i end end
  return nil
end

-- The root index (into M.ROOTS) a key note is usually spelled with: the
-- spelling with the fewest sharps and flats for that scale.
local PREFERRED = { "C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B" }
function M.rootFor(pc)
  local want = PREFERRED[pc % 12 + 1]
  for i, rt in ipairs(M.ROOTS) do if rt.name == want then return i end end
  return 1
end

-- The triad (or seventh) the scale builds on a degree: its root position, its
-- pitch classes root first, and its symbol from the chord table.
function M.degreeChord(key, degree, seventh)
  local root = M.pitch(key, degree)
  local pcs = { root % 12, M.pitch(key, degree + 2) % 12, M.pitch(key, degree + 4) % 12 }
  if seventh then pcs[#pcs + 1] = M.pitch(key, degree + 6) % 12 end
  local name = M.noteName(key, degree)
  local sym = M.symbolOf(pcs, root % 12) or ""
  return { root = root, pcs = pcs, name = name .. sym, numeral = M.degreeNumeral(key, degree) }
end

return M
