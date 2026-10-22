#!/bin/bash
# Draws every page and celebration to build/snapshots/*.png (needs the app
# built by make_app.sh first).
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/snapshots; mkdir -p build/snapshots
"build/Writing Battle Pass.app/Contents/MacOS/WritingBattlePass" --snapshots build/snapshots
ls -la build/snapshots
