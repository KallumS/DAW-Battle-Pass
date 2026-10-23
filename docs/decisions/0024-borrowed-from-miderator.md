# 0024 - Packaging and Apple's guidelines, borrowed from Miderator

The user pointed at Miderator, another of their Mac apps (JUCE, C++), as
something that might help. Its engine has nothing to lend a Swift game, but
three habits did:

1. **A .dmg, not a zip** - the app beside a shortcut to Applications and a
   "Read me first" (`writer/docs/INSTALL-MAC.txt`), made with `hdiutil`,
   retried because GitHub's runners sometimes find the disk busy. Its
   install note's `xattr -cr` line for "the app is damaged" came too.
   Miderator's note says right-click > Open; macOS 15 removed that, so ours
   says Open Anyway in Privacy & Security.
2. **Text at 7:1** (its 0048): dim text went from `#948B9C` (4.8:1) to
   `#B3AABB` (7.0:1), and Poor with it.
3. **Reduce Motion** (its 0048): with the Mac's setting on, nothing flies,
   bursts or floats, and the stage appears without springs or wobble.

Not borrowed: `build-mac.command` (building on the user's own Mac). The
friend should only ever need the .dmg.
