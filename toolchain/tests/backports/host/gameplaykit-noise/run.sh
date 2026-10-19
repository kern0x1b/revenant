#!/bin/sh
# run.sh -- the port's noise sources held against what the host's own GameplayKit answers.
#
# The host is the oracle and it is measured, not called: the port's classes and the host's carry the
# same names, and ld64 binds each objc_msgSend$selector stub to one implementation of it, so a process
# with both would answer one of the two for the other. measure.m prints what the host answers and
# differential.m holds the port to those numbers.
#
# With no host framework in the picture the port's names are its own, so nothing is renamed and the
# test calls the port exactly as an application would. What the host answers is in the comment above
# every expectation, and measure.m is the file that produced it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/GameplayKit}
out=${BUILD:-$(runs_fresh revenant-gameplaykit-noise)}
mkdir -p "$out"

# The families whose headers this one needs, compiled without the test's own knowledge of them.
xcrun clang -fobjc-arc -w -I"$port" -c "$port/GKNoiseSource.m" -o "$out/GKNoiseSource.o"
xcrun clang -fobjc-arc -w -framework Foundation "$here/differential.m" "$out/GKNoiseSource.o" -o "$out/differential"
"$out/differential"

# The oracle, so that every expectation in the differential can be re-measured rather than trusted.
xcrun clang -fobjc-arc -w -framework Foundation -framework GameplayKit "$here/measure.m" -o "$out/measure"
"$out/measure" > "$out/host-measured.txt"
echo "the host's own answers, for comparison with the checks above:"
sed 's/^/  /' "$out/host-measured.txt"
