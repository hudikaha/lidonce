#!/bin/sh
set -eu

user=$(/usr/bin/id -un)
case "$user" in
  *[!A-Za-z0-9._-]*|'') echo "unsupported user name: $user" >&2; exit 1 ;;
esac

tmp=$(/usr/bin/mktemp /tmp/lidonce-sudoers.XXXXXX)
trap 'rm -f "$tmp"' EXIT HUP INT TERM
{
  echo 'Cmnd_Alias LIDONCE_PMSET = /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1'
  echo "$user ALL=(root) NOPASSWD: LIDONCE_PMSET"
} > "$tmp"

/usr/sbin/visudo -cf "$tmp"
echo "LidOnce will install this restricted rule:"
cat "$tmp"
/usr/bin/osascript - "$tmp" <<'APPLESCRIPT'
on run argv
  set src to quoted form of item 1 of argv
  do shell script "/usr/bin/install -o root -g wheel -m 0440 " & src & " /etc/sudoers.d/lidonce" with administrator privileges
end run
APPLESCRIPT
echo "installed /etc/sudoers.d/lidonce"
