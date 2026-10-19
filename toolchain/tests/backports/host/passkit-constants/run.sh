#!/bin/sh
# The value of every string constant this port carries for PassKit, measured from the host's own
# PassKit and compared with what the port carries. The values in the port's two constant object
# files were read out of the host the same way; this is the test that says they still are, and it
# fails the moment a name is missing from the host's framework, so a value the port invented cannot
# pass.
#
# The probe is generated from the port's own constant files, so it covers exactly what the port
# carries: the port's objects are compiled with each name renamed to charonHost_*, and Apple's own
# PassKit answers for the unrenamed name beside it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/PassKit}
build=${PASSKIT_CONSTANTS_BUILD:-$(runs_folder charon-passkit-constants)}
sources="PKPassConstants9 PKPassConstants16"
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
    renames="$renames -D$name=charonHost_$name"
done < "$build/strings.txt"
while read -r name; do
    [ -n "$name" ] || continue
    renames="$renames -D$name=charonHost_$name"
done < "$build/numbers.txt"
objects=""
for source in $sources; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -I"$port" -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
{
    echo '#import <Foundation/Foundation.h>'
    echo '#import <stdio.h>'
    echo 'extern void charonCompareString(NSString *symbol, NSString *ours, NSString *theirs);'
    echo 'extern void charonCompareNumber(NSString *symbol, double ours, double theirs);'
    awk '{printf "extern NSString *const %s;%c", $0, 10}' "$build/strings.txt"
    awk '{printf "extern NSString *const charonHost_%s;%c", $0, 10}' "$build/strings.txt"
    awk '{printf "extern const double %s;%c", $0, 10}' "$build/numbers.txt"
    awk '{printf "extern const double charonHost_%s;%c", $0, 10}' "$build/numbers.txt"
    sed 's/.*/static void charonCheck_&(void) { charonCompareString(@"&", charonHost_&, &); }/' "$build/strings.txt"
    sed 's/.*/static void charonCheck_&(void) { charonCompareNumber(@"&", charonHost_&, &); }/' "$build/numbers.txt"
    echo 'static void (*const charonChecks[])(void) = {'
    awk '{printf "    charonCheck_%s,\n", $0}' "$build/strings.txt" "$build/numbers.txt"
    echo '};'
    echo 'static const unsigned charonCount = sizeof(charonChecks) / sizeof(charonChecks[0]);'
} > "$build/probe.h"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -framework Foundation -framework PassKit \
    -I"$build" "$here/differential.m" $objects -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
