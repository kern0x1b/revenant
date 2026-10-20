#!/bin/sh
# run.sh - AVPlayerItem's automatically loaded asset keys (iOS 7.0), the host against the port.
#
# probe.m runs five steps on a one-second movie made by the host's AVAssetWriter (see probe.m). It is built twice:
#   host  plain, against Apple's AVPlayerItem;
#   port  with REVENANT_PORT_BUILD=1, against RevenantStandInPlayerItem (standin/), where the port's category
#         AVFoundation/AVPlayerItemAutomaticKeys7.m is compiled from a scratch copy whose class is the stand-in.
#
# The join is row by row, and every row must be equal with ONE allowance, written in the port's facts file:
#   A.duration.status, A.tracks.status and A.playable.status before the item is in a player. Apple's status is 0
#   (Unknown) there, because it loads the keys when the item goes into a player; the port loads them when the item is
#   made, so its status is 1 (Loading) or 2 (Loaded). The allowance holds only for those three keys, only where the
#   host says 0 and the port says 1 or 2.
#
# The owner lines are checked against the build: the host answers from the system, the port from this executable.
#
# A planted control: AVPLAYERITEMKEYS_MUTANT=1 changes the release's default key list in the scratch copy, and the run
# must go red. Run DIRECTLY, not through heavy.sh: a few compiles and runs of a few seconds each.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
src=$root/packages/frameworks/apple-backports/AVFoundation/AVPlayerItemAutomaticKeys7.m
run=${AVPLAYERITEMKEYS_RUN:-$(runs_folder v-avf-item-keys)}
mutant=${AVPLAYERITEMKEYS_MUTANT:-0}
build=$run/build
rm -rf "$build"
mkdir -p "$build/src"
# shellcheck disable=SC2086
flags="-fobjc-arc -w -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo"

# 1. the host table
# shellcheck disable=SC2086
xcrun clang $flags "$here/probe.m" -o "$build/host" > "$build/host.log" 2>&1 || {
    echo "RUN FAILED: the host probe did not build"; head -8 "$build/host.log"; exit 1; }
timeout 120 "$build/host" "$run" > "$build/host.table" 2> "$build/host.err" || {
    echo "RUN FAILED: the host probe stopped (exit $?)"; head -5 "$build/host.err"; exit 1; }

# 2. the port's category, from a scratch copy: its class is the stand-in, with the stand-in's header imported
port_src=$build/src/AVPlayerItemAutomaticKeys7.m
{
    echo '#import "RevenantStandInPlayerItem.h"'
    sed -e 's/AVPlayerItem/RevenantStandInPlayerItem/g' "$src"
} > "$port_src"
[ "$(grep -c '@implementation RevenantStandInPlayerItem (RevenantAutomaticallyLoadedAssetKeys7)' "$port_src")" = 1 ] || {
    echo "RUN FAILED: the scratch copy does not carry the category on the stand-in, so this run proves nothing"; exit 1; }
if [ "$mutant" != 0 ]; then
    before='return @\[@"duration", @"availableMediaCharacteristicsWithMediaSelectionOptions"\];'
    after='return @[@"duration", @"tracks"];'
    [ "$(grep -c "$before" "$port_src")" = 1 ] || { echo "RUN FAILED: the mutant target is not unique, so this run proves nothing"; exit 1; }
    sed -e "s/$before/$after/" "$port_src" > "$port_src.mutant" && mv "$port_src.mutant" "$port_src"
    [ "$(grep -c 'return @\[@"duration", @"tracks"\];' "$port_src")" = 1 ] || {
        echo "RUN FAILED: the mutant did not take, so this run proves nothing"; exit 1; }
    echo "# the mutation applied: the release's default key list is duration and tracks"
