#!/bin/sh
# run.sh - cloudkit's zone differential, in the name the sweep knows.
#
# zone-check.sh is the check and has always been: it runs the four things the family needs and
# reports "zone-check: N failing step(s)" at the end. The sweep looks for a run.sh in every
# directory, so a test whose entry point is called zone-check.sh is passed over as "no run.sh" -
# the same blind spot the sweep exists to close, and cloudkit guarded nothing from the sweep's
# point of view however green it was.
#
# So this runs it and repeats its verdict in the sweep's own words. The counts are read out of
# zone-check.sh's own output, not asserted here: one check per numbered stage it announced, and
# the failing-step count it printed. A run that prints no verdict line is a FAIL rather than a
# pass, because a verdict nobody can read is not one.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=$("$here/zone-check.sh" 2>&1) && status=0 || status=$?
printf '%s\n' "$out" | grep -v '^zone-check: ' || true
fails=$(printf '%s\n' "$out" | sed -n 's/^zone-check: \([0-9][0-9]*\) failing step(s)$/\1/p' | tail -1)
stages=$(printf '%s\n' "$out" | grep -c '^== [0-9]' || true)
if [ -z "$fails" ] || [ "$stages" -eq 0 ]; then
    echo "FAIL: zone-check.sh printed no verdict of its own, so this run cannot be read as one"
    exit 1
fi
echo "checks=$stages failures=$fails"
exit "$status"
