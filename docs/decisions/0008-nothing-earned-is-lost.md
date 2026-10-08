# 0008 - Nothing earned is lost

A drop is granted the moment it is won; the window celebrates it afterwards.
Closing the window mid-animation, a crash, or a modal left open for a day
loses nothing.

The same rule elsewhere: quests finished but not claimed are claimed for you
when the day or week turns; a full stash sells its weakest item rather than
refusing a new one; a damaged save is set aside and the backup loaded.

One consequence found by `test_ui`: granting a crate's contents can level you
up, and the level-up was being shown before the crate opened. Now a crate or
tier is announced first and granted second, so the stage plays in the order
things happened.
