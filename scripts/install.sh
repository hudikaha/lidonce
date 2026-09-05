#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
mkdir -p "$HOME/Applications" "$HOME/bin"
rm -rf "$HOME/Applications/LidOnce.app"
cp -R build/LidOnce.app "$HOME/Applications/LidOnce.app"
/usr/bin/xattr -cr "$HOME/Applications/LidOnce.app"
"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" \
  -f "$HOME/Applications/LidOnce.app" 2>/dev/null || true
cp build/lidonce "$HOME/bin/lidonce"
chmod 755 "$HOME/bin/lidonce"
echo "installed $HOME/Applications/LidOnce.app"
echo "installed $HOME/bin/lidonce"
echo "next: ./scripts/install-privilege.sh"
