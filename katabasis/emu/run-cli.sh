#!/bin/sh
# run-cli.sh NAME BINARY SECONDS [ARGS...] — runs a command-line binary on iPhone3,1 iOS 6.0 through charon-runner.
set -eu
LAB=$HOME/Git/projects/ios/emulator-lab
name=$1 binary=$2 seconds=$3; shift 3
source=$HOME/.charon/firmware/rootfs/iPhone3,1/6.0_10A403
args="$*"
PREPARE='"$LAB/scripts/prepare-home.sh" "$ROOTFS"; install -d -m 0777 "$ROOTFS/private/var/charon"; install -d "$ROOTFS/usr/local/bin"; install -m 0755 "'"$binary"'" "$ROOTFS/usr/local/bin/xlate-test"; "$LAB/scripts/install-runner.sh" "$ROOTFS" 60 /usr/local/bin/xlate-test '"$args"
PREPARE="$PREPARE" "$LAB/recompile/emu/boot.sh" "$name" iPhone3,1 "$source" "$seconds"
run="$LAB/recompile/emu/runs.noindex/$name"
cat "$run/rootfs/private/var/charon/verdict.json" 2>/dev/null; echo
cat "$run/rootfs/private/var/charon/test.stdout" 2>/dev/null
cat "$run/rootfs/private/var/charon/test.stderr" 2>/dev/null | head -20
