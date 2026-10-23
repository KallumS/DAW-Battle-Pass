#!/bin/bash
# Builds "Writing Battle Pass.app" for Apple silicon into writer/build, signs
# it ad hoc (no Apple developer account), and packs it into a .dmg with a
# shortcut to Applications and "Read me first", as Miderator does.
#   tools/make_app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-1.0}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/Writing Battle Pass.app"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/WritingBattlePass"

rm -rf build/*.app build/*.zip build/*.dmg build/dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WritingBattlePass"
sed -e "s/VERSION/$VERSION/" -e "s/BUILD/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

# The icon: every size from the one big PNG.
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"
lipo -archs "$APP/Contents/MacOS/WritingBattlePass"

mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
cp docs/INSTALL-MAC.txt "build/dmg/Read me first.txt"
# hdiutil sometimes finds the disk "Resource busy" on GitHub's Mac runners;
# a few seconds later it works (Miderator's experience). Try a few times.
made=0
for attempt in 1 2 3 4 5; do
  hdiutil create -volname "Writing Battle Pass" -srcfolder build/dmg -ov -format UDZO build/Writing-Battle-Pass.dmg && { made=1; break; }
  echo "hdiutil failed (attempt $attempt), trying again"
  sleep 10
done
[ "$made" = 1 ]
ls -la build
