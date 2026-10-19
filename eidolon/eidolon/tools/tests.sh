#!/bin/bash
tests.sh ROOT: compile the engine tests to an object -- no link, no app. tools/module.sh cannot see
Tests/main.swift, and the full build is too slow a loop to find a defect in it.
# tests.sh DIR: compile the engine tests to an object -- no link, no app. The module gates cannot see this
# file, and the full build is the only thing that normally does, which is too slow a loop to find a defect in it.
set -e
ROOT=$1
O=$ROOT/eidolon/out
cd "$ROOT"
source ./pkg-env.sh
mkdir -p "$O/obj" "$O/mc"
"$SWIFTC" $PKGFLAGS $OCFLAGS -disable-availability-checking -wmo -module-name EidolonTests \
  -I "$O/mods" -module-cache-path "$O/mc" -enforce-exclusivity=unchecked -suppress-warnings \
  -c "$O"/../Tests/*.swift -o "$O/obj/EidolonTests.o"
echo "tests compiled"
