# LidOnce

English | [日本語](README_ja.md)

LidOnce is a small native macOS menu-bar app for one closed-lid session.
Arm it, close your MacBook, and let a long-running task continue. When you
open the lid again, LidOnce automatically restores normal sleep behavior.

Its state machine is deliberately small:

```text
OFF -> ARMED -> CLOSED -> OFF
```

Unlike ordinary `caffeinate` utilities, LidOnce controls the system
`disablesleep` setting required to override lid-close sleep. It never changes
that setting until you explicitly arm it.

## Status

This repository currently contains an early implementation. Do not rely on it
for unattended use until the safety and hardware tests are complete.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools
- a MacBook for lid-transition testing

## Build and test

```sh
make test
make build
```

The app is created at `build/LidOnce.app`. To install a development build:

```sh
make install
./scripts/install-privilege.sh
open ~/Applications/LidOnce.app
```

The privilege installer allows only the exact `pmset` commands needed to turn
`disablesleep` on and off. A separate guard process restores normal sleep if
the app exits or crashes during an armed session.

Click the menu-bar icon to enable or disable LidOnce. While it displays `ON`
or `ON N`, another click within 0.5 seconds advances the limit:

```text
ON -> ON 1 -> ON 2 -> ... -> ON 9 -> ON
```

`ON` has no time limit. `ON N` restores normal sleep after N hours if the lid
is still closed. Timing starts when the lid closes, not when you click. The
next activation starts with the last selected limit.

The same settings are available from the command line (case-insensitive):

```sh
lidonce on       # no time limit
lidonce on1      # at most 1 hour after the lid closes
lidonce on2      # at most 2 hours (through on9)
lidonce status   # show off, armed [N], or closed [N]
lidonce off      # restore normal sleep immediately
lidonce open     # launch the menu-bar app
```

Both interfaces use the same safety state machine in the menu-bar app.

### Menu-bar item is missing on macOS 26

macOS may hide third-party items when the menu bar has no remaining display
space, even though the app is enabled in System Settings and AppKit reports
the item as visible. In **System Settings > Menu Bar**, turn off an unused
system item such as Weather to make room for LidOnce.

## Safety

Keeping a MacBook awake in a closed bag can cause heat buildup and battery
drain. LidOnce is intended for short, supervised moves while a task is
running. The released version will include crash recovery and battery and
thermal cutoffs.

## License

[MIT](LICENSE)
