#!/bin/bash
# Prints each snapshot as a small JPEG in base64 between markers, so the
# pictures can be read back from the CI log by someone who can't download
# the artifact (Claude's containers can read logs but not artifacts).
set -euo pipefail
cd "$(dirname "$0")/../build/snapshots"
mkdir -p ../small
for f in *.png; do
  n="${f%.png}"
  sips -Z 820 -s format jpeg -s formatOptions 52 "$f" --out "../small/$n.jpg" >/dev/null
  echo "SNAP-BEGIN $n"
  base64 -i "../small/$n.jpg" | fold -w 6000
  echo "SNAP-END $n"
done
