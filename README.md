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

The CLI installed at `~/bin/lidonce` provides `status`, `reset`, and `open`.
It intentionally cannot arm a session independently of the safety state
machine in the menu-bar app.

## Safety

Keeping a MacBook awake in a closed bag can cause heat buildup and battery
drain. LidOnce is intended for short, supervised moves while a task is
running. The released version will include crash recovery and battery and
thermal cutoffs.

## License

[MIT](LICENSE)
