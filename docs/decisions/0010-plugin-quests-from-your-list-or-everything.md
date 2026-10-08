# 0010 - Plugin quests: your list, or everything installed

The user offered to send a list of their plugins. REAPER can list everything
installed itself (`EnumInstalledFX`), so quests work without one: JSFX and
video processors are left out (hundreds of utilities), and each plugin is
named once whatever formats it comes in.

A list of the user's own wins when it has names in it: a plain text file in
the data folder, one name a line, opened from the Stats page. Names are
matched plainly - "VST3i: Serum (Xfer Records)" and "Serum" are both
`serum` - and a plugin renamed on a track is known by its real name
(`fx_name`).
