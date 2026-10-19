#!/bin/sh
# run.sh - the renderer's differential, in the name the sweep looks for.
#
# build.sh is the check: it builds the port's UITextDragPreviewRenderer11.m beside the system's own
# under Mac Catalyst and compares the five properties and the arithmetic. This directory had no
# run.sh, so the sweep passed it over as "no run.sh" - the blind spot the sweep exists to close - and
# build.sh's own verdict is repeated here in the sweep's words.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=$("$here/build.sh" 2>&1) && status=0 || status=$?
printf '%s\n' "$out" | tail -20
# build.sh ends "PASS: clean N/M differing, no-condition mutant K/M" when the two sides agree and its
# mutants are all caught, and "FAIL: ..." otherwise. The verdict is that line, read as it is written;
# the counts in the summary below are build.sh's own.
verdict=$(printf '%s\n' "$out" | grep -E '^(PASS|FAIL): ' | tail -1)
if [ -z "$verdict" ]; then
    echo "FAIL: build.sh reached its end without a verdict of its own, so this run cannot be read as one"
    exit 1
fi
clean=$(printf '%s\n' "$verdict" | sed -n 's/.*clean \([0-9][0-9]*\)\/.*/\1/p')
mutant=$(printf '%s\n' "$verdict" | sed -n 's/.*mutant \([0-9][0-9]*\)\/.*/\1/p')
case $verdict in
"PASS: clean 0/"*) echo "checks=${mutant:-1} failures=0"; exit 0 ;;
esac
echo "checks=${mutant:-1} failures=1"
exit 1
