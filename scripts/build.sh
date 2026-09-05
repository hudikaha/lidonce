#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
staging=$(/usr/bin/mktemp -d /tmp/lidonce-build.XXXXXX)
trap 'rm -rf "$staging"' EXIT HUP INT TERM
app="$staging/LidOnce.app"
mkdir -p build
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/swiftc -O -framework AppKit \
  Sources/LidOnce/StateMachine.swift Sources/LidOnce/LidOnceApp.swift \
  -o "$app/Contents/MacOS/LidOnce"
/usr/bin/swiftc -O -framework AppKit Sources/LidOnceCLI/main.swift -o build/lidonce
cp Resources/Info.plist "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
cp Resources/lidonce-guard "$app/Contents/Resources/lidonce-guard"
cp Resources/lidonce-notebook@2x.png "$app/Contents/Resources/lidonce-notebook@2x.png"
chmod 755 "$app/Contents/Resources/lidonce-guard"
/usr/bin/xattr -cr "$app"
/usr/bin/codesign --force --sign - "$app"
rm -rf build/LidOnce.app
cp -R "$app" build/LidOnce.app
/usr/bin/xattr -cr build/LidOnce.app
echo "built build/LidOnce.app"
