#!/bin/sh
# run.sh - AVContentKeySpecifier (14.5) and AVContentKeyResponse (10.3, factories 10.3, 11.0, 13.0), the port
# against the host's own framework.
#
# probe.m is built twice: plain, where every name is Apple's, and with the two class names renamed to the port's own
# (revenant_host_AVContentKeySpecifier, revenant_host_AVContentKeyResponse) and the port's two object files linked in, so
# the same questions are asked of the port's classes in the same binary. Both outputs are one line per answer, and
# diff is the check: the port must say what the host says, line for line. No divergence is named for these classes,
# so ALLOWED_DIFF is empty; the probe asks nothing about a class's name or its private subclasses for that reason.
#
# What makes it a check and not a comparison:
#   * the output is asserted non-empty on both sides, so an empty table is a red and not a clean diff;
#   * a name the port does not define is a link error, so a missing class cannot read as "both absent";
#   * the run is PLANTED: MUTANT=1 compiles a copy of AVContentKeySpecifier145.m whose stored key system is not
#     copied, and the diff must show differences on labels that are not allowed; CONTROL=1 runs the unmutated
#     sources through the same path and must pass;
#   * a build that fails is RUN FAILED with the compiler's first line, never a noticed mutation.
#
# Run DIRECTLY: a few compiles and two runs, not through heavy.sh.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/frameworks/apple-backports/AVFoundation
build=${AVF_CONTENTKEY_BUILD:-$(runs_folder avf-contentkey-build)}
mutant=${MUTANT:-0}
control=${CONTROL:-0}
ALLOWED_DIFF=""
rm -rf "$build"
mkdir -p "$build"
frameworks="-framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo"
renames="-DAVContentKeySpecifier=revenant_host_AVContentKeySpecifier -DAVContentKeyResponse=revenant_host_AVContentKeyResponse"
specifier="$avf/AVContentKeySpecifier145.m"
response="$avf/AVContentKeyResponse103.m"
for f in "$specifier" "$response"; do
    [ -f "$f" ] || { echo "FAIL: $f does not exist, so the port's classes are not there to check"; exit 1; }
done
if [ "$mutant" = 1 ] && [ "$control" = 1 ]; then
    echo "FAIL: MUTANT and CONTROL are separate runs"
    exit 1
fi

if [ "$mutant" = 1 ]; then
    # The planted wrong answer: the key system is kept by reference, not copied, so a mutable argument changed later
    # shows through the object.
    sed 's/_keySystem = \[keySystem copy\];/_keySystem = keySystem;/' "$specifier" > "$build/AVContentKeySpecifier145.m"
    if cmp -s "$specifier" "$build/AVContentKeySpecifier145.m"; then
        echo "FAIL: the planted mutation did not change the source, so the run would not prove anything"
        exit 1
    fi
    specifier="$build/AVContentKeySpecifier145.m"
fi

clang -fobjc-arc -Wall -c $renames "$specifier" -o "$build/specifier.o" 2> "$build/specifier-build.log" || {
    echo "RUN FAILED: the port's AVContentKeySpecifier145.m did not build:"; head -1 "$build/specifier-build.log"; exit 1; }
clang -fobjc-arc -Wall -c $renames "$response" -o "$build/response.o" 2> "$build/response-build.log" || {
    echo "RUN FAILED: the port's AVContentKeyResponse103.m did not build:"; head -1 "$build/response-build.log"; exit 1; }
clang -fobjc-arc $renames "$here/probe.m" "$build/specifier.o" "$build/response.o" $frameworks -o "$build/port" 2> "$build/port-link.log" || {
    echo "RUN FAILED: the port probe did not link:"; head -1 "$build/port-link.log"; exit 1; }
clang -fobjc-arc "$here/probe.m" $frameworks -o "$build/host" 2> "$build/host-link.log" || {
    echo "RUN FAILED: the host probe did not link:"; head -1 "$build/host-link.log"; exit 1; }

"$build/host" > "$build/host.txt" 2> "$build/host-err.txt" || { echo "RUN FAILED: the host probe exited non-zero"; exit 1; }
"$build/port" > "$build/port.txt" 2> "$build/port-err.txt" || { echo "RUN FAILED: the port probe exited non-zero"; exit 1; }
rows=$(wc -l < "$build/host.txt" | tr -d ' ')
[ "$rows" -gt 30 ] || { echo "FAIL: the host probe printed $rows lines, so there is nothing to compare"; exit 1; }

# diff exits 1 when the two sides differ, which is an answer; anything above 1 is diff itself failing.
diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt" || [ $? -eq 1 ] || { echo "RUN FAILED: diff did not run"; exit 1; }
# The label a differing line belongs to is its first word: "<label> ..." in either side.
differing=$(grep '^[<>]' "$build/diff.txt" | awk '{print $2}' | sort -u | tr '\n' ' ')
unexpected=""
for label in $(echo "$differing"); do
    case " $ALLOWED_DIFF " in
        *" $label "*) ;;
        *) unexpected="$unexpected $label" ;;
    esac
done
if [ -z "$unexpected" ]; then
    if [ "$mutant" = 1 ]; then
        echo "avf-contentkey-values: FAIL the planted mutation was not noticed"
        exit 1
    fi
    echo "avf-contentkey-values: OK ($rows answers; the port and the host agree line for line)"
    exit 0
fi
if [ "$mutant" = 1 ]; then
    echo "avf-contentkey-values: planted mutation noticed on:$unexpected"
    exit 0
fi
echo "avf-contentkey-values: FAIL the port differs from the host on:$unexpected"
grep "^[<>]" "$build/diff.txt" | head -20
exit 1
