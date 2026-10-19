#!/bin/sh
# run.sh — every registry row of packages/s/swift-runtime/registry/ that says `implemented` names a
# type the overlay sources declare.
#
# Why: the family review of 2026-09-28 found `EnvironmentResource` used four times in ARView.swift,
# declared nowhere, and with a row calling it implemented — a row with no code behind it, in a
# module that did not compile. No gate sees it: a Swift module exports no symbol a dylib inventory
# holds, so `check_registry` cannot read these rows (registry/README.md), and the light guard and
# the host differential did not either. This is the check for that class.
#
# What it is not: a behavioural check. A member row is not examined — a member of a declared type is
# the host differential's business — and a row that is not implemented is not examined, because an
# absent row is supposed to have no declaration.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
xmake l "$here/swiftregistry.lua"
