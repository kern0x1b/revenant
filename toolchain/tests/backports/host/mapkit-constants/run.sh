#!/bin/sh
# The value of every constant this port carries, measured from the host's own MapKit and compared
# with what the port carries. The values in the port's five constant object files were read out of
# the host the same way; this is the test that says they still are, and it fails the moment a name
# is missing from the host's framework, so a value the port invented cannot pass.
#
# The two lists come from the port's own constant files, so the probe covers exactly what the port
# carries. The port's objects are compiled with each name renamed to revenantHost_*, and Apple's own
# MapKit answers for the unrenamed name beside it: the two values are therefore in one process, one
# from this port and one from Apple's own framework, and compared.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/MapKit}
build=${MAPKIT_CONSTANTS_BUILD:-$(runs_folder revenant-mapkit-constants)}
sources="MKLaunchOptions71 MKLaunchOptions90 MKMapItemNames11 MKPointOfInterestCategories134 MKPointOfInterestCategories16 MKPointOfInterestCategories18"
rm -rf "$build"
mkdir -p "$build"
files=""
for source in $sources; do
    files="$files $port/$source.m"
done
# shellcheck disable=SC2086
grep -h '^extern NSString \*const ' $files | sed 's/^extern NSString \*const //; s/;$//' > "$build/strings.txt"
# shellcheck disable=SC2086
grep -h '^extern const double ' $files | sed 's/^extern const double //; s/;$//' > "$build/numbers.txt"
renames=""
while read -r name; do
    [ -n "$name" ] || continue
    renames="$renames -D$name=revenantHost_$name"
done < "$build/strings.txt"
while read -r name; do
    [ -n "$name" ] || continue
    renames="$renames -D$name=revenantHost_$name"
done < "$build/numbers.txt"
objects=""
for source in $sources; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -I"$port" -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
# One comparison per name, generated from the two lists: the port's name and Apple's name are both
# compile-time identifiers here, so a name Apple's own framework does not export does not link and
# the test says so itself.
{
    echo '#import <Foundation/Foundation.h>'
    echo '#import <stdio.h>'
    echo 'extern void revenantCompareString(NSString *symbol, NSString *ours, NSString *theirs);'
    echo 'extern void revenantCompareNumber(NSString *symbol, double ours, double theirs);'
    awk '{printf "extern NSString *const %s;\nextern NSString *const revenantHost_%s;\n", $0, $0}' "$build/strings.txt"
    awk '{printf "extern const double %s;\nextern const double revenantHost_%s;\n", $0, $0}' "$build/numbers.txt"
    sed 's/.*/static void revenantCheck_&(void) { revenantCompareString(@"&", revenantHost_&, &); }/' "$build/strings.txt"
    sed 's/.*/static void revenantCheck_&(void) { revenantCompareNumber(@"&", revenantHost_&, &); }/' "$build/numbers.txt"
    echo 'static void (*const revenantChecks[])(void) = {'
    awk '{printf "    revenantCheck_%s,\n", $0}' "$build/strings.txt" "$build/numbers.txt"
    echo '};'
    echo 'static const unsigned revenantCount = sizeof(revenantChecks) / sizeof(revenantChecks[0]);'
} > "$build/probe.h"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -framework Foundation -framework MapKit -framework CoreLocation \
    -I"$build" "$here/differential.m" $objects -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
