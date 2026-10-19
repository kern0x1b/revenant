#!/bin/sh
# THE RED CONTROL for the contentunavailable group: the comparison must GO RED when the port answers a
# value the system does not, and must be GREEN on the unplanted source.
#
# WHY THIS GROUP NEEDS ONE MORE THAN THE OTHERS.  The group is built for arm64-apple-ios15.0-macabi,
# where the four iOS 17.0 classes do not exist in the system UIKit at all.  So there IS a system side -
# the test holds UIContentUnavailableTextProperties and friends under their own names and builds the
# port's objects beside them with prefixed selectors - but the class EXISTENCE is carried by the test's
# own @interface declarations rather than by the SDK.  That is a weaker position than a group whose
# system side comes out of a framework, and the review is right that a check which has only ever seen its
# own clean output has not been shown to fail.  So the plant below makes the port answer something the
# system does not and proves the run says so, by NAME.
#
# The plants are made in a SCRATCH COPY of the port source, never in the tree: UIKIT2_SOURCES already
# overrides where the group reads its sources from, so the control points that variable at a copy and
# runs the real run.sh unchanged.  The control asserts the real source is untouched afterwards, so a
# control that forgot to copy could not pass by editing the repository.
#
# What this proves and what it does not: it proves the comparison RESPONDS to a wrong value on a key
# that agrees today, and it names that key.  It does not prove the harness builds the group at all - a
# group that fails to build is a different failure and the run says so in its own words.
#
# Exit 0 when the plant went red and the unplanted source is green.  Exit 1 when the plant stayed green,
# because a control that cannot fail is not a control.  Exit 2 when the unplanted run is already red,
# because then the plant proves nothing and the first thing to fix is the group itself.
set -eu

root=$(cd "$(dirname "$0")/../../../.." && pwd)
here="$root/tests/backports/host/uikit2"
build="$root/.agent-work/runs/uikit2-red-control"
scratch="$build/sources"
source_file="UIContentUnavailableProperties.m"
config_file="UIContentUnavailableConfiguration.m"
attr_file="UIEventAttribution145.m"
attr_group="eventattribution"
logdir="$build/logs"

fail() { echo "RED CONTROL FAILED: $1" >&2; exit 1; }

rm -rf "$build"
mkdir -p "$scratch" "$logdir"

# The plant is on the line count of a FRESH text bag.  It is a key the test asserts on ("a fresh text bag
# holds the same line count") and it is a VALUE, so the group still builds and still links: a plant that
# broke the build would prove the compiler works, not that the comparison works.
#
# The anchor is the ivar's default in -init, which is where a fresh bag's line count is decided.  It is
# _numberOfLines = 0 and NOT `return 0`, because numberOfLines is a synthesised PROPERTY over an ivar -
# there is no getter to edit, and an earlier version of this control matched on "return" and silently
# planted nothing, which the file-unchanged assertion caught.  A control that cannot tell a no-op plant
# from a real one is a control that will one day report a green run as a green plant.
plant_value() {
    src=$1
    dst=$2
    awk '
        /_numberOfLines = 0;/ && !done {
            sub(/_numberOfLines = 0;/, "_numberOfLines = 99;")
            print
            print "        // RED CONTROL: a line count no fresh bag would have"
            done = 1
            next
        }
        { print }' "$src" > "$dst"
}

# The SECOND plant, on the configuration and not on a bag.  It is here because the group grew a whole class
# since the first plant was written, and a control that only proves the bag half responds says nothing about
# the configuration half.  The anchor is the measured default of the text-to-secondary-text padding, which
# the case asks as "the %@ text-to-secondary-text padding" on all three factories - so one planted value
# has to be reported three times, and the control looks for all of them.
# The THIRD plant, on the 14.5 attribution. It is here because a control that only proves the empty-state
# group responds says nothing about a group added later. The anchor is the measured identifier the copy
# builds from, and the case asks it as "the source identifier reads back".
plant_attr_value() {
    src=$1
    dst=$2
    awk '
        /_sourceIdentifier = sourceIdentifier;/ && !done {
            sub(/_sourceIdentifier = sourceIdentifier;/, "_sourceIdentifier = sourceIdentifier + 1;")
            print
            print "            // RED CONTROL: an identifier no caller passed"
            done = 1
            next
        }
        { print }' "$src" > "$dst"
}

