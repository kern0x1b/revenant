#!/bin/sh
# run.sh -- the port's state machines, entity/component system, behaviours, rules, distributions and
# shuffle held against what the host's own GameplayKit answers.
#
# The host is the oracle and it is measured, not called: the port's classes and the host's carry the same
# names, and ld64 binds each objc_msgSend$selector stub to one implementation of it, so a process with
# both would answer one of the two for the other. measure.m prints what the host answers and
# differential.m holds the port to those numbers; this prints measure.m's own output beside the checks,
# so every expectation can be re-measured rather than trusted.
#
# The port's own sources are compiled with no framework in the picture, so its names are its own and the
# test calls it exactly as an application would.
#
# The random sources are in the object list because the distributions and the shuffle draw through them
# and because -[NSArray shuffledArrayWithRandomSource:] hands the array to the source's own
# -arrayByShufflingObjectsInArray:, which GKRandomSource.m carries. That source is NOT the host's: its
# generators are unidentified and its sequences differ (facts/GameplayKit/GKRandomSource.md), which is
# why the distributions and the shuffle are measured through a written script and not through a seed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/frameworks/apple-backports/GameplayKit}
out=${BUILD:-$(runs_fresh revenant-gameplaykit-core)}
mkdir -p "$out"

# The families this differential covers, and the two random sources NSArray's shuffle reaches, all of
# them API of one release: every class below is declared at 9.0 by the SDK's GK_BASE_AVAILABILITY, so
# one object holds one release and no file here mixes with the 10.0 graph object beside them.
objects=""
for source in GKStateMachine GKComponentSystem GKBehavior GKGoal GKRuleSystem GKRandomDistribution \
              RevenantGKRandomCommon GKRandomSource GKARC4RandomSource GKLinearCongruentialRandomSource \
              GKMersenneTwisterRandomSource; do
    xcrun clang -fobjc-arc -w -I"$port" -c "$port/$source.m" -o "$out/$source.o"
    objects="$objects $out/$source.o"
done

# The two methods NSArray carries for the framework, on their own: they are a category on a class the
# release already has, and they reach the source's own shuffle.
xcrun clang -fobjc-arc -w -I"$port" -c "$port/NSArray+GameplayKit.m" -o "$out/NSArray-GameplayKit.o"
objects="$objects $out/NSArray-GameplayKit.o"

xcrun clang -fobjc-arc -w -framework Foundation "$here/differential.m" $objects -o "$out/differential"
"$out/differential"

# The oracle, so that every expectation in the differential can be re-measured rather than trusted.
xcrun clang -fobjc-arc -w -framework Foundation -framework GameplayKit "$here/measure.m" -o "$out/measure"
"$out/measure" > "$out/host-measured.txt"
echo "the host's own answers, for comparison with the checks above:"
sed 's/^/  /' "$out/host-measured.txt"