#!/bin/sh
# run.sh - the port's own install of the user info value provider against this host's NSError.
#
#   ./run.sh            the control
#   ./run.sh mutant     the port's file with the install skipped, which must turn the verdict red
#
# The nineteen cases are the ones tests/backports/device/errorprovider.m asks on a device with the library
# loaded, and the answers they are held to are this Mac's own, as recorded by
# tests/backports/host/errorprovider/run.sh into device/errorprovider-expectations.h: the differential asks
# those same questions of NSError first, so a row that fails is the port and not a recording that drifted.
#
# The port's file is a category on a system class, so its selectors are renamed by prefix_selectors.py
# rather than by a -D, and the six methods are reached through the install pointed at a class of the test's
# own: +load cannot be exercised here, because this Foundation has carried the provider API since macOS 10.11
# and its +load returns without touching anything. The selectors the install replaces are the release's own
# spellings, and they are spelled as strings in the file on purpose - a rename that moved them would move
# the release's spelling with them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${SOURCES:-$here/../../../../packages/a/apple-backports/Foundation}
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh revenant-errorproviderinstall)}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-nullability-completeness"
mkdir -p "$build/plain" "$build/prefixed"

cp "$sources/NSError+UserInfoValueProvider.m" "$build/port.m"
cp "$build/port.m" "$build/port.pristine"
if [ "${1:-}" = "mutant" ]; then
    # The install skipped. Every one of the six methods is NSError's own since 10.0, so a category's copy of
    # one is never attached and this is the only thing that puts the provider in front of the release's own
    # method: with the install skipped, the release's own method answers every case, which is what a
    # process without the port answers.
    sed -i.bak 's/^    for (NSString \*name in keys) {$/    return;\n    for (NSString *name in keys) {/' "$build/port.m"
    echo "MUTANT: the install returns before it replaces a method"
fi
# A MUTATION THAT CHANGED NOTHING IS NOT A MUTANT, and a runner that prints MUTANT either way makes a green
# control look defended. The comparison is against the copy as it was before the mutation.
if [ "${1:-}" = "mutant" ] && cmp -s "$build/port.pristine" "$build/port.m"; then
    echo "MUTANT FAILED: the copy is byte-identical to the file before the mutation, so nothing was"
    echo "mutated and a green verdict would prove nothing. The sed target is not in the file."
    exit 2
fi
rm -f "$build"/*.bak

xcrun clang -fobjc-arc -w $quiet -c "$build/port.m" -o "$build/plain/port.o"
printf '#import <Foundation/Foundation.h>\n' > "$build/prefixed/declarations.h"
runs_xmake l "$here/../prefix_selectors.lua" "$build/port.m" "$build/prefixed/port.m" revenantHost_ \
    --declarations="$build/prefixed/declarations.h" -fobjc-arc $quiet -- "$build/plain/port.o"
xcrun clang -fobjc-arc -w $quiet -include "$build/prefixed/declarations.h" -c "$build/prefixed/port.m" -o "$build/port.o"
# The renamed categories are not attached to anything: the answers under test are the install's, and the
# install is pointed at a class of the test's own, so the host's Foundation keeps the methods it has.
xcrun clang -fobjc-arc -w $quiet -I"$device" "$here/differential.m" "$device/check.m" "$device/errorprovider-cases.m" \
    "$build/port.o" -framework Foundation -o "$build/differential"
if "$build/differential" > "$build/differential.log" 2>&1; then result=0; else result=$?; fi
cat "$build/differential.log"
checks=$(sed -n 's/^checks=\([0-9]*\).*/\1/p' "$build/differential.log" | tail -1)
failures=$(sed -n 's/^checks=.*failures=\([0-9]*\).*/\1/p' "$build/differential.log" | tail -1)
divergences=$(sed -n 's/^checks=.*divergences=\([0-9]*\)$/\1/p' "$build/differential.log" | tail -1)
if [ "$result" -eq 0 ]; then
    echo "VERDICT: green - the port answers what this host's NSError answers, on ${checks:-0} checks and ${divergences:-0} written-down divergence(s)"
else
    echo "VERDICT: RED - ${failures:-?} of ${checks:-?} checks differ"
fi
echo "errorproviderinstall: exit=$result log=$build/differential.log"
exit "$result"
