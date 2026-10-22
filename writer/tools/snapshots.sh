#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/snapshots && echo hi > build/snapshots/x.txt
