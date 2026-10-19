#!/bin/sh
# run.sh - the plane's extent: the release's defaults, the release's archive keys, and a round trip of
# the port's own archive.
#
# There is no host oracle for this class, and this says so instead of implying one: this Mac's
# ARKit.framework has no ARPlaneExtent (dlopen by path answers a handle; NSClassFromString answers
# nil), so nothing here is compared with what a host ARKit answers. What is measured is the port's own
# object against the release's own code, whose addresses and strings are in facts/ARKit/PlaneExtent.md,
# and the checks the host does allow: the three literal keys in the archive's own bytes, the round trip
# of three floats, and +supportsSecureCoding beside a class that adopts nothing.
#
# `--mutants` changes one thing at a time in a *copy* of the port's sources under .agent-work and
# requires the run to go red. The checkout is never touched. The mutants are the ones that matter
# here: a key renamed (the archive check sees it), a key swapped between two properties (only the
# round trip sees it, because both keys are still present), and a default from -init changed (only the
# defaults check sees it).
#
# The port's object is compiled into this harness with the class name renamed, so what runs is the
# port's own code.

set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
ARKit=$repo/packages/a/apple-backports/ARKit
runs=${RUNS:-$repo/.agent-work/runs/arkit-planeextent-host}
mkdir -p "$runs"

renames=-DARPlaneExtent=CharonPortARPlaneExtent

build() {
    src=$1
    xcrun clang -fobjc-arc -w -O1 $renames -I"$src" -c "$src/ARPlaneExtent16.m" -o "$runs/port.o"
    xcrun clang -fobjc-arc -w -O1 -I"$here" "$here/extent.m" "$runs/port.o" \
        -framework Foundation -o "$runs/extent"
}

port() {
    build "$ARKit"
    "$runs/extent"
}

port | tee "$runs/plain.txt"
grep -q '^VERDICT ok' "$runs/plain.txt" || { echo "FAIL: the check is not green"; exit 1; }
[ "${1:-}" = "--mutants" ] || { echo "ok the extent's archive carries the release's own keys"; exit 0; }

survived=0
mutant() {
    label=$1; from=$2; to=$3
    copy="$runs/mutant"
    rm -rf "$copy"; mkdir -p "$copy"
    cp "$ARKit/ARPlaneExtent16.m" "$ARKit/CharonARKitPlaneExtent.h" "$copy/"
    python3 - "$copy/ARPlaneExtent16.m" "$from" "$to" <<'PY' || { echo "MUTANT NOT APPLIED: $label"; survived=$((survived + 1)); return; }
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if text.count(old) != 1:
    sys.stderr.write("needle occurs %d times, expected 1\n" % text.count(old))
    sys.exit(1)
open(path, "w").write(text.replace(old, new))
PY
    if build "$copy" >/dev/null 2>&1 && "$runs/extent" > "$runs/mutant.txt" 2>&1 && grep -q '^VERDICT ok' "$runs/mutant.txt"; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "ok mutant killed: $label"
        grep '^FAIL' "$runs/mutant.txt" 2>/dev/null | head -3 | sed 's/^/    /'
    fi
}

# A key the release does not use. The archive then carries neither `origin` nor the property name.
mutant "the rotation written under the property name instead of origin" \
    '[coder encodeFloat:_rotationOnYAxis forKey:@"origin"]' \
    '[coder encodeFloat:_rotationOnYAxis forKey:@"rotationOnYAxis"]'
# Two keys swapped: every key is still in the archive, so only the round trip can see it.
mutant "width and height written under each other's keys" \
    '    [coder encodeFloat:_width forKey:@"width"];
    [coder encodeFloat:_height forKey:@"height"];' \
    '    [coder encodeFloat:_width forKey:@"height"];
    [coder encodeFloat:_height forKey:@"width"];'
# A default from -init that the release does not use.
mutant "a fresh extent whose width is zero" \
    '    _width = -1.0f;' \
    '    _width = 0.0f;'
# The one answer the release gives unconditionally (mov w0, #1; ret at 0x1af14f2b8).
mutant "an extent that declines secure coding" \
    '+ (BOOL)supportsSecureCoding { return YES; }' \
    '+ (BOOL)supportsSecureCoding { return NO; }'
# Value equality replaced by the identity NSObject would answer with on its own.
mutant "isEqual: that answers identity only" \
    '    if (self == object)
        return YES;' \
    '    if (self == object)
        return YES;
    if (1)
        return NO;'
# The release's own tolerance replaced by an exact comparison, which is the loosening in the other
# direction: it would answer NO where the release answers YES.
mutant "isEqual: that demands bit equality" \
    'fabsf(_rotationOnYAxis - other->_rotationOnYAxis) < FLT_EPSILON' \
    'fabsf(_rotationOnYAxis - other->_rotationOnYAxis) == 0'

if [ "$survived" -eq 0 ]; then
    echo "ok every mutant is killed: the check can fail, and it fails for the right reason"
else
    echo "FAIL: $survived mutant(s) survived"
fi
exit "$survived"