--[[ DAW Battle Pass - the loot.

     Pure Lua. Nothing in this file touches REAPER or ImGui: it takes a dice
     function and returns plain tables, so tests/test_loot.lua can make
     thousands of rewards and check every one.

     Everything the pass hands out is made here, on the fly, from word lists
     and musical rules - which is what makes it endless:

       - the rarity ladder, Poor to Mythic (L.RARITY);
       - ideas: song titles, song themes, chord progressions, drum patterns,
         melodies, sound design briefs, challenges, genre fusions, artist
         aliases, lyric openers, arrangements, song seeds and Good Idea
         numbers (L.IDEAS);
       - studio gear in the manner of Diablo: a base, an implicit stat, random
         affixes that name the item, and on Legendary and Mythic gear a power
         (L.makeGear);
       - cosmetics: player titles and banners;
       - coins, XP, tokens and crates, and what a crate holds;
       - the season: its name and the reward on every tier of its track.

     The dice are Midi Variator's generator (Park and Miller's), the same one
     Good Idea uses, so a seed gives the same reward on any Lua. That is what
     lets the season track show its rewards before they are reached: a tier's
     reward is a function of the season and the tier, nothing else.

     Loaded with dofile(...).init(T): it is handed the theory rather than
     finding it, the way the sister repos load their engines.
]]

local L = {}

------------------------------------------------------------------------------
-- The dice
------------------------------------------------------------------------------

function L.random(seed)
  local s = math.floor(math.abs(seed or 1)) % 2147483646 + 1
  local function nextr()
    s = s * 48271 % 2147483647
    return (s - 1) / 2147483646
  end
  for _ = 1, 4 do nextr() end
  return nextr
end

-- A seed from any mix of numbers and strings, so "season 10, tier 37" is
-- always the same dice.
function L.seedOf(...)
  local h = 5381
  for _, v in ipairs({ ... }) do
    local s = tostring(v)
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483629 end
    h = (h * 33 + 7) % 2147483629
  end
  return h + 1
end

