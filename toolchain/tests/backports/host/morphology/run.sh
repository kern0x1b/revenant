#!/bin/sh
# The morphology family against the host's own: the port's five classes renamed with -D beside the host's five, in one process,
# over the 172 cases in expected.txt. Build from scratch every time, so nothing stale is ever measured.
#
# Before anything is built, two greps on the one file that holds the class, the description and the 17.0 side table. A
# -description that prints a bare number for the eight settings is the form the port had for two commits, and it came back twice
# through a rewrite that was meant to change something else; the first grep says the eight name tables are still there and the
# second says the %ld form is not. Either failing stops here, before a binary exists to be run.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
FOUNDATION=${FOUNDATION:-$root/packages/a/apple-backports/Foundation}
CLASSES=CharonMorphology.m

table=$FOUNDATION/$CLASSES
named=$(grep -c 'charon_grammatical(' "$table" || true)
bare=$(grep -cE 'grammaticalGender = %ld' "$table" || true)
printf 'guard  %s: charon_grammatical( %s times (want >= 8), "grammaticalGender = %%ld" %s times (want 0)\n' "$CLASSES" "$named" "$bare"
[ "$named" -ge 8 ] || { echo "the eight name tables are not in $CLASSES" >&2; exit 1; }
[ "$bare" -eq 0 ] || { echo "$CLASSES prints a bare number for grammaticalGender" >&2; exit 1; }

# The build lives under the worktree and not in /tmp: nothing this project builds goes to /tmp.
BUILD=${BUILD:-$root/.agent-work/build/morphology}
rm -rf "$BUILD"
mkdir -p "$BUILD"
RENAME="-DNSMorphology=charonHostNSMorphology -DNSMorphologyCustomPronoun=charonHostNSMorphologyCustomPronoun
        -DNSMorphologyPronoun=charonHostNSMorphologyPronoun -DNSInflectionRule=charonHostNSInflectionRule
        -DNSInflectionRuleExplicit=charonHostNSInflectionRuleExplicit"
flags="-fobjc-arc -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-nullability-completeness"
echo "link   $BUILD/differential"
# shellcheck disable=SC2086
xcrun clang $flags $RENAME -I "$FOUNDATION" -o "$BUILD/differential" \
    "$here/differential.m" \
    "$FOUNDATION/CharonMorphology.m" "$FOUNDATION/NSMorphologyCustomPronoun16.m" "$FOUNDATION/NSMorphologyInflectionConcepts18.m" \
    "$FOUNDATION/NSMorphologyPronoun.m" "$FOUNDATION/NSInflectionRule.m" "$FOUNDATION/NSInflectionRuleExplicit.m" \
    -framework Foundation
[ -x "$BUILD/differential" ] || { echo "no binary at $BUILD/differential" >&2; exit 1; }
echo "bytes $(wc -c < "$BUILD/differential" | tr -d ' ')"

# Which image answered, before the verdict is read: dladdr on both sides' IMPs, so a
# comparison that quietly compared the port with itself cannot pass unnoticed.
xcrun clang $flags $RENAME -I "$FOUNDATION" -o "$BUILD/provenance" "$here/provenance.m" \
    "$FOUNDATION/CharonMorphology.m" "$FOUNDATION/NSMorphologyCustomPronoun16.m" "$FOUNDATION/NSMorphologyInflectionConcepts18.m" \
    "$FOUNDATION/NSMorphologyPronoun.m" "$FOUNDATION/NSInflectionRule.m" \
    "$FOUNDATION/NSInflectionRuleExplicit.m" -framework Foundation
"$BUILD/provenance"

verdict=$("$BUILD/differential" "$here/expected.txt" | tail -1) || verdict="checks=? failures=?"
echo "verdict $verdict"
case "$verdict" in
    "checks=0 failures=0") exit 1 ;;   # nothing compared: the golden file did not load
    *"failures=0") exit 0 ;;
    *) exit 1 ;;
esac
