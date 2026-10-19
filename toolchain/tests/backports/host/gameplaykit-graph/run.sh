#!/bin/sh
# run.sh -- the port's pathfinding graphs held against what the host's own GameplayKit answers.
#
# The host is the oracle and it is measured, not called: the port's classes and the host's carry the same
# names, and ld64 binds each objc_msgSend$selector stub to one implementation of it, so a process with both
# would answer one of the two for the other. measure.m prints what the host answers and differential.m holds
# the port to those numbers; run.sh prints measure.m's own output beside the checks, so every expectation can
# be re-measured rather than trusted.
#
# The port's own sources are compiled with no framework in the picture, so its names are its own and the
# test calls it exactly as an application would.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/GameplayKit}
out=${BUILD:-$(runs_fresh revenant-gameplaykit-graph)}
mkdir -p "$out"

# The shared arithmetic and the one search, then the THREE objects of the family, because an object holds the
# API of exactly one release: GKGraph9.m and GKObstacleGraph9.m are the iOS 9 classes, GKGraph10.m the 10.0
# ones (relcheck measures GKGraph10's half at 10.0.1).
xcrun clang -fobjc-arc -w -I"$port" -c "$port/RevenantGKGraph.m" -o "$out/RevenantGKGraph.o"
xcrun clang -fobjc-arc -w -I"$port" -c "$port/GKGraph9.m" -o "$out/GKGraph9.o"
xcrun clang -fobjc-arc -w -I"$port" -c "$port/GKObstacleGraph9.m" -o "$out/GKObstacleGraph9.o"
xcrun clang -fobjc-arc -w -I"$port" -c "$port/GKGraph10.m" -o "$out/GKGraph10.o"
xcrun clang -fobjc-arc -w -framework Foundation "$here/differential.m" "$out/RevenantGKGraph.o" \
    "$out/GKGraph9.o" "$out/GKObstacleGraph9.o" "$out/GKGraph10.o" -o "$out/differential"
"$out/differential"

# The oracle, so that every expectation in the differential can be re-measured rather than trusted.
xcrun clang -fobjc-arc -w -framework Foundation -framework GameplayKit "$here/measure.m" -o "$out/measure"
"$out/measure" > "$out/host-measured.txt"
echo "the host's own answers, for comparison with the checks above:"
sed 's/^/  /' "$out/host-measured.txt"