plant_config_value() {
    src=$1
    dst=$2
    awk '
        /_textToSecondaryTextPadding = 3;/ && !done {
            sub(/_textToSecondaryTextPadding = 3;/, "_textToSecondaryTextPadding = 33;")
            print
            print "            // RED CONTROL: a padding no measured configuration has"
            done = 1
            next
        }
        { print }' "$src" > "$dst"
}

run_group() {
    label=$1
    sources=$2
    group=${3:-contentunavailable}
    UIKIT2_SOURCES="$sources" UIKIT2_ONLY="$group" \
        sh "$here/run.sh" > "$logdir/$label.txt" 2>&1 || true
}

# 1. GREEN on the real source.  This must pass BEFORE the plant means anything.
echo "== the unplanted group, which must be green"
run_group green "$root/packages/a/apple-backports/UIKit"
green_line=$(grep -E '^contentunavailable: exit=' "$logdir/green.txt" | tail -1 || true)
[ -n "$green_line" ] || { cat "$logdir/green.txt"; fail "the control could not find the group's own result line, so it cannot judge the plant"; }
echo "   $green_line"
case "$green_line" in
    *"exit=0"*) : ;;
    *) sed -n '1,40p' "$logdir/green.txt"; fail "the group is red BEFORE any plant, so a plant here would prove nothing" ;;
esac

# 2. The plant.  A copy of the whole sources directory is made first, so the group has every file it
# lists and only ONE of them differs.
echo "== planting a line count nothing keyed asked for and a padding no measured configuration has, in a scratch copy"
mkdir -p "$scratch"
for f in "$root/packages/a/apple-backports/UIKit/"*.m "$root/packages/a/apple-backports/UIKit/"*.h; do
    [ -f "$f" ] && cp "$f" "$scratch/"
done
# The group's sources reach three headers in the PARENT directory - CharonSayOnce.h through CharonMenus.h,
# which CharonLists.h imports, plus CharonSRGB.h and charon_alias.h - and CharonMenus.h spells that
# "../CharonSayOnce.h".  $scratch is a flat directory, so that path resolves to $build/CharonSayOnce.h and
# nothing else, and every file that transitively includes CharonMenus.h stops compiling.  That is not the
# plant's failure but the control's: a control that cannot build the group it controls reports "no result
# line" instead of "the group went red", which is the wrong answer to the wrong question.  So the parent
# goes beside $scratch, which is what "../" resolves to.
for f in "$root/packages/a/apple-backports/"*.h; do
    [ -f "$f" ] && cp "$f" "$build/"
done
cp "$root/packages/a/apple-backports/UIKit/$source_file" "$build/source.before.m"
cp "$root/packages/a/apple-backports/UIKit/$config_file" "$build/config.before.m"
plant_value "$root/packages/a/apple-backports/UIKit/$source_file" "$scratch/$source_file"
plant_config_value "$root/packages/a/apple-backports/UIKit/$config_file" "$scratch/$config_file"
cmp -s "$build/source.before.m" "$scratch/$source_file" && fail "the plant did not change the file, so it is not a plant"
cmp -s "$build/config.before.m" "$scratch/$config_file" && fail "the second plant did not change its file, so it is not a plant"

# the tree must be untouched, and this asserts it rather than assuming it
cmp -s "$build/source.before.m" "$root/packages/a/apple-backports/UIKit/$source_file" \
    || fail "the plant edited the repository instead of the scratch copy"
cmp -s "$build/config.before.m" "$root/packages/a/apple-backports/UIKit/$config_file" \
    || fail "the second plant edited the repository instead of the scratch copy"

echo "== the planted group, which must be RED and must NAME the key"
run_group red "$scratch"
red_line=$(grep -E '^contentunavailable: exit=' "$logdir/red.txt" | tail -1 || true)
[ -n "$red_line" ] || { sed -n '1,40p' "$logdir/red.txt"; fail "the planted run produced no result line"; }
echo "   $red_line"
# Only the PLANTED KEY is evidence, by its exact line.  main's own buttonconfig group carries an in-harness
# red control that runs alongside and prints its own FAILs, and a filter broad enough to pick those up
# would let this control pass on a failure it did not cause - which is the same mistake as planting on a
# key that was already red.
echo "   the lines the planted group printed:"
grep -E "^FAIL a fresh text bag holds the same line count" "$logdir/red.txt" | sed 's/^/     /' || true
grep -E "^FAIL the (empty|loading|search) text-to-secondary-text padding" "$logdir/red.txt" | sed 's/^/     /' || true

