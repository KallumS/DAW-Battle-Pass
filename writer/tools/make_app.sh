#!/bin/bash
# Builds "Writing Battle Pass.app" (Apple silicon) into writer/build and zips it.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --arch arm64
mkdir -p build
echo built
ls -la .build/arm64-apple-macosx/release/ | head
.build/arm64-apple-macosx/release/WritingBattlePass
echo zip > build/Writing-Battle-Pass.zip