fi
# shellcheck disable=SC2086
xcrun clang $flags -fobjc-arc -I "$here/standin" -c "$here/standin/RevenantStandInPlayerItem.m" -o "$build/standin.o" > "$build/standin.log" 2>&1 || {
    echo "RUN FAILED: the stand-in did not compile"; head -8 "$build/standin.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $flags -I "$here/standin" -c "$port_src" -o "$build/keys.o" > "$build/keys.log" 2>&1 || {
    echo "RUN FAILED: the port's category did not compile against the stand-in"; head -8 "$build/keys.log"; exit 1; }

# 3. the port table: the same probe, the stand-in and the category in place of Apple's class
# shellcheck disable=SC2086
xcrun clang $flags -DREVENANT_PORT_BUILD=1 -I "$here/standin" "$here/probe.m" "$build/keys.o" "$build/standin.o" -o "$build/port" > "$build/port.log" 2>&1 || {
    echo "RUN FAILED: the port probe did not link"; head -8 "$build/port.log"; exit 1; }
timeout 120 "$build/port" "$run" > "$build/port.table" 2> "$build/port.err" || {
    echo "RUN FAILED: the port probe stopped (exit $?)"; head -5 "$build/port.err"; exit 1; }

# 4. the owners: the host's three members answer from the system, the port's from this executable
for side in host port; do
    want=system; [ "$side" = port ] && want=executable
    for member in playerItemWithAsset:automaticallyLoadedAssetKeys: initWithAsset:automaticallyLoadedAssetKeys: automaticallyLoadedAssetKeys; do
        grep -q "^owner: $member $want\$" "$build/$side.table" || {
            echo "FAIL: the $side table does not show $member answered by $want"; grep '^owner:' "$build/$side.table"; exit 1; }
    done
done

# 5. neither table may be smaller than its claim, and the rows join one for one
for side in host port; do
    want=$(sed -n 's/^rows: \([0-9][0-9]*\)$/\1/p' "$build/$side.table" | tail -1)
    have=$(grep -c ' = ' "$build/$side.table" || true)
    if [ -z "$want" ] || [ "$have" -ne "$want" ]; then
        echo "FAIL: the $side table holds $have rows but the probe reported ${want:-no count}; refusing to compare"
        exit 1
    fi
done
grep ' = ' "$build/host.table" > "$build/host.cmp"
grep ' = ' "$build/port.table" > "$build/port.cmp"
[ "$(wc -l < "$build/host.cmp")" = "$(wc -l < "$build/port.cmp")" ] || { echo "FAIL: the tables have different row counts"; exit 1; }
compared=$(wc -l < "$build/host.cmp" | tr -d ' ')

# 6. the join, with the one allowance and nothing else
status=0
verdict=$(paste -d'|' "$build/host.cmp" "$build/port.cmp" | awk -F'|' '
    BEGIN { same = 0; allowed = 0; bad = 0 }
    {
        split($1, h, " = "); split($2, p, " = ");
        if (h[1] != p[1]) { print "FAIL row order: " $1 " vs " $2; bad++; next }
        if (h[2] == p[2]) { same++; next }
        if ((h[1] == "A.duration.status" || h[1] == "A.tracks.status" || h[1] == "A.playable.status") && h[2] == "0" && (p[2] == "1" || p[2] == "2")) {
            allowed++; next
        }
        print "FAIL " h[1] ": host " h[2] ", port " p[2]; bad++
    }
    END { printf "same %d, allowed %d, bad %d\n", same, allowed, bad; exit (bad ? 1 : 0) }') || status=$?
echo "host $(wc -l < "$build/host.cmp" | tr -d ' ') rows, port $(wc -l < "$build/port.cmp" | tr -d ' ') rows; compared $compared"
echo "$verdict"

if [ "$mutant" != 0 ]; then
    if [ "$status" = 0 ]; then
        echo "FAIL: the mutation left the tables equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed"
    exit 0
fi
if [ "$status" != 0 ]; then
    echo "FAIL: the port's table differs from the host's beyond the allowance"
    exit 1
fi
echo "ok  every compared row: the port answers what the host answers, with the one allowance"
exit 0
