# 0013 - Prices come from a simulated economy

The first prices were guesses (a takeaway at 1,200 coins). A simulation of
ten players doing two hours a day for five days - checking in, finishing
quests, opening every crate - earned about 575 coins an active hour,
early achievements included. At that rate a takeaway was two hours away,
which is cheap for a treat that is meant to feel earned.

Passes were roughly doubled: a takeaway at 2,500 is about five hours of real
music-making, a movie about three, a coffee half an hour. Tokens and crates
kept their prices; they feed back into the game rather than out of it.

The prices are data at the top of `bp_game.lua` (`G.SHOP`), and the README
tells the user where they are: it is their reward system, so they set its
exchange rate. Change a reward's size and the simulation should be run again
(the session log for 2026-10-08 has the shape of it).
