#!/bin/sh
# Runs every suite. Uses lua if there is one, and falls back to lupa otherwise.
set -e
cd "$(dirname "$0")/.."

if command -v lua5.4 >/dev/null 2>&1; then RUN="lua5.4"
elif command -v lua >/dev/null 2>&1;   then RUN="lua"
else RUN="python3 tools/run_lua.py"
fi

fail=0
for suite in tests/test_theory.lua tests/test_loot.lua tests/test_game.lua \
             tests/test_fx.lua tests/test_watch.lua tests/test_ui.lua; do
  [ -f "$suite" ] || continue
  printf '%-22s ' "$(basename "$suite")"
  if ! $RUN "$suite"; then fail=1; fi
done

exit $fail
