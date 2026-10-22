# Writing Battle Pass

A battle pass for writing, as a Mac app (Apple silicon: any Mac from late
2020 on with an M1, M2, M3 or M4 chip; macOS 13 Ventura or newer).

Keep it running while you write. Every **15 minutes** of actual writing
unlocks a tier of this month's season pass, and every **hour** a big one.
Every **letter you type** earns a little XP (a tenth of a point each, so a
thousand words is roughly a level early on), and every level brings a **gift
box**. Gifts are coins, writing prompts (characters, first lines, plot
twists, book titles...), titles, banners - and a **wardrobe** of clothes,
make-up and pens, each with stats that make you earn faster. Coins buy
**treats** in the shop: permission slips for a fancy coffee, a new lipstick,
a new top, a makeup haul, a shopping spree. Buy one, then redeem it when you
take the treat. You can rename, reprice, add and remove treats in Settings.

When you stop writing, the clock pauses. Close the window and it carries on
from the menu bar (the pencil at the top of the screen); choose Quit there to
stop it.

## Installing

1. Download **Writing-Battle-Pass.zip** and double-click it. Drag
   **Writing Battle Pass** into your **Applications** folder.
2. Open it. The first time, the Mac will say it can't check the app for
   malicious software, because it isn't from the App Store or a paid Apple
   developer account. Click **Done** (not Move to Bin), then open **System
   Settings → Privacy & Security**, scroll down, and click **Open Anyway**
   next to Writing Battle Pass. You only do this once.
3. To count letters, the Mac has to let the app see key presses. Click
   **Allow typing to count** on the welcome screen, then turn on Writing
   Battle Pass in **System Settings → Privacy & Security → Input
   Monitoring**. Quit and reopen the app if it doesn't notice straight away.

It only ever counts key presses - letters, and words from the spaces between
them. What you type is never read, kept or sent anywhere. Without the
permission everything else still works; only letters go uncounted.

**After an update** you may need to turn Input Monitoring off and on again
for the new version (the Mac sees it as a new app).

## Which apps count

Out of the box: Word, Pages, Scrivener, Ulysses, iA Writer, Bear, Notes,
TextEdit, Obsidian, Typora and Reedsy. In **Settings → Writing apps** you can
switch on any other app you've typed in (it appears there once you have).
Writing in **Google Docs**? Switch on your web browser - but then browsing
counts too. There's also a switch to count every app.

## Your progress

Saved in `~/Library/Application Support/Writing Battle Pass/progress.json`
every few seconds, with a backup of the save before. Settings has a button
that shows it in Finder.

## For whoever maintains it

See [`docs/BUILDING.md`](docs/BUILDING.md).
