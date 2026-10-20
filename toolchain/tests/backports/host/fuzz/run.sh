#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
usage="usage: run.sh [--mutants] percentencoding|stringcase|calendar [rounds] [seed]"
mutants=no
if [ "${1:-}" = --mutants ]; then
    mutants=yes
    shift
fi
suite=${1:?$usage}
shift
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
build=${FUZZ_BUILD:-$(runs_folder revenant-fuzz-host)}/$suite
case $suite in
    percentencoding) sources="NSString+URLUtilities.m NSCharacterSet+URLUtilities.m NSData+Base64.m"; locales= ;;
    stringcase) sources="NSString+LocalizedCase.m NSString+Containment.m NSString+Transform.m"; locales="en_US tr_TR" ;;
    calendar) sources="NSCalendar+Components.m NSCalendar+Weekend.m NSDateComponents+Validation.m RevenantCalendarUnits.m"; locales= ;;
    *) echo "no fuzzer $suite" >&2; exit 2 ;;
esac
if [ $mutants = yes ]; then
    missed=0
    tab=$(printf '\t')
    mutant=$build-mutant
    while IFS="$tab" read -r name file change; do
        rm -rf "$mutant"
        mkdir -p "$mutant/Foundation"
        cp -R "$FOUNDATION"/ "$mutant/Foundation/"
        perl -0pi -e "$change" "$mutant/Foundation/$file"
        if cmp -s "$FOUNDATION/$file" "$mutant/Foundation/$file"; then
            echo "STALE $name: the change no longer applies"
            missed=1
            continue
        fi
        if FOUNDATION="$mutant/Foundation" FUZZ_BUILD="$mutant/build" sh "$here/run.sh" "$suite" "${1:-0}" "${2:-1}" > "$mutant.log" 2>&1; then
            echo "MISSED $name"
            missed=1
        elif grep -q ' error: ' "$mutant.log"; then
            echo "BROKEN $name: the mutant does not compile"
            missed=1
        elif grep -q '^FAIL ' "$mutant.log"; then
            echo "caught $name: $(grep '^FAIL ' "$mutant.log" | head -1 | cut -d: -f1 | cut -c6-)"
        else
            echo "caught $name: the port crashed"
        fi
    done < "$here/mutants/$suite.txt"
    rm -rf "$mutant" "$mutant.log"
    exit $missed
fi
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
rm -rf "$build"
mkdir -p "$build/plain" "$build/prefixed" "$build/renamed"
for s in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$FOUNDATION/$s" -o "$build/plain/$s.o"
done
printf '#import <Foundation/Foundation.h>\n' > "$build/prefixed/declarations.h"
for s in $sources; do
    runs_xmake l "$here/../prefix_selectors.lua" "$FOUNDATION/$s" "$build/prefixed/$s" revenantHost_ --declarations="$build/prefixed/declarations.h" -fobjc-arc $quiet -- "$build"/plain/*.o
done
for s in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -I"$FOUNDATION" -include "$build/prefixed/declarations.h" -c "$build/prefixed/$s" -o "$build/renamed/$s.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__port_catlist\0\0/g' "$build/renamed/$s.o"
done
xcrun clang -fobjc-arc -w -I"$here" "$here/$suite.m" "$here/fuzz.m" "$here/../foundation2/host-attach.c" "$build"/renamed/*.o -framework Foundation -o "$build/fuzz"
if [ -z "$locales" ]; then
    FUZZ_TOLERATED="$here/tolerated/$suite.txt" exec "$build/fuzz" "${1:-0}" "${2:-0}"
fi
status=0
for locale in $locales; do
    echo "locale $locale"
    FUZZ_TOLERATED="$here/tolerated/$suite.txt" "$build/fuzz" "${1:-0}" "${2:-0}" -AppleLocale "$locale" -AppleLanguages "(${locale%_*})" || status=1
done
exit $status
