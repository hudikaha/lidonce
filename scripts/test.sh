#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
mkdir -p build/tests
/usr/bin/swiftc Sources/LidOnce/StateMachine.swift Tests/StateMachineTests.swift \
  -o build/tests/state-machine-tests
build/tests/state-machine-tests

