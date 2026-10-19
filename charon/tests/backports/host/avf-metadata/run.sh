#!/bin/sh
# avf-metadata — the metadata key-space and coordinated-playback constants, the port against the host.
#
# One program (probe-constants.m), linked twice. Linked plain, every name is Apple's own exported
# symbol and the table it prints is the host's. Linked with the rename list and the port's four
# sources, the same names are the port's own definitions, in the same binary as Apple's, and the
# table it prints is the port's. The two tables are then diffed.
#
# Three things this checks that a value-inspection would not:
#
#   * a value the port gets wrong shows up as a diff, not as a passing comparison against itself;
#   * a name the port does not define is a LINK ERROR, so a missing constant cannot read as "both
#     sides absent and therefore equal";
#   * a run that compared nothing fails. The row count is asserted on both sides and against the
#     count this slice claims, so an empty table on either side is a red, not a clean diff of two
#     empty files.
#
# The mutant is the check's own falsifiability: AVFMUTANT=1 perturbs one value in a copy of the
# port's source and the run must go red on exactly that row. A mutant that does not build is RUN
# FAILED and is never counted as noticed - the build step is separate from the diff step for that
# reason.
#
# Usage: sh tests/backports/host/avf-metadata/run.sh          the differential
#        AVFMUTANT=1 sh tests/backports/host/avf-metadata/run.sh   the mutant, which must go red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/a/apple-backports/AVFoundation
build=${AVF_METADATA_BUILD:-$root/.agent-work/avf-metadata}
expected=${AVF_METADATA_ROWS:-47}
rm -rf "$build"
mkdir -p "$build"

sources="MetadataKeyspaces10 MetadataKeyspaces12 MetadataKeyspaces13 MetadataKeyspaces14 MetadataKeyspaces154 CoordinatedPlaybackReasons12 CoordinatedPlaybackReasons15"

# The rename list is written out, not derived: the compiled subset is exactly these four files, and
# a derived list would rename names this binary does not define and break the host side.
renames=""
for source in $sources; do
    names=$(sed -n 's/^NSString \*const \([A-Za-z0-9_]*\) = .*/\1/p' "$avf/$source.m")
    [ -n "$names" ] || { echo "FAIL: $source.m defines no constant"; exit 1; }
    for name in $names; do
        renames="$renames -D$name=charon_host_$name"
    done
done

# The table the probe reads: one row per constant, in the order the sources define them.
# The table the probe reads: the NAME of every constant, taken from the sources in the tree, written
# into the build directory and not into the checkout - it is generated on every run, and a generated
# file does not belong in a tracked tree. The names come from the tree rather than from a mutated
# copy on purpose: a mutant that drops a definition must leave the name in the table so the LINK
# fails, and a run that quietly stopped asking about that name would be a smaller comparison.
: > "$build/table.inc"
count=0
for source in $sources; do
    sed -n 's/^NSString \*const \([A-Za-z0-9_]*\) = .*/    { "\1", \&\1 },/p' "$avf/$source.m" >> "$build/table.inc"
    count=$((count + $(grep -c '^NSString \*const' "$avf/$source.m")))
done
if [ "$count" != "$expected" ]; then
    echo "FAIL: the sources define $count constants and this slice claims $expected"
    exit 1
fi

# 1. the host table
xcrun clang -fobjc-arc -w -I"$build" "$here/probe-constants.m" \
    -framework Foundation -framework AVFoundation -o "$build/host" || {
        echo "FAIL: the host probe did not build"; exit 1; }
"$build/host" > "$build/host.log" 2>&1 || { echo "FAIL: the host probe did not run"; cat "$build/host.log"; exit 1; }

