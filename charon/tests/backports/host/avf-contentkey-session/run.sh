#!/bin/sh
# run.sh - AVContentKeySession, AVContentKeyRequest and AVContentKey (10.3 to 14.5), the port against the host's own
# framework, and the port's decryption against an independent oracle.
#
# probe.m is built twice: plain, where every name is Apple's, and with the port's class names renamed
# (charon_host_AVContentKeySession, ..._AVContentKeyRequest, ..._AVContentKey, ..._AVContentKeyResponse,
# ..._AVContentKeySpecifier) and the port's object files linked in, so the same questions are asked of the port's
# classes in the same binary. Both outputs are one line per answer, and diff is the check. No divergence is named for
# these classes, so ALLOWED_DIFF is empty.
#
# What makes it a check and not a comparison:
#   * the output is asserted non-empty on both sides, so an empty table is a red and not a clean diff;
#   * a name the port does not define is a link error, so a missing class cannot read as "both absent";
#   * the run is PLANTED: MUTANT=1 compiles a copy of AVContentKeySession103.m that delivers the callbacks for
#     non-nil initialization data, which the host does not, and the diff must show differences on labels that are not
#     allowed; CONTROL=1 runs the unmutated sources through the same path and must pass;
#   * a build that fails is RUN FAILED with the compiler's first line, never a noticed mutation.
#
# Two things the host varies from run to run are not compared on stdout: the error shape of a refused key response
# (stdout says "refused"; the shape goes to stderr), and the order of the success callbacks (printed sorted; the order that
# happened goes to stderr). Their measured distributions are in facts/AVFoundation/ContentKeySession.md. The accept set,
# the refusals themselves and the status are stable on the host and are compared.
#
# The decryption check (vectors.m) is the port's alone: the host has no public decryptor. Its expected values come from
# CommonCrypto's ECB mode, which is a different code path from the CBC and CTR modes the port uses, so it is not the
# port's own answer checked against itself.
#
# Run DIRECTLY: a few compiles and runs, not through heavy.sh.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/a/apple-backports/AVFoundation
build=${AVF_CONTENTKEY_SESSION_BUILD:-$root/.agent-work/avf-contentkey-session-build}
mutant=${MUTANT:-0}
control=${CONTROL:-0}
ALLOWED_DIFF=""
rm -rf "$build"
mkdir -p "$build"
frameworks="-framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo"
renames="-DAVContentKeySession=charon_host_AVContentKeySession -DAVContentKeyRequest=charon_host_AVContentKeyRequest"
renames="$renames -DAVContentKey=charon_host_AVContentKey -DAVContentKeyResponse=charon_host_AVContentKeyResponse"
renames="$renames -DAVContentKeySpecifier=charon_host_AVContentKeySpecifier"
session="$avf/AVContentKeySession103.m"
key="$avf/AVContentKey145.m"
response="$avf/AVContentKeyResponse103.m"
specifier="$avf/AVContentKeySpecifier145.m"
for f in "$session" "$key" "$response" "$specifier"; do
    [ -f "$f" ] || { echo "FAIL: $f does not exist, so the port's classes are not there to check"; exit 1; }
done
if [ "$mutant" = 1 ] && [ "$control" = 1 ]; then
    echo "FAIL: MUTANT and CONTROL are separate runs"
    exit 1
fi

if [ "$mutant" = 1 ]; then
    # The planted wrong answer: the session delivers requests for initialization data it should refuse.
    sed 's/    if (initializationData) return;/    if (NO) return;/' "$session" > "$build/AVContentKeySession103.m"
    if cmp -s "$session" "$build/AVContentKeySession103.m"; then
        echo "FAIL: the planted mutation did not change the source, so the run would not prove anything"
        exit 1
    fi
    session="$build/AVContentKeySession103.m"
fi

for pair in "session:$session" "key:$key" "response:$response" "specifier:$specifier"; do
    name=${pair%%:*}
    src=${pair#*:}
    clang -fobjc-arc -Wall -c -I "$avf" $renames "$src" -o "$build/$name.o" 2> "$build/$name-build.log" || {
        echo "RUN FAILED: the port's $name source did not build:"; grep -m1 'error:' "$build/$name-build.log" || head -1 "$build/$name-build.log"; exit 1; }
done
clang -fobjc-arc $renames "$here/probe.m" "$build/session.o" "$build/key.o" "$build/response.o" "$build/specifier.o" $frameworks -o "$build/port" 2> "$build/port-link.log" || {
    echo "RUN FAILED: the port probe did not link:"; head -1 "$build/port-link.log"; exit 1; }
clang -fobjc-arc "$here/probe.m" $frameworks -o "$build/host" 2> "$build/host-link.log" || {
    echo "RUN FAILED: the host probe did not link:"; head -1 "$build/host-link.log"; exit 1; }

"$build/host" > "$build/host.txt" 2> "$build/host-err.txt" || { echo "RUN FAILED: the host probe exited non-zero"; exit 1; }
"$build/port" > "$build/port.txt" 2> "$build/port-err.txt" || { echo "RUN FAILED: the port probe exited non-zero"; exit 1; }
rows=$(wc -l < "$build/host.txt" | tr -d ' ')
[ "$rows" -gt 100 ] || { echo "FAIL: the host probe printed $rows lines, so there is nothing to compare"; exit 1; }

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
        echo "avf-contentkey-session: FAIL the planted mutation was not noticed"
        exit 1
    fi
    echo "avf-contentkey-session: OK ($rows answers; the port and the host agree line for line)"
else
    if [ "$mutant" = 1 ]; then
        echo "avf-contentkey-session: planted mutation noticed on:$unexpected"
        exit 0
    fi
    echo "avf-contentkey-session: FAIL the port differs from the host on:$unexpected"
    grep "^[<>]" "$build/diff.txt" | head -20
    exit 1
fi

# The port's decryption, against CommonCrypto's ECB mode as the independent oracle (skipped under MUTANT, which is about
# the session).
if [ "$mutant" = 0 ]; then
    clang -fobjc-arc $renames "$here/vectors.m" "$build/key.o" "$build/response.o" "$build/specifier.o" "$build/session.o" $frameworks -o "$build/vectors" 2> "$build/vectors-link.log" || {
        echo "RUN FAILED: the decryption check did not link:"; head -1 "$build/vectors-link.log"; exit 1; }
    "$build/vectors" || { echo "avf-contentkey-session: FAIL the decryption check"; exit 1; }
fi
exit 0
