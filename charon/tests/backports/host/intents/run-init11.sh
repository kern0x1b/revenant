#!/bin/sh
# run-init11.sh - the harness in init11.m, and the builds that make its verdict mean something.
#
# init11.m reads the HOST's own Intents, so it measures the release side of the sixteen
# registry/Intents/ios11.json -[X init] rows: it is the per-class run that each row's `source` used
# to say was owed ("the other hundred and two are the same rule applied to the same header, which is
# a claim and not a measurement until that harness runs"), done for the sixteen this slice owns.
# What is measured for the PORT's side is by nm over the armv7 object the 11.0 band builds, and it
# is written out in packages/a/apple-backports/facts/Intents/Init11.md. Nothing here executes armv7
# and this script does not pretend otherwise.
#
# THE BASELINE IS TWO RED LINES, AND IT IS PINNED HERE ON PURPOSE. The measurement is not "sixteen
# green": on this host the system's own -init answers for fourteen of the sixteen and not for two.
# -[INCancelRideIntentResponse init] and -[INSendRideFeedbackIntentResponse init] return nil after
# the system logs "Unable to initialize '<class>'. Please make sure that your intent definition file
# is valid.", and the object it could not initialize takes the process down on teardown. Both are
# facts about the HOST's Intents on a machine with no intent definition file, and a run that demanded
# sixteen green would be demanding a different host than this one. So the baseline is the measured
# pair, this script fails when the red set is not exactly that pair, and the plant below has to add
# to the pair rather than merely appear.
#
# Four builds:
#
#   1. the measurement         -> the red set is exactly MEASURED_RED, and the control passed.
#   2. the plant               -> PLANTS=one-wrong must make MORE lines red than the baseline. A
#                                 check that cannot fail guards nothing, so this build runs and the
#                                 script FAILS when the plant does not show.
#   3. names the host lacks    -> every line red. The control for "a zero is the release's answer and
#                                 not the reader's" is a run whose table holds names the host does not
#                                 carry, and the script fails when that build passes.
#   4. the registry crosscheck -> every -[X init] row the 11.0 registry carries has a line in
#                                 init11.m. The harness is the measurement FOR the registry, so a row
#                                 with no line is a row nothing measures, and this finds it.
#
# sh tests/backports/host/intents/run-init11.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
registry=${REGISTRY:-$repo/packages/a/apple-backports/registry/Intents/ios11.json}
build=${INTENTS_INIT11_BUILD:-$repo/.agent-work/build/init11}
rm -rf "$build"
mkdir -p "$build"
flags="-fobjc-arc -w -Wno-deprecated-declarations"
cd "$repo"

# The host's own answer, measured on 2026-10-01 by this script's build 1 and written out in
# packages/a/apple-backports/facts/Intents/Init11.md. Two classes, one reason.
MEASURED_RED="INCancelRideIntentResponse INSendRideFeedbackIntentResponse"

redset() {
    sed -n 's/^  \([A-Za-z_]*\)  *->  FAIL.*/\1/p' "$1" | sort -u
}

# The harness exits red ? 1 : 0, so a run with red lines EXITS 1 by design and `set -e` would abort
# this script before the red set was read. The status is therefore captured and then CHECKED, once per
# build, rather than swallowed: a run that exits 0 when red lines were expected, or 1 when none were,
# fails this script like any other disagreement.
echo "== 1. the measurement: the host's own -init for the sixteen"
xcrun clang $flags "$here/init11.m" -framework Intents -framework Foundation -o "$build/init11"
status=0
"$build/init11" > "$build/measured.log" 2>&1 || status=$?
cat "$build/measured.log"
got=$(redset "$build/measured.log" | tr '\n' ' ' | sed 's/ $//')
want=$(echo "$MEASURED_RED" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$status" -ne 1 ]; then
    echo "  intents-11 init: FAIL the run exited $status, and $want is measured, so it must exit 1"
    exit 1
fi
if [ "$got" != "$want" ]; then
    echo "  intents-11 init: FAIL the red set is [$got], and the measurement in"
    echo "  packages/a/apple-backports/facts/Intents/Init11.md records [$want]"
    exit 1
fi
grep -q "control: " "$build/measured.log" || {
    echo "  intents-11 init: FAIL the run printed no control, so its zeros prove nothing"
    exit 1
}
echo "  intents-11 init: the red set is exactly the two classes the host cannot initialize"

echo "== 2. the plant: one class of its own must report a property that is not zero"
status=0
PLANTS=one-wrong "$build/init11" > "$build/plant.log" 2>&1 || status=$?
sed -n 's/^/  /p' "$build/plant.log"
plant=$(redset "$build/plant.log" | wc -l | tr -d ' ')
base=$(echo "$want" | wc -w | tr -d ' ')
if [ "$status" -ne 1 ] || [ "$plant" -le "$base" ]; then
    echo "  intents-11 init: FAIL the plant exited $status with $plant red against a baseline of"
    echo "  $base, so it must exit 1 and add a line, and the check cannot fail"
    exit 1
fi
echo "  intents-11 init: the plant is red on top of the baseline, as it must be"

echo "== 3. names the host does not carry: every line red, and the control still speaks"
sed 's/^    "\(IN[A-Za-z_]*\)",$/    "ccharonHost_\1",/' "$here/init11.m" > "$build/absent.m"
if cmp -s "$build/absent.m" "$here/init11.m"; then
    echo "  intents-11 init: FAIL the substitution changed nothing, so build 3 proves nothing"
    exit 1
fi
xcrun clang $flags "$build/absent.m" -framework Intents -framework Foundation -o "$build/absent"
status=0
"$build/absent" > "$build/absent.log" 2>&1 || status=$?
# The same reader as builds 1 and 2, and the same reason it is the right one: a line that reports a
# name absent says "not present on this host", and counting that phrase with a second pattern would
# be a second reader to keep in step with the first.
absent=$(sed -n 's/^  \([A-Za-z_]*\)  *->  FAIL not present on this host.*/\1/p' "$build/absent.log" | sort -u | wc -l | tr -d ' ')
if [ "$status" -eq 0 ] || [ "$absent" -ne 16 ]; then
    echo "  intents-11 init: FAIL a run against names the host lacks exited $status with $absent of"
    echo "  16 reported absent, and all 16 must be"
    exit 1
fi
grep -m1 "control: " "$build/absent.log" | sed 's/^/  /'
echo "  intents-11 init: 16 of 16 absent, and the control still found the framework's names"

echo "== 4. the registry cross-check: every -[X init] row in ios11.json has a line here"
missing=$(python3 - "$registry" "$here/init11.m" <<'PY'
import json, re, sys
registry, harness = sys.argv[1], sys.argv[2]
rows = [e["api"] for e in json.load(open(registry))["entries"]
        if e["kind"] == "method" and e["api"].endswith(" init]")]
lines = set(re.findall(r'"(IN\w+)"', open(harness).read()))
want = {a[2:-6] for a in rows}          # -[INFoo init] -> INFoo, dropping " init]"
print("\n".join(sorted(want - lines)))
PY
)
if [ -n "$missing" ]; then
    echo "  intents-11 init: FAIL these -init rows have no line in init11.m:"
    echo "$missing" | sed 's/^/    /'
    exit 1
fi
python3 - "$registry" <<'PY' | sed 's/^/  /'
import json, sys
rows = [e["api"] for e in json.load(open(sys.argv[1]))["entries"]
        if e["kind"] == "method" and e["api"].endswith(" init]")]
print("intents-11 init: %d -init rows, every one has a line in init11.m" % len(rows))
PY
echo "  intents-11 init: PASS"