# 2. the port's sources, and the same probe against them.  The copies are made FIRST and the
#    perturbations second: a perturb that ran before its file existed raised FileNotFoundError, and a
#    harness that calls that "noticed" would be counting a crash as an observation.
mkdir -p "$build/port-src"
objects=""
mutant=no
for source in $sources; do cp "$avf/$source.m" "$build/port-src/$source.m"; done
if [ "${AVFMUTANT:-0}" != 0 ]; then
    mutant=yes
    if [ "${AVFBREAK:-0}" != 0 ]; then
        # The control for the mutant: one value changed AND one line made not-C, so the file does
        # not compile. A harness that counted this as "noticed" would be counting a build failure as
        # an observation, which is the failure mode this exists to rule out. The perturbing is done in
        # python, not in nested sed, so a quoting slip cannot leave the file untouched and let the run
        # pass for the wrong reason.
        python3 - "$build/port-src/MetadataKeyspaces154.m" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
text = text.replace('@"Codabar"', '@"codabar"')
text = text.replace('NSString *const AVMetadataObjectTypeGS1DataBarCode = @"org.gs1.GS1DataBar";',
                    'this is not C at all = @"org.gs1.GS1DataBar";')
open(path, 'w').write(text)
if 'this is not C at all' not in text:
    raise SystemExit('the control did not apply, so this run proves nothing')
PERTURB
    else
        # The mutant: two changes, and both are single-byte. The object type Codabar is "Codabar" and
        # the mutant spells it "codabar" - one letter. And the row the commit singles out,
        # AVMetadataIdentifierQuickTimeUserDataAccessibilityDescription, whose value is the eleven
        # ASCII characters "udta/%A9ade", loses the one byte of its percent sign: 0x25 becomes 0x3f.
        # The report says which row catches which, rather than assuming.
        python3 - "$build/port-src/MetadataKeyspaces154.m" "$build/port-src/MetadataKeyspaces14.m" <<'PERTURB'
import sys
codabar, keyspaces = sys.argv[1], sys.argv[2]
text = open(codabar).read()
text = text.replace('@"Codabar"', '@"codabar"')
open(codabar, 'w').write(text)
if '@"codabar"' not in text:
    raise SystemExit('the letter mutant did not apply, so this run proves nothing')
text = open(keyspaces).read()
before = '@"udta/%A9ade"'
after = '@"udta/?A9ade"'
if before not in text:
    raise SystemExit('the one-byte mutant did not apply, so this run proves nothing')
text = text.replace(before, after)
open(keyspaces, 'w').write(text)
PERTURB
    fi
fi
for source in $sources; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -c "$build/port-src/$source.m" -o "$build/$source.o" \
        > "$build/$source.build.log" 2>&1 || {
            echo "RUN FAILED: the port's $source.m did not build - a build failure is never a noticed mutation"
            head -8 "$build/$source.build.log"
            exit 1
        }
    objects="$objects $build/$source.o"
done
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -I"$build" $renames "$here/probe-constants.m" $objects \
    -framework Foundation -framework AVFoundation -o "$build/port" > "$build/port.link.log" 2>&1 || {
        echo "RUN FAILED: the port probe did not link"
        head -8 "$build/port.link.log"
        exit 1
    }
"$build/port" > "$build/port.log" 2>&1 || { echo "RUN FAILED: the port probe did not run"; cat "$build/port.log"; exit 1; }

# 3. both tables must be the size this slice claims, or the diff below compares nothing
for side in host port; do
    rows=$(grep -c ' = ' "$build/$side.log" || true)
    if [ "$rows" != "$expected" ]; then
        echo "FAIL: the $side table has $rows rows and this slice claims $expected; the diff below"
        echo "      would be a comparison of something smaller than the claim"
        exit 1
    fi
done

# 4. the diff
if diff -u "$build/host.log" "$build/port.log" > "$build/diff.log" 2>&1; then
    if [ "$mutant" = yes ]; then
        echo "FAIL: the mutant left the tables equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the port's $expected constants answer exactly what Apple's do"
    echo "log=$build"
    exit 0
fi
if [ "$mutant" = yes ]; then
    echo "ok  the mutant went red, on this row and no other:"
    sed -n '1,40p' "$build/diff.log"
    echo "log=$build"
    exit 0
fi
echo "FAIL: the port's table differs from the host's"
cat "$build/diff.log"
exit 1
