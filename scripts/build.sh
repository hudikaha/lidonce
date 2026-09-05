#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
app=build/LidOnce.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/swiftc -O -framework AppKit \
  -framework SwiftUI Sources/LidOnce/StateMachine.swift Sources/LidOnce/LidOnceApp.swift \
  -o "$app/Contents/MacOS/LidOnce"
/usr/bin/swiftc -O -framework AppKit Sources/LidOnceCLI/main.swift -o build/lidonce
cp Resources/Info.plist "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
cp Resources/lidonce-guard "$app/Contents/Resources/lidonce-guard"
chmod 755 "$app/Contents/Resources/lidonce-guard"
/usr/bin/xattr -cr "$app"
/usr/bin/codesign --force --sign - "$app"
echo "built $app"
