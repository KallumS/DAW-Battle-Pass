# 0012 - The stage replaces the page; effects float above everything

Every bit of progress is meant to be celebrated, and a celebration that
can be clicked through by accident is not one. A reward is shown on "the
stage": while one is waiting, the page underneath is not drawn at all, so
nothing on it can be clicked, and the header (coins, level bar) stays on top
to receive what flies into it.

Rewards queue: an hour away from the window can leave several waiting. They
play in the order they happened (see 0008). Each has its own choreography -
a crate bobs until clicked, shakes harder for a second, flashes and bursts;
cards land one at a time with a burst in their rarity's colour; Legendary
flashes the window, Mythic shakes it; a level-up zooms in; a check-in stamps;
a redeemed pass tears in two.

Particles, floating numbers and toasts are on ReaImGui's foreground draw
list, over everything, so coins can fly out of a page and into the header.
Their maths is in `bp_fx` (pure, tested); the window only draws them.

ReaImGui's own popups were the alternative. They dim and block, but they
are a window of their own to size and place, and a docked window makes that
awkward.
