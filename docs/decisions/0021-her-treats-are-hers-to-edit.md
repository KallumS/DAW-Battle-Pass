# 0021 - The treats are editable in the app

In DAW Battle Pass the shop's prices live in `G.SHOP` for the user to edit in
the script. A compiled app can't be edited, and she named her own rewards
("makeup and buying clothes, as examples"), so the permission slips are
saved state (`GameState.rewards`), seeded with fourteen defaults (a fancy
coffee at 300 coins up to a shopping spree at 15,000) and editable in
Settings: rename, reprice, add, remove, or put back as they were.

A treat can't be removed while she owns an unredeemed one, so a pass never
points at nothing. Tokens and gift boxes stay the game's own
(`Rules.fixedShop`), because their prices are part of the balance.
