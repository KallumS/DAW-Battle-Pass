# 0003 - The time is always passed in

Every rule that depends on time takes it as an argument: `tp`
(`time_precise`) for idle and the size of a tick, `epoch` (`os.time`) for
days, weeks and seasons. Nothing in `bp_game` reads a clock.

That is what lets `test_game` run two hours of music, a week of check-ins and
a change of season in a second, and `test_ui` run the real window through an
hour by moving a fake clock. A day starts at 4am (`G.DAY_START_HOUR`) so a
late session counts for the day it started; a week is named for its Monday.
