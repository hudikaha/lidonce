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
/usr/bin/sudo /usr/bin/install -o root -g wheel -m 0440 "$tmp" /etc/sudoers.d/lidonce
/usr/bin/sudo -k
echo "installed /etc/sudoers.d/lidonce"

