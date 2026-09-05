# LidOnce

**English (canonical documentation)** | [日本語訳](README_ja.md)

LidOnce is a small native macOS menu-bar app that keeps a MacBook awake for
one closed-lid session. Enable it, close the lid, and let a long-running task
continue. Opening the lid restores normal sleep behavior automatically.

Unlike ordinary `caffeinate` utilities, LidOnce controls the system
`disablesleep` setting required to override lid-close sleep.

## Safety first

Keeping a MacBook awake in a closed bag can cause heat buildup and battery
drain. Use LidOnce only for supervised work and make sure ventilation is
adequate. The current version restores normal sleep when the lid opens, when
a time limit expires, when you turn LidOnce off, and when the app exits or
crashes. It does not yet implement battery-level or thermal cutoffs.

## Requirements

- macOS 13 or newer
- A MacBook
- Xcode Command Line Tools to build from source
- An administrator account for the one-time restricted privilege setup

## Build and install

```sh
git clone https://github.com/hudikaha/lidonce.git
cd lidonce
make test
make install
./scripts/install-privilege.sh
open ~/Applications/LidOnce.app
```

This installs:

- `~/Applications/LidOnce.app`
- `~/bin/lidonce`
- `/etc/sudoers.d/lidonce`

The privilege installer displays a standard macOS administrator dialog. Its
sudoers rule permits only these two commands without another password prompt:

```text
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

No general root shell or unrestricted `pmset` access is granted.

## Menu-bar operation

The icon has no pull-down menu. Click it directly.

| Display | Meaning |
| --- | --- |
| `Zzz` | Off; normal sleep behavior |
| `ON` | Enabled with no time limit |
| `ON 1` ... `ON 9` | Enabled for at most N hours after the lid closes |

A click more than 0.5 seconds after the previous click toggles LidOnce off.
While `ON` or `ON N` is displayed, another click within 0.5 seconds advances
the limit:

```text
ON -> ON 1 -> ON 2 -> ... -> ON 9 -> ON
```

When LidOnce is off, clicking it restores the last selected limit. The initial
limit after launching the app is unlimited (`ON`).

For `ON N`, timing starts when the lid actually closes, not when the icon is
clicked. If the lid is still closed after N hours, LidOnce restores
`disablesleep 0`, allowing the MacBook to sleep. Opening the lid earlier also
restores normal sleep immediately.

## Command line

Commands are case-insensitive. The CLI sends requests to the same running app
and therefore uses the same state machine and safety behavior.

```sh
lidonce on       # Unlimited; equivalent to ON
lidonce on1      # At most 1 hour after the lid closes
lidonce on2      # At most 2 hours; on3 through on9 also work
lidonce off      # Restore normal sleep immediately
lidonce status   # Print the current state
lidonce open     # Launch the menu-bar app
```

`lidonce on`, `on1`, ... `on9` launch the app automatically if necessary.
Examples of `status` output are:

```text
off
armed
armed 2
closed
closed 2
```

`armed` means LidOnce is enabled and waiting for the lid to close. `closed`
means it has observed the closed lid. A trailing number is the hour limit;
no number means unlimited.

## State and failure recovery

The core state machine is:

```text
OFF -> ARMED -> CLOSED -> OFF
```

- `OFF -> ARMED`: the user enables LidOnce and `disablesleep 1` succeeds.
- `ARMED -> CLOSED`: the app observes the lid closing; a timed session starts.
- `CLOSED -> OFF`: the lid opens or the selected time limit expires.
- `ARMED/CLOSED -> OFF`: the user turns LidOnce off.

While enabled, a separate guard process watches the app. If the app exits or
crashes, the guard runs the narrowly authorized `disablesleep 0` command. A
transient failure to read the lid sensor does not change the power setting.

## Menu-bar item is missing on macOS 26

macOS 26 may hide third-party status items when its menu-bar display area is
full, even when System Settings shows the app as enabled and AppKit reports
the item as visible. In **System Settings > Menu Bar**, disable an unused
system item such as Weather to make room. LidOnce and other third-party items
should then appear.

## Development

```sh
make test    # State-machine and click-selection tests
make build   # build/LidOnce.app and build/lidonce
make install # Install the current source build for this user
make clean
```

The app and CLI communicate through files under:

```text
~/Library/Application Support/LidOnce/
```

## Uninstall

First turn LidOnce off, then remove the app, CLI, and restricted sudoers rule:

```sh
~/bin/lidonce off
pkill -x LidOnce
rm -rf ~/Applications/LidOnce.app
rm -f ~/bin/lidonce
sudo rm -f /etc/sudoers.d/lidonce
rm -rf ~/Library/Application\ Support/LidOnce
```

## License

[MIT](LICENSE)
