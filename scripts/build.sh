#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
app=build/LidOnce.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/swiftc -O -framework AppKit \
  Sources/LidOnce/StateMachine.swift Sources/LidOnce/main.swift \
  -o "$app/Contents/MacOS/LidOnce"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/bin/xattr -cr "$app"
/usr/bin/codesign --force --sign - "$app"
echo "built $app"
