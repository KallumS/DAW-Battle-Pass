# The colour scheme

Every colour the window uses. The chrome is the house scheme, the same as
Good Idea, Midi Catalogue, Starting Blocks, Midi Suggester, Midi Variator and
ScaleView: a dark cool-grey ground, a light grey for the controls raised off
it, and one yellow for whatever is switched on. A game needs more than that,
so it adds a second set - the rarity ladder and three progress colours - and
keeps every one of them off the accent's hue.

This file is kept by hand. If you change a colour in
`reascripts/DAW Battle Pass.lua` or `reascripts/bp_loot.lua`, change it here.

## The house scheme (unchanged)

| | value | what it is |
| --- | --- | --- |
| Accent | `#FFF200` | whatever is on |
| Controls | `#A9AFBA` | buttons, raised off the ground |
| Ground | `#23272E` | the window behind everything |
| Ink | `#14171C` | the text on any button |
| Sunken | `#1A1D23` | panels and cards |
| Deep | `#111419` | the track, the chart, the bars' empty part |
| Rule | `#3A404A` | separators, locked things, empty slots |
| Grab | `#585F6B` | the clock's ring when paused |
| Body text | `#DDE1E7` | |
| Dim text | `#8A919C` | |
| Bright | `#F2F4F7` | flashes, the level number |
| Warn | `#D2483F` | the dot on a tab with something waiting |

Every grey keeps R < G < B. **Every button takes the ink**, chosen or not -
`test_ui` checks every button on every page.

**What the accent means here.** Still only "on": the chosen tab or vault
filter, the chosen title or banner, the clock's ring while the clock is
running (it turns grey when you are away), a quest ready to claim, a check-in
waiting, the "Sure?" of a two-step button, an XP Boost running (yellow stripes
on the level bar), the next tier on the track. Nothing decorative takes it.

## What a game adds

### The rarity ladder

The only other saturated colours, and they always mean a rarity: a card's
border and glow, a name in the stash, the strip down a quest or idea.

| | value | |
| --- | --- | --- |
| Poor | `#8A919C` | the dim text grey - junk looks like junk |
| Common | `#DDE1E7` | the body text |
| Uncommon | `#3FCF6E` | green |
| Rare | `#3D8EFF` | blue |
| Epic | `#A45CFF` | purple |
| Legendary | `#FF8A1C` | orange |
| Mythic | `#FF3FA4` | hot pink |

WoW's and Fortnite's colours up to Legendary. Fortnite's Mythic is gold, which
would sit beside the accent's yellow and read as "on"; Diablo 4's Mythics are
pink-purple, so pink it is, far enough from the warning red to tell apart.

### Progress and money

| | value | |
| --- | --- | --- |
| XP | `#3D8EFF` | the level bar: Rare's blue |
| The pass | `#FF8A1C` | the season track, hour pips, ticks on claimed tiers: Legendary's orange |
| Coin | `#FFC83D`, edge `#B9862A` | coins are gold; the only gold, and only on a coin |

Reusing two rarities for progress keeps the palette to the ladder.

## Two rules worth carrying

**Keep the greys blue**, as the house scheme says.

**A colour that means something means one thing.** Yellow is "on". A rarity
colour is that rarity, except blue on the level bar and orange on the pass
track. Red is "something is waiting". Gold is a coin.
