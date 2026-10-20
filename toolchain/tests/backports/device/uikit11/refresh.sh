#!/bin/sh
# Runs the host tests this tweak replays and writes their answers to uikit11-expectations.h.
set -eu
echo "FAIL device/uikit11/refresh.sh: its Python steps are gone and not yet ported to Lua: expectations.py" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
host=$here/../../host
work=$(runs_fresh revenant-uikit11-expectations)
rm -rf "$work"
mkdir -p "$work"
for test in interactions systemspacing gesturename batchupdates contentsize; do
    TMPDIR="$work/" sh "$host/$test/run.sh" > "$work/$test.out" 2>/dev/null
done
python3 "$here/expectations.py" interactions="$(runs_folder charon-interactions-host)/log" systemspacing="$work/systemspacing.out" \
    gesturename="$work/gesturename.out" batchupdates="$work/batchupdates.out" contentsize="$work/contentsize.out" \
    > "$here/uikit11-expectations.h"