case "$red_line" in
    *"exit=0"*) sed -n '1,40p' "$logdir/red.txt"; fail "the plant left the group GREEN - the comparison does not read this key" ;;
esac

# The point of naming the key: a red run that only says "exit=1" has not told anyone what disagrees.
if ! grep -qiE 'line count|numberOfLines' "$logdir/red.txt"; then
    fail "the group went red but never named the line-count key, so the failure is not attributable"
fi
echo "   the planted run names the line-count key, so the disagreement is attributable"

# The configuration half.  All three factories report the padding, so all three lines have to be there: a
# group that went red on one of them and silent about the other two would be a group that stops at the
# first disagreement, which is a different defect from one that compares everything.
for kind in empty loading search; do
    if ! grep -qE "^FAIL the $kind text-to-secondary-text padding" "$logdir/red.txt"; then
        fail "the planted padding went red without naming the $kind factory, so the comparison stops early"
    fi
done
echo "   the planted run names the padding on all three factories, so the configuration half compares every factory"

# 3. And the real source is still the real source.
cmp -s "$build/source.before.m" "$root/packages/a/apple-backports/UIKit/$source_file" \
    || fail "the run left the repository's source changed"
cmp -s "$build/config.before.m" "$root/packages/a/apple-backports/UIKit/$config_file" \
    || fail "the run left the repository's configuration source changed"

# 4. The attribution group, the same three steps. Kept in the same script because a control is worth
#    exactly as much as the run that reads it: a group with no plant is a group nobody has shown responds.
echo "== the unplanted attribution group, which must be green"
run_group attr-green "$root/packages/a/apple-backports/UIKit" "$attr_group"
attr_green_line=$(grep -E "^$attr_group: exit=" "$logdir/attr-green.txt" | tail -1 || true)
[ -n "$attr_green_line" ] || { cat "$logdir/attr-green.txt"; fail "could not find the attribution group's result line"; }
echo "   $attr_green_line"
case "$attr_green_line" in
    *"exit=0"*) : ;;
    *) sed -n '1,40p' "$logdir/attr-green.txt"; fail "the attribution group is red BEFORE any plant" ;;
esac

cp "$root/packages/a/apple-backports/UIKit/$attr_file" "$build/attr.before.m"
plant_attr_value "$root/packages/a/apple-backports/UIKit/$attr_file" "$scratch/$attr_file"
cmp -s "$build/attr.before.m" "$scratch/$attr_file" && fail "the attribution plant did not change its file, so it is not a plant"
cmp -s "$build/attr.before.m" "$root/packages/a/apple-backports/UIKit/$attr_file" \
    || fail "the attribution plant edited the repository instead of the scratch copy"

echo "== planting an identifier no caller passed, in the same scratch copy"
run_group attr-red "$scratch" "$attr_group"
attr_red_line=$(grep -E "^$attr_group: exit=" "$logdir/attr-red.txt" | tail -1 || true)
[ -n "$attr_red_line" ] || { sed -n '1,40p' "$logdir/attr-red.txt"; fail "the planted attribution run produced no result line"; }
echo "   $attr_red_line"
case "$attr_red_line" in
    *"exit=0"*) sed -n '1,40p' "$logdir/attr-red.txt"; fail "the attribution plant left the group GREEN" ;;
esac
grep -E "^FAIL the source identifier reads back" "$logdir/attr-red.txt" | sed 's/^/     /' || true
if ! grep -qE "^FAIL the source identifier reads back" "$logdir/attr-red.txt"; then
    fail "the attribution group went red without naming the source-identifier key, so it is not attributable"
fi
echo "   the planted attribution run names the source-identifier key"

cmp -s "$build/attr.before.m" "$root/packages/a/apple-backports/UIKit/$attr_file" \
    || fail "the run left the repository's attribution source changed"

echo "RED CONTROL OK: green before, red after, naming the key, tree untouched"