local function between(rnd, lo, hi) return lo + math.floor(rnd() * (hi - lo + 1)) end
local function chance(rnd, p) return rnd() < p end
local function pickOne(rnd, list) return list[math.floor(rnd() * #list) + 1] end
local function weighted(rnd, list)       -- list of { weight, value }
  local total = 0
  for _, e in ipairs(list) do total = total + e[1] end
  local x = rnd() * total
  for _, e in ipairs(list) do
    x = x - e[1]
    if x <= 0 then return e[2] end
  end
  return list[#list][2]
end
local function shuffled(rnd, list)
  local t = {}
  for i, v in ipairs(list) do t[i] = v end
  for i = #t, 2, -1 do
    local j = math.floor(rnd() * i) + 1
    t[i], t[j] = t[j], t[i]
  end
  return t
end
L.between, L.chance, L.pickOne, L.weighted, L.shuffled = between, chance, pickOne, weighted, shuffled

-- "a" before a consonant, "an" before a vowel, wherever a word list put it.
local function articles(s)
  return (s:gsub("(%f[%w][Aa]) ([AEIOUaeiou])", "%1n %2"))
end
local function plural(w)
  if w:sub(-1) == "s" then return w end
  if w:sub(-1) == "y" and not w:sub(-2, -2):match("[aeiou]") then return w:sub(1, -2) .. "ies" end
  return w .. "s"
end
L.articles = articles

------------------------------------------------------------------------------
-- Rarity
--
-- The ladder of loot games: Diablo's grey Poor at the bottom, Fortnite's and
-- WoW's Common, Uncommon, Rare, Epic and Legendary, and Mythic on top. The
-- colours are the only saturated colours in the window besides the accent -
-- see docs/COLOUR.md.
------------------------------------------------------------------------------

L.POOR, L.COMMON, L.UNCOMMON, L.RARE, L.EPIC, L.LEGENDARY, L.MYTHIC = 1, 2, 3, 4, 5, 6, 7

L.RARITY = {
  { name = "Poor",      col = 0x8A919CFF, weight = 12,  coins = { 4, 9 },     xp = 15,  sell = 1,   mult = 0.6 },
  { name = "Common",    col = 0xDDE1E7FF, weight = 40,  coins = { 10, 20 },   xp = 30,  sell = 3,   mult = 0.8 },
  { name = "Uncommon",  col = 0x3FCF6EFF, weight = 26,  coins = { 20, 40 },   xp = 60,  sell = 8,   mult = 1.0 },
  { name = "Rare",      col = 0x3D8EFFFF, weight = 14,  coins = { 40, 80 },   xp = 120, sell = 20,  mult = 1.15 },
  { name = "Epic",      col = 0xA45CFFFF, weight = 5.5, coins = { 90, 150 },  xp = 250, sell = 50,  mult = 1.3 },
  { name = "Legendary", col = 0xFF8A1CFF, weight = 2,   coins = { 200, 300 }, xp = 500, sell = 120, mult = 1.5 },
  { name = "Mythic",    col = 0xFF3FA4FF, weight = 0.5, coins = { 500, 750 }, xp = 1000, sell = 300, mult = 1.75 },
}

-- Luck (magic find, in percent) makes each step up the ladder that much
-- likelier, compounding: at +50% luck an Epic is 1.5^3 times as likely.
function L.rollRarity(rnd, minR, maxR, luck)
  minR, maxR = minR or 1, maxR or #L.RARITY
  local f = 1 + math.max(0, luck or 0) / 100
  local list = {}
  for i = minR, maxR do
    local w = L.RARITY[i].weight
    if i >= L.UNCOMMON then w = w * f ^ (i - L.COMMON) end
    if i == L.POOR then w = w / f end
    list[#list + 1] = { w, i }
  end
  return weighted(rnd, list)
end

function L.coinsFor(rnd, r) local c = L.RARITY[r].coins; return between(rnd, c[1], c[2]) end

------------------------------------------------------------------------------
-- Words
------------------------------------------------------------------------------

local ADJ = { "Velvet", "Neon", "Midnight", "Golden", "Broken", "Electric", "Silent",
  "Crystal", "Paper", "Hollow", "Burning", "Frozen", "Lucid", "Wild", "Distant",
  "Fading", "Violet", "Static", "Liquid", "Endless", "Gentle", "Restless", "Secret",
  "Cosmic", "Silver", "Crimson", "Lonely", "Shattered", "Sacred", "Bitter", "Sugar",
  "Digital", "Analog", "Infinite", "Dusty", "Rusty", "Weightless", "Feral", "Tender",
  "Hazy", "Lunar", "Solar", "Phantom", "Glass", "Ivory", "Amber", "Copper",
  "Sleepless", "Borrowed", "Stolen", "Northern", "Tidal", "Holographic", "Vintage",
  "Magnetic", "Scarlet", "Hidden", "Wandering", "Patient", "Reckless", "Quiet",
  "Emerald", "Painted", "Second-hand", "Bulletproof", "Heavy", "Floating", "Kinetic" }

local NOUN = { "Static", "Harbour", "Satellites", "Ghosts", "Horizon", "Mirrors",
  "Thunder", "Echoes", "Gardens", "Rivers", "Skyline", "Heartbeat", "Daydream",
  "Lighthouse", "Avalanche", "Signal", "Motel", "Arcade", "Polaroid", "Cathedral",
  "Voltage", "Paradise", "Wolves", "Embers", "Tides", "Comet", "Orbit", "Monsoon",
  "Velocity", "Labyrinth", "Carousel", "Fever", "Sunrise", "Moonlight", "Freeway",
  "Postcard", "Wildfire", "Nebula", "Gravity", "Lullaby", "Mirage", "Rooftop",
  "Streetlights", "Cassette", "Pulse", "Lantern", "Oasis", "Riot", "Desert",
  "Blossom", "Prism", "Frequency", "Engine", "Window", "Ocean", "Kingdom", "Shadow",
  "Feather", "Siren", "Circuit", "Galaxy", "Fireworks", "Starlight", "Hurricane",
  "Diamonds", "Machines", "Petals", "Overdrive", "Dynamite", "Afterglow", "Silhouette" }

local VERBING = { "Chasing", "Falling", "Running", "Dancing", "Breathing", "Burning",
  "Waiting", "Drifting", "Floating", "Fading", "Calling", "Catching", "Counting",
  "Painting", "Dreaming", "Holding", "Losing", "Building", "Breaking", "Melting",
  "Racing", "Hunting", "Spinning", "Stealing", "Shaking" }

local SUBJECTS = { "the last train home", "a city that never existed",
  "finding an old voicemail", "the summer before everything changed",
  "a robot learning to cry", "leaving your hometown", "dancing alone in the kitchen",
  "a lighthouse keeper's final night", "two strangers on a night bus",
  "the first warm day of spring", "an astronaut missing Earth",
  "a party you weren't invited to", "rain on a tin roof",
  "a friendship that slowly faded", "driving with no destination",
  "the moment before a storm", "a message in a bottle", "insomnia at 4am",
  "a secret garden in the middle of the city", "an arcade closing down for good",
  "falling for someone in a dream", "the ocean at night", "a hero who gave up",
  "growing up too fast", "a letter you never sent", "a festival at the end of the world",
  "a ghost who just wants to dance", "running away to join the circus",
  "a heatwave romance", "an empty shopping mall", "a chase through neon streets",
  "waking up in a different decade", "the quiet after an argument",
  "a sunrise you watched with friends", "a dragon guarding a vinyl collection",
  "the last song at a wedding", "a phone call from your future self",
  "a road trip in a car that keeps breaking down", "being the only one awake",
  "a snow day when you were a kid", "a rivalry between two DJs",
  "the view from the top of a ferris wheel", "a time machine with one trip left",
  "a postcard from somewhere you've never been", "a band playing as the ship sinks" }

local MOODS = { "bittersweet", "euphoric", "nostalgic", "anxious", "triumphant",
  "dreamy", "menacing", "playful", "melancholic", "hopeful", "defiant", "serene",
  "mysterious", "chaotic", "tender", "cinematic", "haunting", "carefree", "smug",
  "desperate", "warm", "icy", "feverish", "lazy", "heroic" }

local SETTINGS = { "in a rainy Tokyo alley", "on a beach at 3am",
  "inside a 1980s video game", "on a space station orbiting Jupiter",
  "in a laundrette at midnight", "on the last day of school",
  "in a desert motel", "on a frozen lake", "in a crowded underground station",
  "at a village fete", "in a lighthouse during a storm", "in a forgotten ballroom",
  "on a night ferry", "in a greenhouse full of strange plants", "on a rooftop in July",
  "at the edge of a volcano", "inside a snow globe", "in a 24-hour diner" }

local NARRATORS = { "the moon", "a stray cat", "a retired superhero", "the car radio",
  "the last person on Earth", "a lighthouse", "your younger self", "a houseplant",
  "a ghost", "the villain", "an old jukebox", "a satellite", "the ocean" }

local TWISTS = { "it was a dream all along", "the narrator is the villain",
  "the final chorus is sung by someone else", "the love song is about a city",
  "the happy melody hides sad lyrics", "everything happens backwards",
  "the bridge reveals it was a goodbye", "the last line answers the first",
  "the drop never comes", "it ends in a completely different key" }

local INSTRUMENTS = { "pad", "pluck", "bass", "lead", "bell", "arp", "drone", "riser",
  "impact", "texture", "kick", "snare", "hi-hat", "vocal chop", "stab", "sub bass",
  "keys", "string section", "brass stab", "choir", "reese bass", "FX sweep" }

local IMAGES = { "a frozen lake cracking", "sunlight through stained glass",
  "a broken music box", "whale song underwater", "neon buzzing in the rain",
  "an old VHS tape", "a spaceship engine idling", "wind through a canyon",
  "a heartbeat in a cathedral", "melting chocolate", "a swarm of fireflies",
  "a vintage radio between stations", "a giant's footsteps", "glass marbles on concrete",
  "a sleepy cat's purr", "an alarm in a dream", "steam from a kettle",
  "a distant thunderstorm", "a slot machine jackpot", "velvet curtains",
  "a jellyfish glowing", "a rusty swing", "a robot sighing", "a library at night" }

local LIMITS = { "a single oscillator", "only a sine wave", "only stock REAPER plugins",
  "one sample you record on your phone", "no more than three plugins",
  "only white noise as the source", "only your own voice", "only kitchen sounds",
  "a synth's init preset as the starting point", "nothing but EQ and distortion",
  "a field recording from outside your window" }

local MODULATIONS = { "an LFO synced to dotted eighths", "velocity", "the mod wheel",
  "a slow random LFO", "an envelope on the filter", "sidechain from the kick",
  "automation drawn by hand", "an arpeggiator", "a step sequencer" }

local CONSTRAINTS = { "Use only four tracks", "No reverb allowed",
  "Every track must be panned hard left or hard right", "Use a time signature other than 4/4",
  "No hi-hats", "Write the bassline first", "Use a sample of a household object",
  "Only use one synth for everything", "Change key halfway through",
  "Keep the tempo under 80 BPM", "Keep the tempo over 160 BPM", "No quantising",
  "Use a field recording", "Only minor chords", "Write the melody with only three notes",
  "Reverse something important", "Every section is exactly 8 bars",
  "No drums for the first minute", "Record something live", "Use only stock REAPER plugins",
  "Make a vocal chop the lead", "Sidechain everything to the kick", "Start with the outro",
  "Make the bass the loudest thing", "Use a polyrhythm", "Mono only - no stereo widening",
  "Use an instrument you've never used", "No EQ allowed", "Use 7/8 time",
  "Every sound must be pitched", "Silence is an instrument: use a full bar of it",
  "The chorus has no drums", "Use only one chord" }

local GENRES = { "Lo-fi Hip Hop", "Drum & Bass", "Synthwave", "Bossa Nova", "Trap",
  "Baroque", "Afrobeats", "Shoegaze", "Techno", "Funk", "Disco", "Jazz Fusion",
  "Reggaeton", "Dubstep", "Ambient", "Grunge", "City Pop", "Gospel", "Hyperpop",
  "Country", "K-Pop", "Flamenco", "UK Garage", "Phonk", "Vaporwave", "Chiptune",
  "Bluegrass", "Metal", "House", "Soul", "Dancehall", "Jungle", "Trip Hop",
  "Post-Rock", "Bollywood", "Sea Shanty", "Orchestral", "Garage Rock", "Amapiano",
  "Jersey Club", "Drill", "Psytrance", "Neo-Soul", "Surf Rock", "Celtic", "Gamelan",
  "Dub", "Grime", "Emo", "Film Noir Jazz", "Spaghetti Western", "Trance" }

local OCCASIONS = { "a villain's entrance", "a montage of getting stronger",
  "a heist going wrong", "the end credits", "a 3am drive", "a rooftop party",
  "a boss fight", "a slow-motion goodbye", "a sunrise yoga class", "a chase scene" }

local LYRIC_LINES = {
  "I left my %n at the %p", "We were %a like %s", "Every %t I %v your %n",
  "Don't call me when the %n %vs", "Tell me why the %n still %vs",
  "You and me and the %a %n", "Somewhere between the %n and the %n",
  "I kept your %n in a %a box", "We drove all night to find the %n",
  "Nobody told me the %n would %v", "Under the %a %n we %vd",
  "I've been %ving since the %n went out", "Turn up the %n, I can't hear the %n" }
-- Singular, so "the %n still %vs" agrees with itself.
local LYRIC_NOUNS = { "harbour", "satellite", "horizon", "mirror", "heartbeat", "daydream",
  "lighthouse", "signal", "motel", "arcade", "polaroid", "cathedral", "comet", "carousel",
  "sunrise", "freeway", "postcard", "wildfire", "lullaby", "rooftop", "cassette", "lantern",
  "radio", "streetlight", "ocean", "kingdom", "shadow", "feather", "siren", "galaxy", "engine" }
local LYRIC_PLACES = { "station", "party", "end of the road", "edge of town", "bottom of the sea",
  "back of the bus", "top of the world", "corner shop", "last chance saloon", "door" }
local SIMILES = { "neon in the rain", "kids on a sugar rush", "satellites in love",
  "fireworks in winter", "strangers at a wedding", "ghosts at a disco",
  "candles in a hurricane", "records on repeat" }
local VERBS = { { "glow", "glows", "glowed", "glowing" }, { "break", "breaks", "broke", "breaking" },
  { "sing", "sings", "sang", "singing" }, { "wait", "waits", "waited", "waiting" },
  { "burn", "burns", "burned", "burning" }, { "fall", "falls", "fell", "falling" },
  { "shine", "shines", "shone", "shining" }, { "fade", "fades", "faded", "fading" },
  { "run", "runs", "ran", "running" }, { "dance", "dances", "danced", "dancing" } }
local TIMES = { "night", "summer", "morning", "winter", "weekend", "December", "Sunday" }

local ALIAS_PATTERNS = { "%A %N", "DJ %N", "Lil %N", "The %A %P", "%N & The %P",
  "MC %A", "%N Collective", "%A%n", "Club %N", "%N Theory", "Sister %N", "Kid %N" }

local TITLE_ADJ = { "Cosmic", "Supreme", "Midnight", "Funky", "Certified", "Grand",
  "Turbo", "Mystic", "Undisputed", "Feral", "Golden", "Elusive", "Chaotic", "Serene",
  "Iron", "Velvet", "Low-End", "Hi-Fi", "Lo-Fi", "Analogue", "Quantised", "Unquantised",
  "Sleepless", "Legendary", "Tireless", "Humble", "Infamous", "Wandering" }
local TITLE_ROLE = { "Beatsmith", "Loop Alchemist", "Knob Twister", "Groove Wizard",
  "Sample Pirate", "Bass Baron", "Synth Sorcerer", "Mix Monk", "Chord Captain",
  "Fader Ninja", "Snare Whisperer", "Reverb Druid", "Tempo Titan", "Hook Hunter",
  "Riff Ranger", "Sidechain Sultan", "Drum Shaman", "Arp Architect", "Vocal Viking",
  "Melody Merchant", "Patch Sculptor", "Groove Gardener", "Noise Knight" }
local TITLE_OF = { "the Night", "the Low End", "the Infinite Loop", "the Final Mixdown",
  "the Golden Ratio", "the Eighth Note", "the Last Bar", "Many Plugins", "the Downbeat",
  "the Big Room", "the Upside Down", "the Sustain Pedal" }

local COLOUR_WORDS = { "Neon", "Midnight", "Solar", "Arctic", "Toxic", "Royal", "Sunset",
  "Deep", "Electric", "Cyber", "Pastel", "Molten", "Velvet", "Retro", "Lunar", "Ember" }
local BANNER_THINGS = { "Lion", "Comet", "Fox", "Wave", "Crown", "Serpent", "Phoenix",
  "Owl", "Wolf", "Tiger", "Moth", "Crow", "Stag", "Kraken", "Dragon", "Meteor" }

-- Syllables for the made-up names Legendary and Mythic gear carries.
local SYL_A = { "Kal", "Mor", "Ae", "Vel", "Zan", "Or", "Thal", "Ys", "Bel", "Cor",
  "Dra", "Ely", "Fen", "Gal", "Hal", "Ith", "Jor", "Lys", "Nyx", "Quin", "Ser", "Tor" }
local SYL_B = { "dor", "ion", "ara", "eth", "iel", "os", "an", "ix", "umb", "ira",
  "ond", "ael", "ash", "or", "ys", "ene", "ul", "ath" }
local EPITHETS = { "Breaker of Silence", "Keeper of the Groove", "the Unquantised",
  "Voice of the Void", "Bringer of Drops", "the Eternal Loop", "Heart of the Mix",
  "the Last Encore", "Lord of Low End", "the Golden Ear", "Herald of the Hook" }

L.WORDS = { ADJ = ADJ, NOUN = NOUN, GENRES = GENRES, CONSTRAINTS = CONSTRAINTS }

local function madeUpName(rnd)
  local n = pickOne(rnd, SYL_A) .. pickOne(rnd, SYL_B)
  if chance(rnd, 0.3) then n = n .. pickOne(rnd, SYL_B) end
  return n
end

------------------------------------------------------------------------------
-- Ideas
--
-- Each kind makes { text, sub, data } for a rarity. A rarer idea is a richer
-- one: more chords, sevenths, borrowed chords, more bars, more parts to the
-- brief. Poor ideas are the grey junk of the loot table, and know it.
------------------------------------------------------------------------------

local IDEAS = {}
L.IDEAS = IDEAS

local function idea(def) IDEAS[#IDEAS + 1] = def; IDEAS[def.id] = def end

idea { id = "title", label = "Song Title", icon = "note", weight = 9,
  make = function(rnd, r)
    if r == L.POOR then
      return { text = "Untitled " .. pickOne(rnd, { "Beat", "Project", "Loop", "Idea" }) .. " " .. between(rnd, 2, 99),
               sub = "A song title. Technically." }
    end
    local t
    local pat = between(rnd, 1, math.min(r, 6))
    if pat <= 2 then
      t = chance(rnd, 0.6) and (pickOne(rnd, ADJ) .. " " .. pickOne(rnd, NOUN))
          or (pickOne(rnd, NOUN) .. " " .. pickOne(rnd, NOUN))
    elseif pat == 3 then t = pickOne(rnd, VERBING) .. " " .. pickOne(rnd, NOUN)
    elseif pat == 4 then t = pickOne(rnd, NOUN) .. " of " .. pickOne(rnd, NOUN)
    elseif pat == 5 then t = "The " .. pickOne(rnd, ADJ) .. " " .. pickOne(rnd, NOUN)
    else t = pickOne(rnd, ADJ) .. " " .. pickOne(rnd, NOUN) .. " " .. pickOne(rnd, NOUN) end
    local sub = "A song title"
    if r >= L.LEGENDARY then sub = "B-side: " .. pickOne(rnd, ADJ) .. " " .. pickOne(rnd, NOUN) end
    if r == L.MYTHIC then sub = "Album: " .. pickOne(rnd, NOUN) .. " " .. pickOne(rnd, NOUN) .. "  /  " .. sub end
    return { text = t, sub = sub }
  end }

idea { id = "theme", label = "Song Theme", icon = "bulb", weight = 8,
  make = function(rnd, r)
    if r == L.POOR then return { text = "A song about making a song.", sub = "Very meta. Very grey." } end
    local mood = pickOne(rnd, MOODS)
    local t = (r >= L.UNCOMMON and ("A " .. mood .. " song about ") or "A song about ") .. pickOne(rnd, SUBJECTS) .. "."
    local sub = {}
    if r < L.UNCOMMON then sub[#sub + 1] = "Mood: " .. mood end
    if r >= L.RARE then sub[#sub + 1] = "Set " .. pickOne(rnd, SETTINGS) end
    if r >= L.EPIC then sub[#sub + 1] = "Told by " .. pickOne(rnd, NARRATORS) end
    if r >= L.LEGENDARY then sub[#sub + 1] = "Twist: " .. pickOne(rnd, TWISTS) end
    if r >= L.MYTHIC then sub[#sub + 1] = "Title: " .. pickOne(rnd, ADJ) .. " " .. pickOne(rnd, NOUN) end
    return { text = articles(t), sub = table.concat(sub, ". ") }
  end }

-- Chords ---------------------------------------------------------------------

-- Progressions by 0-based degree, the ones everyone knows first.
local MAJOR_PROGS = { { 0, 4, 5, 3 }, { 5, 3, 0, 4 }, { 0, 5, 3, 4 }, { 1, 4, 0, 0 },
  { 0, 3, 5, 4 }, { 0, 2, 3, 3 }, { 3, 0, 4, 5 }, { 0, 4, 3, 3 }, { 0, 3, 0, 4 },
  { 5, 4, 3, 4 }, { 0, 1, 3, 0 }, { 3, 4, 2, 5 } }
local MINOR_PROGS = { { 0, 5, 2, 6 }, { 0, 3, 6, 2 }, { 0, 6, 5, 6 }, { 0, 5, 6, 0 },
  { 0, 3, 4, 0 }, { 0, 2, 6, 5 }, { 3, 5, 0, 6 }, { 0, 6, 5, 4 }, { 0, 3, 0, 4 } }
-- Which degree may follow which: tonic anywhere, predominants to dominants,
-- dominants home. The walk for rarer progressions, so they are still music.
local NEXT = { [0] = { 3, 4, 5, 1, 2 }, [1] = { 4, 6, 3 }, [2] = { 5, 3, 1 },
  [3] = { 4, 0, 1, 6 }, [4] = { 0, 5, 3 }, [5] = { 1, 3, 4, 2 }, [6] = { 0, 2, 5 } }

local LETTER_PC = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
local LETTER_ORDER = { "C", "D", "E", "F", "G", "A", "B" }
-- A pitch class spelled on a given letter: the fifth above D is A, the fifth
-- above Bb is F, and a V/V in Eb is F7, not E#7.
local function spell(letter, pc)
  local acc = (pc - LETTER_PC[letter]) % 12
  if acc > 6 then acc = acc - 12 end
  -- A double flat or sharp is right by the letter and wrong for a reader.
  if acc < -1 or acc > 1 then return L.T.ROOTS[L.T.rootFor(pc)].name end
  return letter .. (acc == -1 and "b" or (acc == 1 and "#" or ""))
end
local function letterUp(letter, steps)
  for i, l in ipairs(LETTER_ORDER) do
    if l == letter then return LETTER_ORDER[(i - 1 + steps) % 7 + 1] end
  end
  return letter
end

local function chordSym(pcs, root)
  return L.T.symbolOf(pcs, root) or ""
end

-- Close voicings around middle C, each chord the inversion nearest the last.
local function voice(pcs, prevMean)
  local best, bestCost
  for inv = 0, #pcs - 1 do
    local notes, last = {}, nil
    for i = 0, #pcs - 1 do
      local pc = pcs[(inv + i) % #pcs + 1]
      local p = 48 + pc
      while last and p <= last do p = p + 12 end
      while not last and p < 52 do p = p + 12 end
      notes[#notes + 1] = p
      last = p
    end
    local mean = 0
    for _, p in ipairs(notes) do mean = mean + p end
    mean = mean / #notes
    local cost = math.abs(mean - (prevMean or 62))
    if notes[#notes] > 79 then cost = cost + 20 end
    if not bestCost or cost < bestCost then best, bestCost = notes, cost end
  end
  local mean = 0
  for _, p in ipairs(best) do mean = mean + p end
  return best, mean / #best
end

-- A key on a pitch class, spelled the way that gives its scale the fewest
-- sharps and flats - Good Idea's rule (T.transpose there): Ab Phrygian
-- would need Bbb and Fb, so it is G# Phrygian.
local function keyFor(pc, scaleIdx)
  local T = L.T
  local best, bestCost
  for i, rt in ipairs(T.ROOTS) do
    local k = T.key(i, scaleIdx)
    if T.rootPc(k) == pc % 12 then
      local cost = 0
      for pos = 0, T.scaleLen(k) - 1 do
        local name = T.noteName(k, pos)
        cost = cost + #name - 1
        if name:find("bb") or name:find("x") then cost = cost + 10 end
      end
      if not bestCost or cost < bestCost then best, bestCost = k, cost end
    end
  end
  return best
end
L.keyFor = keyFor

local function scaleByWeight(rnd, r)
  if r <= L.COMMON then return pickOne(rnd, { "Major", "Minor" }) end
  return weighted(rnd, (function()
    local t = {}
    for _, s in ipairs(L.T.REWARD_SCALES) do t[#t + 1] = { s[2], s[1] } end
    return t
  end)())
end

function L.progression(rnd, r)
  local T = L.T
  local scaleName = scaleByWeight(rnd, r)
  local key = keyFor(between(rnd, 0, 11), T.scaleIndex(scaleName))
  local minorish = T.degreeQuality(key, 0) == "minor"
  local count = (r >= L.LEGENDARY) and 8 or ((r >= L.EPIC) and 6 or 4)
  local degrees = {}
  if r <= L.UNCOMMON or chance(rnd, 0.5) then
    local base = pickOne(rnd, minorish and MINOR_PROGS or MAJOR_PROGS)
    if r == L.POOR then base = minorish and { 0, 3, 4, 0 } or { 0, 3, 4, 0 } end
    for i = 1, count do degrees[i] = base[(i - 1) % 4 + 1] end
    if count > 4 then degrees[count] = 0; degrees[count - 1] = 4 end
  else
    degrees[1] = 0
    for i = 2, count do degrees[i] = pickOne(rnd, NEXT[degrees[i - 1]]) end
    degrees[count - 1] = (degrees[count - 2] == 4) and 3 or 4
    degrees[count] = 0
  end
  local sevenths = r >= L.EPIC or (r == L.RARE and chance(rnd, 0.5))
  local chords = {}
  for i, d in ipairs(degrees) do
    local c = T.degreeChord(key, d, sevenths or (r == L.UNCOMMON and d == 4))
    c.degree = d
    chords[i] = c
  end
  -- Borrowed from the parallel key: the iv, bVI and bVII in major, the major
  -- IV and V in minor. Never the first chord or the last.
  if r >= L.EPIC and T.scaleLen(key) == 7 then
    local parallel = T.key(key.root, T.scaleIndex(minorish and "Major" or "Minor"))
    local tries = minorish and { 3, 4 } or { 3, 5, 6 }
    local slot = between(rnd, 2, count - 1)
    local d = pickOne(rnd, tries)
    local c = T.degreeChord(parallel, d, sevenths)
    local diatonic = T.pitch(key, d) % 12
    local acc = ""
    if (c.root % 12) ~= diatonic then acc = ((c.root - diatonic) % 12 == 11) and "b" or "#" end
    c.numeral = acc .. T.degreeNumeral(parallel, d)
    if c.name:find("bb") or c.name:find("x") then
      -- Db major's bVI is Bbb by the letter; nobody reads it that way.
      c.name = T.ROOTS[T.rootFor(c.root % 12)].name .. (c.name:gsub("^[A-G][#bx]*", ""))
    end
    c.borrowed = true
    c.degree = d
    chords[slot] = c
  end
  -- A secondary dominant: the chord before a major or minor chord becomes its
  -- V7, spelled a fifth up on the letter.
  if r >= L.LEGENDARY then
    for i = 3, count - 1 do
      local target = chords[i]
      if not target.borrowed and target.degree ~= 0 and not chords[i - 1].borrowed
         and T.degreeQuality(key, target.degree) ~= "diminished" then
        local rootPc = (target.root + 7) % 12
        local letter = letterUp(target.name:sub(1, 1), 4)
        local pcs = { rootPc, (rootPc + 4) % 12, (rootPc + 7) % 12, (rootPc + 10) % 12 }
        chords[i - 1] = { root = rootPc, pcs = pcs, name = spell(letter, rootPc) .. "7",
                          numeral = "V7/" .. target.numeral, applied = true, degree = -1 }
        break
      end
    end
  end
  -- Colour: an add9 or a sus on a plain major triad.
  if r >= L.LEGENDARY then
    for i = 2, count - 1 do
      local c = chords[i]
      if #c.pcs == 3 and not c.applied and chance(rnd, 0.35) then
        local third = (c.pcs[2] - c.pcs[1]) % 12
        if third == 4 then
          local sus = chance(rnd, 0.5)
          local pcs = sus and { c.pcs[1], (c.pcs[1] + 5) % 12, c.pcs[3] } or { c.pcs[1], c.pcs[2], c.pcs[3], (c.pcs[1] + 2) % 12 }
          local letterName = c.name:match("^[A-G][#bx]*")
          chords[i] = { root = c.root, pcs = pcs, name = letterName .. (sus and "sus4" or "add9"),
                        numeral = c.numeral .. (sus and "sus4" or "add9"), degree = c.degree, borrowed = c.borrowed }
        end
      end
    end
  end
  -- Mythic: the second half goes up a whole step.
  local modulated = false
  if r == L.MYTHIC then
    modulated = true
    local half = count / 2
    for i = half + 1, count do
      local c = chords[i]
      local pcs = {}
      for j, pc in ipairs(c.pcs) do pcs[j] = (pc + 2) % 12 end
      local letterName = c.name:match("^([A-G])")
      local rest = c.name:gsub("^[A-G][#bx]*", "")
      chords[i] = { root = (c.root + 2) % 12, pcs = pcs, name = spell(letterUp(letterName, 1), (c.root + 2) % 12) .. rest,
                    numeral = c.numeral, degree = c.degree, lifted = true }
    end
  end
  for _, c in ipairs(chords) do c.sym = chordSym(c.pcs, c.pcs[1]) end
  return { key = key, keyName = T.noteName(key, 0) .. " " .. T.SCALES[key.scale].name,
           chords = chords, modulated = modulated }
end

local function progressionBlock(p, name)
  local notes, prevMean = {}, nil
  for i, c in ipairs(p.chords) do
    local s = (i - 1) * 4
    local vs
    vs, prevMean = voice(c.pcs, prevMean)
    for _, pitch in ipairs(vs) do notes[#notes + 1] = { start = s, len = 4, pitch = pitch, vel = 90 } end
    notes[#notes + 1] = { start = s, len = 4, pitch = 36 + (c.root % 12), vel = 100 }
  end
  return { name = name, beats = #p.chords * 4, notes = notes }
end

idea { id = "chords", label = "Chord Progression", icon = "keys", weight = 9, midi = true,
  make = function(rnd, r)
    local p = L.progression(rnd, r)
    local names, nums = {}, {}
    for i, c in ipairs(p.chords) do names[i] = c.name; nums[i] = c.numeral end
    local sub = p.keyName .. "  /  " .. table.concat(nums, " - ")
    if p.modulated then sub = sub .. "  (up a tone halfway)" end
    if r == L.POOR then sub = sub .. "  /  A classic. Some say too classic." end
    return { text = table.concat(names, " - "), sub = sub,
             data = { block = progressionBlock(p, "Chords: " .. table.concat(names, " ")) } }
  end }

-- Drums ----------------------------------------------------------------------

local GM = { kick = 36, rim = 37, snare = 38, clap = 39, chh = 42, ohh = 46, ltom = 45,
             htom = 50, crash = 49, ride = 51, cowbell = 56, shaker = 70 }

-- Sixteen steps a bar: x is a hit, o a ghost (soft) hit.
local DRUM_STYLES = {
  { name = "House", bpm = { 120, 128 }, swing = 0, rows = {
      kick = "x...x...x...x...", clap = "....x.......x...", chh = "..x...x...x...x.", ohh = "......x.......x." } },
  { name = "Boom Bap", bpm = { 84, 96 }, swing = 58, rows = {
      kick = "x......x..x.....", snare = "....x.......x...", chh = "x.x.x.x.x.x.x.x." } },
  { name = "Trap", bpm = { 130, 150 }, swing = 0, rows = {
      kick = "x......x..x....x", snare = "........x.......", chh = "x.xxx.x.x.xxx.xx" } },
  { name = "Drum & Bass", bpm = { 170, 176 }, swing = 0, rows = {
      kick = "x.........x.....", snare = "....x.......x...", chh = "x.x.x.x.x.x.x.x." } },
  { name = "Reggaeton", bpm = { 90, 100 }, swing = 0, rows = {
      kick = "x...x...x...x...", snare = "...x..x....x..x.", chh = "x.x.x.x.x.x.x.x." } },
  { name = "Lo-fi", bpm = { 70, 88 }, swing = 62, rows = {
      kick = "x..x......x.....", snare = "....x.......x...", chh = "x.x.x.x.x.x.x.x.", rim = "..........o....." } },
  { name = "Techno", bpm = { 128, 140 }, swing = 0, rows = {
      kick = "x...x...x...x...", clap = "....x.......x...", chh = "xxxxxxxxxxxxxxxx", ohh = "..x...x...x...x." } },
  { name = "Funk", bpm = { 98, 112 }, swing = 54, rows = {
      kick = "x.x.......x..x..", snare = "....x..o.o..x..o", chh = "x.x.x.x.x.x.x.x." } },
  { name = "UK Garage", bpm = { 130, 136 }, swing = 66, rows = {
      kick = "x.........x.....", snare = "....x.......x...", chh = "..x...x...x...xx", rim = ".......o......o." } },
  { name = "Afrobeats", bpm = { 100, 112 }, swing = 55, rows = {
      kick = "x..x..x...x..x..", rim = "...x..x....x..x.", shaker = "xxxxxxxxxxxxxxxx", clap = "....x.......x..." } },
}
L.DRUM_STYLES = DRUM_STYLES
local ROW_ORDER = { "kick", "snare", "clap", "rim", "chh", "ohh", "shaker", "cowbell", "ltom", "htom", "crash", "ride" }
local ROW_NAMES = { kick = "Kick", snare = "Snare", clap = "Clap", rim = "Rim", chh = "Hat", ohh = "Open hat",
  shaker = "Shaker", cowbell = "Cowbell", ltom = "Low tom", htom = "High tom", crash = "Crash", ride = "Ride" }

function L.drumPattern(rnd, r)
  local style = pickOne(rnd, DRUM_STYLES)
  local bars = (r >= L.LEGENDARY) and 4 or ((r >= L.EPIC) and 2 or 1)
  local steps = bars * 16
  local rows = {}
  local function row(id)
    if not rows[id] then rows[id] = {}; for i = 1, steps do rows[id][i] = 0 end end
    return rows[id]
  end
  for id, s in pairs(style.rows) do
    local rr = row(id)
    for b = 0, bars - 1 do
      for i = 1, 16 do
        local ch = s:sub(i, i)
        if ch == "x" then rr[b * 16 + i] = (i % 4 == 1) and 110 or 96
        elseif ch == "o" then rr[b * 16 + i] = 50 end
      end
    end
  end
  -- Variations, more of them the rarer the pattern.
  local changes = ({ 0, 1, 2, 3, 4, 5, 6 })[r]
  for _ = 1, changes do
    local what = between(rnd, 1, 4)
    local i = between(rnd, 1, steps)
    if what == 1 then row("kick")[i] = (row("kick")[i] > 0 and i % 16 ~= 1) and 0 or 92
    elseif what == 2 and rows.snare then if rows.snare[i] == 0 then rows.snare[i] = 45 end
    elseif what == 3 and rows.chh then rows.chh[i] = (rows.chh[i] > 0) and 0 or 70
    else row("ohh")[i] = (i % 2 == 1) and 0 or 85 end
  end
  if r >= L.EPIC then
    -- A fill at the end of the last bar, and a crash on the way back in.
    local t = row(chance(rnd, 0.5) and "htom" or "snare")
    local lt = row("ltom")
    for i = steps - 3, steps do
      if rows.kick then rows.kick[i] = 0 end
      if i % 2 == 0 then t[i] = 100 else lt[i] = 100 end
    end
    row("crash")[1] = 115
  end
  if r >= L.MYTHIC then
    -- Three against four: a cowbell every three sixteenths.
    local cb = row("cowbell")
    for i = 1, steps, 3 do cb[i] = 80 end
  end
  local bpm = between(rnd, style.bpm[1], style.bpm[2])
  local list = {}
  for _, id in ipairs(ROW_ORDER) do
    if rows[id] then
      local any = false
      for i = 1, steps do if rows[id][i] > 0 then any = true end end
      if any then list[#list + 1] = { id = id, name = ROW_NAMES[id], note = GM[id], steps = rows[id] } end
    end
  end
  return { style = style.name, bpm = bpm, bars = bars, steps = steps, swing = style.swing, rows = list }
end

function L.drumBlock(p, name)
  local notes = {}
  for _, row in ipairs(p.rows) do
    for i, v in ipairs(row.steps) do
      if v > 0 then
        local pairStart = math.floor((i - 1) / 2) * 0.5
        local start = (i % 2 == 1) and pairStart
                      or (pairStart + 0.5 * (p.swing > 0 and p.swing / 100 or 0.5))
        -- A swung last sixteenth is shortened to end with the pattern.
        local len = math.min(0.2, p.bars * 4 - start)
        notes[#notes + 1] = { start = start, len = len, pitch = row.note, vel = v }
      end
    end
  end
  return { name = name, beats = p.bars * 4, notes = notes }
end

function L.drumText(p)
  local lines = {}
  for _, row in ipairs(p.rows) do
    local s = {}
    for i = 1, math.min(16, p.steps) do s[i] = row.steps[i] > 60 and "x" or (row.steps[i] > 0 and "o" or ".") end
    lines[#lines + 1] = string.format("%-8s %s", row.name, table.concat(s))
  end
  return table.concat(lines, "\n")
end

idea { id = "drums", label = "Drum Pattern", icon = "drum", weight = 7, midi = true,
  make = function(rnd, r)
    local p = L.drumPattern(rnd, r)
    local sub = string.format("%d BPM  /  %d bar%s%s", p.bpm, p.bars, p.bars > 1 and "s" or "",
                              p.swing > 0 and ("  /  swing " .. p.swing .. "%") or "")
    if r == L.POOR then sub = sub .. "  /  It's a beat." end
    return { text = p.style .. " beat", sub = sub,
             data = { drums = p, block = L.drumBlock(p, "Drums: " .. p.style), text = L.drumText(p), bpm = p.bpm } }
  end }

-- Melody ---------------------------------------------------------------------

local CELLS = { { 4 }, { 2, 2 }, { 3, 1 }, { 1, 1, 2 }, { 2, 1, 1 }, { 2, 2 }, { -2, 2 }, { 1, 1, 1, 1 }, { 4 }, { 6, 2 }, { 8 } }
local STEPS = { { 1, 0 }, { 7, 1 }, { 7, -1 }, { 3, 2 }, { 3, -2 }, { 1, 3 }, { 1, -3 }, { 1, 4 }, { 1, -4 } }

function L.melody(rnd, r)
  local T = L.T
  local scaleName = (r <= L.COMMON) and pickOne(rnd, { "Maj Pent", "Min Pent" }) or scaleByWeight(rnd, r)
  local key = keyFor(between(rnd, 0, 11), T.scaleIndex(scaleName))
  local n = T.scaleLen(key)
  local bars = (r >= L.EPIC) and 4 or ((r >= L.UNCOMMON) and 2 or 1)
  local base = 5 * n     -- the root in the octave of middle C
  local notes, t, pos = {}, 0, pickOne(rnd, { 0, 2, 4 }) % n
  local function phrase(len)
    local out, at = {}, 0
    while at < len do
      local cell = pickOne(rnd, CELLS)
      local total = 0
      for _, d in ipairs(cell) do total = total + math.abs(d) end
      if at + total > len then cell = { len - at } end
      for _, d in ipairs(cell) do
        if d > 0 then
          out[#out + 1] = { s = at, l = d, pos = pos }
          pos = math.max(-2, math.min(n + 4, pos + weighted(rnd, STEPS)))
        end
        at = at + math.abs(d)
      end
    end
    return out
  end
  local first = phrase(math.min(bars, 2) * 16)
  for _, x in ipairs(first) do notes[#notes + 1] = x end
  if bars == 4 then
    -- Call and answer: the second half starts like the first and ends home.
    for i, x in ipairs(first) do
      if x.s < 16 then notes[#notes + 1] = { s = x.s + 32, l = x.l, pos = x.pos }
      else notes[#notes + 1] = { s = x.s + 32, l = x.l, pos = (i % 2 == 0) and x.pos + 1 or x.pos } end
    end
  end
  table.sort(notes, function(a, b) return a.s < b.s end)
  -- End on the key note, held.
  local last = notes[#notes]
  last.pos = (last.pos >= n / 2) and n or 0
  t = 0
  local names, block = {}, {}
  local barNames = {}
  for _, x in ipairs(notes) do
    local bar = math.floor(x.s / 16) + 1
    barNames[bar] = barNames[bar] or {}
    table.insert(barNames[bar], T.noteName(key, x.pos % n))
    block[#block + 1] = { start = x.s / 4, len = x.l / 4 * 0.95, pitch = T.pitch(key, base + x.pos), vel = 100 }
  end
  for b = 1, bars do names[#names + 1] = table.concat(barNames[b] or { "-" }, " ") end
  return { key = key, keyName = T.noteName(key, 0) .. " " .. T.SCALES[key.scale].name,
           bars = bars, text = table.concat(names, " | "), notes = block }
end

idea { id = "melody", label = "Melody", icon = "wave", weight = 7, midi = true,
  make = function(rnd, r)
    local m = L.melody(rnd, r)
    local sub = m.keyName .. "  /  " .. m.bars .. " bar" .. (m.bars > 1 and "s" or "")
    return { text = m.text, sub = sub,
             data = { block = { name = "Melody: " .. m.keyName, beats = m.bars * 4, notes = m.notes } } }
  end }

-- Words ----------------------------------------------------------------------

idea { id = "sound", label = "Sound Design Brief", icon = "dial", weight = 6,
  make = function(rnd, r)
    local t = articles("Design a " .. pickOne(rnd, INSTRUMENTS) .. " that sounds like " .. pickOne(rnd, IMAGES) .. ".")
    local sub = {}
    if r >= L.RARE then sub[#sub + 1] = "Use " .. pickOne(rnd, LIMITS) end
    if r >= L.EPIC then sub[#sub + 1] = "Modulate it with " .. pickOne(rnd, MODULATIONS) end
    if r >= L.MYTHIC then sub[#sub + 1] = "Make it evolve over 16 bars" end
    if r == L.POOR then sub[#sub + 1] = "Or just pick a preset. No judgement." end
    return { text = t, sub = table.concat(sub, ". ") }
  end }

idea { id = "challenge", label = "Challenge", icon = "flag", weight = 6,
  make = function(rnd, r)
    local n = (r >= L.LEGENDARY) and 3 or ((r >= L.RARE) and 2 or 1)
    local picks = shuffled(rnd, CONSTRAINTS)
    local list = {}
    for i = 1, n do list[i] = picks[i] end
    local sub = (r >= L.EPIC) and ("Finish a loop in " .. pickOne(rnd, { 20, 30, 45, 60 }) .. " minutes") or "Try it on your next idea"
    if r == L.POOR then sub = "Optional. Very optional." end
    return { text = table.concat(list, ". ") .. ".", sub = sub }
  end }

idea { id = "fusion", label = "Genre Fusion", icon = "atom", weight = 6,
  make = function(rnd, r)
    local picks = shuffled(rnd, GENRES)
    local n = (r >= L.EPIC) and 3 or 2
    local list = {}
    for i = 1, n do list[i] = picks[i] end
    local sub = "at " .. between(rnd, 70, 175) .. " BPM"
    if r >= L.LEGENDARY then sub = sub .. ", for " .. pickOne(rnd, OCCASIONS) end
    return { text = table.concat(list, " x "), sub = sub }
  end }

idea { id = "alias", label = "Artist Alias", icon = "mask", weight = 4,
  make = function(rnd, r)
    local function one()
      local p = pickOne(rnd, ALIAS_PATTERNS)
      p = p:gsub("%%A", function() return pickOne(rnd, ADJ) end)
      p = p:gsub("%%N", function() return pickOne(rnd, NOUN) end)
      p = p:gsub("%%P", function() return plural(pickOne(rnd, NOUN)) end)
      p = p:gsub("%%n", function() return pickOne(rnd, NOUN):lower() end)
      return p
    end
    local sub = "Your next side project"
    if r >= L.EPIC then sub = "a.k.a. " .. one() end
    if r == L.POOR then return { text = "DJ " .. pickOne(rnd, { "Laptop", "Default", "Preset", "Untitled" }), sub = "It's a start." } end
    return { text = one(), sub = sub }
  end }

idea { id = "lyric", label = "Lyric Opener", icon = "mic", weight = 6,
  make = function(rnd, r)
    local function line()
      local v = pickOne(rnd, VERBS)
      local s = pickOne(rnd, LYRIC_LINES)
      s = s:gsub("%%vs", v[2]):gsub("%%vd", v[3]):gsub("%%ving", v[4]):gsub("%%v", v[1])
      s = s:gsub("%%n", function() return pickOne(rnd, LYRIC_NOUNS) end)
      s = s:gsub("%%a", function() return pickOne(rnd, ADJ):lower() end)
      s = s:gsub("%%p", function() return pickOne(rnd, LYRIC_PLACES) end)
      s = s:gsub("%%s", function() return pickOne(rnd, SIMILES) end)
      s = s:gsub("%%t", function() return pickOne(rnd, TIMES) end)
      return articles(s)
    end
    local t = "\"" .. line() .. "\""
    local sub = { "Write the next three lines" }
    if r >= L.RARE then sub[1] = "Rhyme the next line with \"" .. pickOne(rnd, LYRIC_NOUNS) .. "\"" end
    if r >= L.EPIC then sub[#sub + 1] = "Hook: \"" .. line() .. "\"" end
    if r >= L.MYTHIC then sub[#sub + 1] = "Bridge: \"" .. line() .. "\"" end
    return { text = t, sub = table.concat(sub, ". ") }
  end }

local SECTION_SETS = {
  { { "Intro", 8 }, { "Verse", 16 }, { "Chorus", 8 }, { "Verse", 16 }, { "Chorus", 8 }, { "Bridge", 8 }, { "Chorus", 16 }, { "Outro", 8 } },
  { { "Intro", 16 }, { "Build", 8 }, { "Drop", 16 }, { "Break", 16 }, { "Build", 8 }, { "Drop", 16 }, { "Outro", 16 } },
  { { "Intro", 4 }, { "Verse", 8 }, { "Pre-Chorus", 4 }, { "Chorus", 8 }, { "Verse", 8 }, { "Pre-Chorus", 4 }, { "Chorus", 8 }, { "Outro", 4 } },
  { { "Intro", 8 }, { "A", 16 }, { "B", 16 }, { "A", 16 }, { "Solo", 16 }, { "A", 16 }, { "Outro", 8 } },
  { { "Cold open", 4 }, { "Hook", 8 }, { "Verse", 16 }, { "Hook", 8 }, { "Verse", 16 }, { "Hook", 8 }, { "Outro", 4 } },
}

idea { id = "arrange", label = "Arrangement", icon = "blocks", weight = 5,
  make = function(rnd, r)
    local set = pickOne(rnd, SECTION_SETS)
    local list = {}
    for i, s in ipairs(set) do list[i] = { s[1], s[2] } end
    if r >= L.RARE and chance(rnd, 0.7) then
      table.insert(list, between(rnd, 3, #list - 1), { pickOne(rnd, { "Breakdown", "Interlude", "Key change", "Half-time" }), 8 })
    end
    if r >= L.LEGENDARY then table.insert(list, #list, { "False ending", 4 }) end
    if r == L.POOR then list = { { "Loop", 8 }, { "Same loop", 8 }, { "Loop again", 8 } } end
    local bpm = between(rnd, 80, 140)
    local bars, parts = 0, {}
    for i, s in ipairs(list) do bars = bars + s[2]; parts[i] = s[1] .. " " .. s[2] end
    local secs = bars * 4 * 60 / bpm
    return { text = table.concat(parts, "  >  "),
             sub = string.format("%d bars, about %d:%02d at %d BPM", bars, math.floor(secs / 60), math.floor(secs % 60), bpm),
             data = { sections = list, bpm = bpm } }
  end }

local SIGS = { { "4/4", 60 }, { "3/4", 10 }, { "6/8", 10 }, { "5/4", 4 }, { "7/8", 4 }, { "12/8", 6 } }

idea { id = "seed", label = "Song Seed", icon = "seed", weight = 6,
  make = function(rnd, r)
    local T = L.T
    local scaleName = scaleByWeight(rnd, r)
    local key = keyFor(between(rnd, 0, 11), T.scaleIndex(scaleName))
    local bpm = between(rnd, 68, 174)
    local sig = (r >= L.RARE) and weighted(rnd, (function()
      local t = {}
      for _, s in ipairs(SIGS) do t[#t + 1] = { s[2], s[1] } end
      return t
    end)()) or "4/4"
    local parts = { T.noteName(key, 0) .. " " .. T.SCALES[key.scale].name, bpm .. " BPM", sig }
    local sub = { pickOne(rnd, GENRES) }
    if r >= L.UNCOMMON then sub[#sub + 1] = "feeling " .. pickOne(rnd, MOODS) end
    if r >= L.EPIC then sub[#sub + 1] = "called \"" .. pickOne(rnd, ADJ) .. " " .. pickOne(rnd, NOUN) .. "\"" end
    return { text = table.concat(parts, "  /  "), sub = table.concat(sub, ", "), data = { bpm = bpm } }
  end }

idea { id = "goodidea", label = "Good Idea Number", icon = "dice", weight = 2,
  make = function(rnd, r)
    local kinds = { "Motif", "Phrase", "Measure", "Drums" }
    local n = between(rnd, 1, 99999)
    return { text = "Idea #" .. n, sub = "Open Good Idea, choose " .. pickOne(rnd, kinds) .. " and type in idea number " .. n,
             data = { number = n } }
  end }

function L.makeIdea(rnd, kind, r)
  local def = IDEAS[kind]
  local out = def.make(rnd, r)
  return { type = "idea", kind = kind, rarity = r, name = def.label, icon = def.icon,
           text = out.text, sub = out.sub or "", data = out.data or {}, midi = def.midi or false }
end

function L.randomIdeaKind(rnd)
  local list = {}
  for _, d in ipairs(IDEAS) do list[#list + 1] = { d.weight, d.id } end
  return weighted(rnd, list)
end

------------------------------------------------------------------------------
-- Gear
--
-- Diablo's way with items: a base for its slot; an implicit stat every item
-- of that slot carries; affixes, more the rarer it is, each rolled within a
-- range and naming the item; and on Legendary and Mythic gear a power that
-- changes a rule rather than a number. Stats only ever reward working on
-- music - none of them shortens the fifteen minutes a tier takes.
------------------------------------------------------------------------------

L.SLOTS = {
  { id = "phones", name = "Headphones", icon = "phones", implicit = "xp",
    bases = { "Earbuds", "Studio Cans", "Open-Backs", "Closed-Backs", "Reference Headphones", "Planar Headphones" } },
  { id = "monitors", name = "Monitors", icon = "speaker", implicit = "coins",
    bases = { "Desk Speakers", "Nearfields", "Studio Monitors", "Midfields", "Horn Monitors", "Coaxial Monitors" } },
  { id = "keys", name = "Controller", icon = "keys", implicit = "notes",
    bases = { "Mini Keyboard", "Pad Controller", "MIDI Keyboard", "Weighted Keys", "Grid Controller", "Fader Bank" } },
  { id = "mic", name = "Microphone", icon = "mic", implicit = "rec",
    bases = { "Dynamic Mic", "Condenser Mic", "Ribbon Mic", "Tube Mic", "Shotgun Mic", "Valve Condenser" } },
  { id = "interface", name = "Interface", icon = "dial", implicit = "quest",
    bases = { "Audio Interface", "Preamp", "Channel Strip", "Converter", "Summing Mixer", "Patchbay" } },
  { id = "charm", name = "Desk Charm", icon = "gem", implicit = "luck",
    bases = { "Coffee Mug", "Lava Lamp", "Rubber Duck", "Cactus", "Lucky Plectrum", "Vinyl Record", "Cassette Tape", "Tiny Gong" } },
}
for _, s in ipairs(L.SLOTS) do L.SLOTS[s.id] = s end

L.JUNK = { "Cracked", "Dusty", "Buzzing", "Wobbly", "Chipped", "Sticky", "Crackling", "Second-hand" }

-- stat: what the game reads. lo/hi: the roll at item level 1, before rarity.
L.AFFIXES = {
  { id = "xp",      lo = 2, hi = 6,   fmt = "+%d%% XP from everything",            prefix = "Studious",  suffix = "of Learning" },
  { id = "coins",   lo = 3, hi = 8,   fmt = "+%d%% coins found",                   prefix = "Gilded",    suffix = "of Riches" },
  { id = "luck",    lo = 3, hi = 10,  fmt = "+%d%% better loot (magic find)",       prefix = "Lucky",     suffix = "of Fortune" },
  { id = "quest",   lo = 4, hi = 10,  fmt = "+%d%% quest rewards",                 prefix = "Questing",  suffix = "of the Seeker" },
  { id = "notes",   lo = 8, hi = 20,  fmt = "+%d%% XP from writing MIDI notes",    prefix = "Melodic",   suffix = "of the Composer" },
  { id = "rec",     lo = 8, hi = 20,  fmt = "+%d%% XP from recording",             prefix = "Live",      suffix = "of the Performer" },
  { id = "fx",      lo = 8, hi = 20,  fmt = "+%d%% XP from plugins",               prefix = "Processed", suffix = "of the Engineer" },
  { id = "tracks",  lo = 8, hi = 20,  fmt = "+%d%% XP from new tracks and items",  prefix = "Building",  suffix = "of the Arranger" },
  { id = "endure",  lo = 5, hi = 15,  fmt = "+%d%% XP after an hour in a session", prefix = "Tireless",  suffix = "of Endurance" },
  { id = "night",   lo = 8, hi = 25,  fmt = "+%d%% XP between midnight and 5am",   prefix = "Nocturnal", suffix = "of the Night Owl" },
  { id = "dawn",    lo = 8, hi = 25,  fmt = "+%d%% XP between 5am and 9am",        prefix = "Dawnlit",   suffix = "of the Early Bird" },
  { id = "grace",   lo = 15, hi = 45, fmt = "+%d seconds before you count as idle", prefix = "Patient",  suffix = "of Focus" },
  { id = "checkin", lo = 10, hi = 30, fmt = "+%d%% check-in rewards",              prefix = "Loyal",     suffix = "of Devotion" },
  { id = "crate",   lo = 5, hi = 15,  fmt = "+%d%% chance of an extra item in crates", prefix = "Hoarding", suffix = "of Plenty" },
}
for _, a in ipairs(L.AFFIXES) do L.AFFIXES[a.id] = a end

L.POWERS = {
  { id = "golden_hour", name = "Golden Hour",  text = "Hour rewards hold one extra item." },
  { id = "hoarder",     name = "Hoarder",      text = "Every crate holds one extra item." },
  { id = "midas",       name = "Midas Touch",  text = "A 10% chance to double any coins you find." },
  { id = "collector",   name = "The Collector", text = "Ideas you find have a 25% chance to be one rarity higher." },
  { id = "second_wind", name = "Second Wind",  text = "Coming back from idle gives 30 XP (once every 30 minutes)." },
  { id = "fickle",      name = "Fickle Muse",  text = "A free quest reroll every day." },
  { id = "deep_focus",  name = "Deep Focus",   text = "Three extra minutes before you count as idle." },
  { id = "overclock",   name = "Overclocked",  text = "XP Boosts last twice as long." },
  { id = "marathon",    name = "Marathon",     text = "+50% XP after two hours in a session." },
  { id = "scholar",     name = "Scholar",      text = "Quests give 50% more XP." },
}
for _, p in ipairs(L.POWERS) do L.POWERS[p.id] = p end

local AFFIX_COUNT = { 0, 0, 1, 2, 3, 3, 4 }
local RARE_A = { "Storm", "Doom", "Echo", "Rune", "Dread", "Grim", "Bliss", "Soul", "Ghost", "Star", "Blood", "Dusk", "Glory", "Hex", "Void" }
local RARE_B = { "Whisper", "Howl", "Hymn", "Song", "Roar", "Chant", "Pulse", "Beat", "Wail", "Drone", "Groove", "Fang", "Ward", "Mark" }

local function affixValue(rnd, a, r, ilvl, top)
  local roll = top and (0.5 + 0.5 * rnd()) or rnd()
  local v = (a.lo + (a.hi - a.lo) * roll) * L.RARITY[r].mult * (1 + math.min(ilvl or 1, 100) / 200)
  return math.max(1, math.floor(v + 0.5))
end

function L.makeGear(rnd, r, ilvl, slotId)
  ilvl = math.max(1, math.floor(ilvl or 1))
  local slot = slotId and L.SLOTS[slotId] or pickOne(rnd, L.SLOTS)
  local base = slot.bases[math.min(#slot.bases, 1 + math.floor((r - 1) * #slot.bases / 7 + rnd() * 1.5))]
  local implicit = L.AFFIXES[slot.implicit]
  local item = { type = "gear", slot = slot.id, base = base, rarity = r, ilvl = ilvl, icon = slot.icon,
                 implicit = { id = implicit.id, value = math.max(1, math.floor(affixValue(rnd, implicit, r, ilvl, r == L.MYTHIC) * 0.5 + 0.5)) },
                 affixes = {} }
  if r == L.POOR then item.implicit.value = 1 end
  local pool = {}
  for _, a in ipairs(L.AFFIXES) do if a.id ~= slot.implicit then pool[#pool + 1] = a end end
  pool = shuffled(rnd, pool)
  for i = 1, AFFIX_COUNT[r] do
    local a = pool[i]
    item.affixes[i] = { id = a.id, value = affixValue(rnd, a, r, ilvl, r == L.MYTHIC) }
  end
  if r >= L.LEGENDARY then item.power = pickOne(rnd, L.POWERS).id end
  -- The name, the way Diablo builds one.
  if r == L.POOR then item.name = pickOne(rnd, L.JUNK) .. " " .. base
  elseif r == L.COMMON then item.name = base
  elseif r == L.UNCOMMON then
    local a = L.AFFIXES[item.affixes[1].id]
    item.name = chance(rnd, 0.5) and (a.prefix .. " " .. base) or (base .. " " .. a.suffix)
  elseif r == L.RARE then
    item.name = L.AFFIXES[item.affixes[1].id].prefix .. " " .. base .. " " .. L.AFFIXES[item.affixes[2].id].suffix
  elseif r == L.EPIC then item.name = pickOne(rnd, RARE_A) .. " " .. pickOne(rnd, RARE_B)
  elseif r == L.LEGENDARY then item.name = madeUpName(rnd) .. "'s " .. base
  else item.name = madeUpName(rnd) .. ", " .. pickOne(rnd, EPITHETS) end
  item.text = item.name
  item.sub = L.RARITY[r].name .. " " .. slot.name .. (r >= L.EPIC and (" (" .. base .. ")") or "") .. "  /  item level " .. ilvl
  item.name = item.name
  return item
end

-- Every stat an item gives, implicit included, as { id = value }.
function L.gearStats(item)
  local s = {}
  if item.implicit then s[item.implicit.id] = (s[item.implicit.id] or 0) + item.implicit.value end
  for _, a in ipairs(item.affixes or {}) do s[a.id] = (s[a.id] or 0) + a.value end
  return s
end

function L.statLine(id, value) return string.format(L.AFFIXES[id].fmt, value) end

-- A single number to compare gear by: each stat against its own range.
function L.gearScore(item)
  local score = 0
  for id, v in pairs(L.gearStats(item)) do
    local a = L.AFFIXES[id]
    score = score + v / ((a.lo + a.hi) / 2) * 10
  end
  if item.power then score = score + 25 end
  return math.floor(score + 0.5)
end

function L.sellValue(item)
  return math.floor(L.RARITY[item.rarity].sell * (1 + (item.ilvl or 1) / 50) + 0.5)
end

------------------------------------------------------------------------------
-- Cosmetics
------------------------------------------------------------------------------

function L.makeTitle(rnd, r)
  local t
  if r <= L.COMMON then t = pickOne(rnd, TITLE_ROLE)
  elseif r <= L.RARE then t = pickOne(rnd, TITLE_ADJ) .. " " .. pickOne(rnd, TITLE_ROLE)
  elseif r <= L.LEGENDARY then t = pickOne(rnd, TITLE_ADJ) .. " " .. pickOne(rnd, TITLE_ROLE) .. " of " .. pickOne(rnd, TITLE_OF)
  else t = madeUpName(rnd) .. " the " .. pickOne(rnd, TITLE_ADJ) .. ", " .. pickOne(rnd, TITLE_ROLE) .. " of " .. pickOne(rnd, TITLE_OF) end
  return { type = "title", rarity = r, name = "Player Title", icon = "crown", text = t, sub = "Wear it in your banner" }
end

L.BANNER_SHAPES = { "circle", "shield", "diamond", "hexagon", "star" }
L.BANNER_PATTERNS = { "plain", "split", "stripes", "chevron", "rings", "rays", "dots" }
L.BANNER_GLYPHS = { "note", "bolt", "star", "crown", "flame", "wave", "moon", "gem" }

function L.makeBanner(rnd, r)
  local maxPattern = math.min(#L.BANNER_PATTERNS, 1 + r)
  local b = {
    shape = pickOne(rnd, L.BANNER_SHAPES),
    pattern = L.BANNER_PATTERNS[between(rnd, 1, maxPattern)],
    h1 = rnd(), h2 = rnd(),
    glyph = (r >= L.RARE) and pickOne(rnd, L.BANNER_GLYPHS) or nil,
    glow = r >= L.LEGENDARY, spin = r >= L.MYTHIC,
  }
  if r == L.POOR then b.pattern = "plain"; b.sat = 0.1 end
  return { type = "banner", rarity = r, name = "Banner", icon = "banner",
           text = pickOne(rnd, COLOUR_WORDS) .. " " .. pickOne(rnd, BANNER_THINGS), sub = "A banner for your profile", data = b }
end

------------------------------------------------------------------------------
-- Coins, XP, tokens, crates
------------------------------------------------------------------------------

L.TOKENS = {
  reroll = { name = "Quest Reroll", icon = "dice", text = "Swap a quest for a new one" },
  freeze = { name = "Streak Freeze", icon = "snow", text = "Saves your check-in streak for a missed day" },
  boost  = { name = "XP Boost", icon = "bolt", text = "Double XP for 30 minutes of active time" },
}

function L.makeCoins(rnd, r)
  local n = L.coinsFor(rnd, r)
  return { type = "coins", rarity = r, name = "Coins", icon = "coin", amount = n, text = n .. " coins", sub = "Spend them in the shop" }
end

function L.makeXp(rnd, r)
  local n = L.RARITY[r].xp
  return { type = "xp", rarity = r, name = "XP", icon = "star", amount = n, text = n .. " XP", sub = "Straight onto your level" }
end

function L.makeToken(rnd, r, id)
  id = id or weighted(rnd, { { 5, "reroll" }, { 2, "freeze" }, { 3, "boost" } })
  local tk = L.TOKENS[id]
  local n = (r >= L.MYTHIC) and 3 or ((r >= L.LEGENDARY) and 2 or 1)
  return { type = "token", rarity = math.max(r, L.UNCOMMON), name = tk.name, icon = tk.icon, token = id, amount = n,
           text = (n > 1 and (n .. " x ") or "") .. tk.name, sub = tk.text }
end

function L.makeCrate(r)
  r = math.max(L.COMMON, r)
  return { type = "crate", rarity = r, name = "Loot Crate", icon = "crate",
           text = L.RARITY[r].name .. " Crate", sub = "Open it in Loot" }
end

-- A random drop of a rarity, from a pool's weights. ctx: ilvl, collector.
local POOLS = {
  tier  = { { 24, "coins" }, { 34, "idea" }, { 18, "gear" }, { 8, "cosmetic" }, { 9, "token" }, { 7, "xp" } },
  crate = { { 32, "gear" }, { 30, "idea" }, { 14, "coins" }, { 12, "cosmetic" }, { 8, "token" }, { 4, "xp" } },
  deal  = { { 50, "gear" }, { 35, "cosmetic" }, { 15, "idea" } },
}
L.POOLS = POOLS

function L.makeDrop(rnd, r, pool, ctx)
  ctx = ctx or {}
  local what = weighted(rnd, POOLS[pool or "tier"])
  if what == "coins" then return L.makeCoins(rnd, r)
  elseif what == "xp" then return L.makeXp(rnd, r)
  elseif what == "token" then return L.makeToken(rnd, r)
  elseif what == "gear" then return L.makeGear(rnd, r, ctx.ilvl or 1)
  elseif what == "cosmetic" then
    if chance(rnd, 0.5) then return L.makeTitle(rnd, r) end
    return L.makeBanner(rnd, r)
  end
  local kind = L.randomIdeaKind(rnd)
  if ctx.collector and r < L.MYTHIC and chance(rnd, 0.25) then r = r + 1 end
  return L.makeIdea(rnd, kind, r)
end

-- What a crate holds: three things, one at least the crate's rarity, the rest
-- at most two steps under it. `extra` items on top.
function L.crateContents(rnd, r, luck, extra, ctx)
  local out = {}
  local n = 3 + (extra or 0)
  for i = 1, n do
    local rr
    if i == 1 then rr = L.rollRarity(rnd, r, L.MYTHIC, luck)
    else rr = L.rollRarity(rnd, math.max(L.POOR, r - 2), L.MYTHIC, luck) end
    out[i] = L.makeDrop(rnd, rr, "crate", ctx)
  end
  return out
end

------------------------------------------------------------------------------
-- Seasons
--
-- A season is a calendar month, numbered from January 2026, with a name made
-- from its number. Its track has 100 tiers, one every fifteen active minutes,
-- every fourth (each hour) a big one; past 100 the bonus tiers go on for ever.
-- Each tier's reward is made from the season and the tier alone, so the track
-- can be shown ahead of time.
------------------------------------------------------------------------------

L.SEASON_TIERS = 100

local SEASON_ADJ = { "Neon", "Midnight", "Golden", "Electric", "Cosmic", "Velvet", "Crystal",
  "Analog", "Lunar", "Solar", "Feral", "Infinite", "Phantom", "Tidal", "Static", "Molten" }
local SEASON_NOUN = { "Tides", "Frequencies", "Echoes", "Horizons", "Circuits", "Embers",
  "Dreams", "Signals", "Voltage", "Gardens", "Machines", "Skies", "Waves", "Ruins", "Rhythms" }

function L.seasonId(year, month) return (year - 2026) * 12 + month end

function L.seasonName(id)
  local rnd = L.random(L.seedOf("season", id))
  return pickOne(rnd, SEASON_ADJ) .. " " .. pickOne(rnd, SEASON_NOUN)
end

-- "big" tiers are each hour's; "milestone" every tenth; the last the finale.
function L.tierKind(tier)
  if tier == L.SEASON_TIERS then return "finale" end
  if tier % 25 == 0 and tier <= L.SEASON_TIERS then return "legendary" end
  if tier % 10 == 0 and tier <= L.SEASON_TIERS then return "milestone" end
  if tier % 4 == 0 then return "big" end
  return "small"
end

-- The rarity a tier's headline reward will have, without making it: for the
-- track's preview.
function L.tierRewards(season, tier, ilvl, ctx)
  ctx = ctx or {}
  ctx.ilvl = ilvl
  local rnd = L.random(L.seedOf("tier", season, tier))
  local kind = L.tierKind(tier)
  local out = {}
  if kind == "small" then
    out[1] = L.makeCoins(rnd, L.rollRarity(rnd, L.POOR, L.UNCOMMON))
    out[2] = L.makeDrop(rnd, L.rollRarity(rnd, L.POOR, L.MYTHIC), "tier", ctx)
  elseif kind == "big" then
    out[1] = L.makeCoins(rnd, L.RARE)
    out[2] = L.makeCrate(L.rollRarity(rnd, L.RARE, L.MYTHIC))
    out[3] = L.makeDrop(rnd, L.rollRarity(rnd, L.UNCOMMON, L.MYTHIC), "crate", ctx)
  elseif kind == "milestone" then
    out[1] = L.makeCoins(rnd, L.EPIC)
    out[2] = L.makeGear(rnd, L.rollRarity(rnd, L.EPIC, L.MYTHIC), ilvl)
    out[3] = L.makeDrop(rnd, L.rollRarity(rnd, L.RARE, L.MYTHIC), "crate", ctx)
  elseif kind == "legendary" then
    out[1] = L.makeCoins(rnd, L.LEGENDARY)
    out[2] = L.makeGear(rnd, L.LEGENDARY, ilvl)
    out[3] = L.makeCrate(L.EPIC)
  else
    out[1] = L.makeCoins(rnd, L.MYTHIC)
    out[2] = L.makeGear(rnd, L.MYTHIC, ilvl)
    local t = L.makeTitle(rnd, L.MYTHIC)
    t.text = "Champion of " .. L.seasonName(season)
    out[3] = t
    local b = L.makeBanner(rnd, L.MYTHIC)
    out[4] = b
  end
  return out, kind
end

-- What the track shows for a tier before it is reached: its best reward.
function L.tierHeadline(season, tier, ilvl)
  local list, kind = L.tierRewards(season, tier, ilvl)
  local best = list[1]
  for _, d in ipairs(list) do
    if d.rarity > best.rarity or (d.rarity == best.rarity and best.type == "coins") then best = d end
  end
  return best, kind
end

function L.init(T)
  L.T = T
  return L
end

return L
