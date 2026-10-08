# DAW Battle Pass

A battle pass for REAPER that rewards you for making music.

Keep its window open while you work. Every **15 minutes** of actual
music-making unlocks a tier of rewards, and every **hour** unlocks a big one.
Everything you do (new tracks, MIDI notes, plugins, recording) earns **XP**
that levels you up, and every level gives a **loot crate**. You spend
**coins** in a shop on permission slips: a takeaway, a movie, a two-hour
gaming session. When you stop working, it notices and the clock pauses. Your
progress belongs to you, not to a project, so it carries on whichever project
you open.

Built in the same shape and colours as Good Idea, Midi Catalogue, Starting
Blocks and ScaleView.

## Installing

You need **ReaImGui**, the extension your other scripts already use. If you
have Good Idea or Midi Catalogue working, you have it.

**With ReaPack** (recommended): Extensions > ReaPack > Import repositories,
and paste:

    https://raw.githubusercontent.com/KallumS/DAW-Battle-Pass/main/index.xml

Then Extensions > ReaPack > Browse packages, find **DAW Battle Pass**, and
install it.

**By hand**: copy the whole `reascripts` folder into REAPER's Scripts folder,
then Actions > Show action list > New action > Load ReaScript, and choose
`DAW Battle Pass.lua`. The other five files must stay beside it.

**Optional extras:**
- **js_ReaScriptAPI** (from ReaPack) lets the battle pass tell whether REAPER
  is actually the app you're using. Without it, moving the mouse in your web
  browser still counts as "working".
- **SWS** lets the "Open my plugin list" button open the file for you.

## Using it

Run the action. The first time, you get a short welcome and a Rare crate to
start you off. You can **dock** the window: right-click its title bar.

You can also tick **Start the battle pass when REAPER starts** on the Stats
page, so you never forget to run it.

### What counts as "working"

The clock runs while something is happening in REAPER: edits, the mouse
moving, the edit cursor moving, playing or recording. With nothing happening
for **3 minutes** (you can change this on the Stats page) you count as away
and the clock stops. While the project is playing back you get at least 8
minutes, so you can listen through a mix. Recording always counts.

### The pages

| Page | What's there |
| --- | --- |
| **Pass** | This month's season, the ring counting down to your next tier, today's numbers, and the battle pass track sliding past - hover any tier to see what it holds. |
| **Quests** | The daily check-in calendar, three daily quests and four weekly quests. Finish all the dailies for an Uncommon crate, all the weeklies for an Epic one. |
| **Shop** | Three Daily Deals (new every day), then passes, tokens and crates. Expensive things ask "Sure?" before buying. |
| **Gear** | Your six equipment slots, what they add up to, and your stash. |
| **Loot** | Crates to open, passes to redeem, tokens, and your titles and banners. |
| **Ideas** | Every idea you've won. Copy them, star them, or put them straight into your project. |
| **Trophies** | Achievements, each in tiers. Finish a series to earn its title. |
| **Stats** | Your totals, the last 14 days, your most-worked projects and most-used plugins, and settings. |

## The season pass

Like Fortnite's: each **calendar month is a season** with its own name and a
**100-tier track**. A tier unlocks every 15 active minutes; every fourth tier
(each hour) is big, every tenth is a milestone with Epic-or-better gear,
tiers 25, 50 and 75 give Legendary gear, and tier 100 is a Mythic finale with
a title and banner for that season. After 100, bonus tiers go on for ever.

The track is the same for everyone in a given month, so you can see what's
coming. When a new month starts, the track starts again; your level, coins,
gear and everything else stay.

## Rarity

| | |
| --- | --- |
| **Poor** | Grey junk, the Diablo way. Sometimes funny. |
| **Common** | |
| **Uncommon** | |
| **Rare** | |
| **Epic** | |
| **Legendary** | Glows. |
| **Mythic** | Very rare. The screen shakes. |

Rarer ideas are richer: a Common chord progression is four plain chords, a
Legendary one is eight, with sevenths, a borrowed chord and a secondary
dominant; a Mythic one changes key halfway.

## The rewards (they never run out)

Every reward is made on the spot, so there's always something new:

- **Song titles** ("Velvet Static", "Chasing Satellites")
- **Song themes** ("A bittersweet song about the last train home, set in a
  rainy Tokyo alley, told by a stray cat")
- **Chord progressions** - insert them as MIDI
- **Drum patterns** in ten styles (house, boom bap, trap, D&B, reggaeton,
  lo-fi, techno, funk, UK garage, afrobeats) - insert them as MIDI
- **Melodies** - insert them as MIDI
- **Sound design briefs** ("Design a pad that sounds like a frozen lake
  cracking, using only a single oscillator")
- **Challenges** ("No reverb allowed. Use 7/8 time.")
- **Genre fusions** ("Sea Shanty x Drum & Bass at 172 BPM, for a heist going
  wrong")
- **Artist aliases**, **lyric openers**, **arrangements** (add them as
  regions), **song seeds** (key, tempo, time signature - set the tempo with
  one click) and **Good Idea numbers** to try in Good Idea
- **Gear**, **player titles**, **banners**, **coins**, **XP**, **tokens**
  and **crates**

## Gear

Six slots - Headphones, Monitors, Controller, Microphone, Interface and a Desk
Charm - in the manner of Diablo. Each item has a stat it always gives, plus
random bonuses: more XP, more coins, better loot, bigger quest rewards, more
XP for writing MIDI or recording, more time before you count as away, and so
on. The bonuses name the item ("Gilded Studio Monitors of the Night Owl").
**Legendary and Mythic gear has a power** that changes a rule, like an extra
item in every crate or a free quest reroll every day.

No gear ever makes a tier come faster. Gear only makes your work worth more.

Hover any item to compare it with what you're wearing. Salvage what you don't
want for coins.

## The shop

| Pass | Price |
| --- | ---: |
| Coffee Run Pass | 300 |
| Snack Pass | 450 |
| Video Break Pass (30 minutes) | 600 |
| Lie-In Pass | 1,200 |
| Movie Pass | 1,600 |
| Gaming Pass (2 hours) | 1,800 |
| Takeaway Pass | 2,500 |
| Day Off Pass | 6,000 |
| New Plugin Pass | 12,000 |

Plus Quest Rerolls, Streak Freezes, XP Boosts (double XP for 30 active
minutes) and crates. A focused hour earns roughly 400-600
coins once quests, crates and check-ins are counted, so a takeaway is about
five hours of real music-making.

**To change the prices or add your own passes**, open
`reascripts/bp_game.lua` in any text editor and find the section that starts
`G.SHOP = {`. Each line is one item; change the `price`, or copy a line and
give it a new `id`, `name` and `desc`.

## Plugin quests

Quests can ask you to use a particular plugin ("Use Serum on 2 tracks") or a
kind of plugin ("Use a compressor 3 times"). By default the plugin is chosen
from everything REAPER has installed (JSFX left out). To choose for yourself,
click **Open my plugin list** on the Stats page and write one plugin name per
line - just the name, like `Serum` or `Pro-Q 3`. Then click **Reload
plugins**.

## Where your progress lives

In REAPER's resource folder, under `Data/DAW Battle Pass/progress.lua`, with
the save before it kept as `progress.lua.bak`. If the save is ever damaged,
the battle pass starts from the backup and keeps the damaged file beside it
rather than overwriting it.

## For developers

See [CLAUDE.md](CLAUDE.md). `tools/test.sh` runs the six test suites;
`tools/bite.sh` proves they catch breakage; `lua5.4 tools/demo.lua` prints a
sample of everything the loot table makes.
