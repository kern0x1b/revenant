#!/bin/sh
# shift-and-run.sh - the negative control for the host kind, in the tree rather than in a scratch note.
#
# It builds a scratch copy of the port's own NSUnitTemperature.m with the Fahrenheit constant moved, and
# runs the same differential over it, so a control that is meant to be red is shown red rather than
# asserted. The scratch copy is built here and is not tracked; the script is.
#
# The digit moved is not the last one the port writes, and that is the point of the control. One ulp at
# 255.37222222222428 is 2.842e-14 and the 17th digit is worth 1e-14, so 255.37222222222428 and
# 255.37222222222429 are the same double: a control that moved that digit and passed would have proved
# nothing. This moves one the double does hold.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
FOUNDATION=$root/packages/a/apple-backports/Foundation
scratch=$root/.agent-work/runs/shifted-constant
overlay=$scratch/Foundation
rm -rf "$overlay"; mkdir -p "$overlay"
for f in "$FOUNDATION"/*; do ln -s "$f" "$overlay/$(basename "$f")"; done
rm "$overlay/NSUnitTemperature.m"
sed 's/constant:255\.37222222222428/constant:255.3722222222524/' \
    "$FOUNDATION/NSUnitTemperature.m" > "$overlay/NSUnitTemperature.m"
echo "the scratch copy holds 255.3722222222524 where the port writes 255.37222222222428"
echo "the clean run of the same differential, for the pair to read against:"
(cd "$here" && sh run.sh | tail -1)
echo "and the shifted one, which must be red:"
(cd "$here" && FOUNDATION=$overlay sh run.sh | grep -E "^FAIL|checks," | head -4) || true
