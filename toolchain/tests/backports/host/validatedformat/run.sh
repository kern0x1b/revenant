#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/frameworks/apple-backports/Foundation}
build=${VALIDATEDFORMAT_BUILD:-$(runs_folder revenant-validatedformat-host)}
rm -rf "$build"
mkdir -p "$build"
compile() {
    xcrun clang -fobjc-arc -w "-DREVENANT_VALIDATED_FORMAT=\"$1\"" "$here/fuzz.m" -framework Foundation -o "$2"
}
if [ "${1:-}" != --mutants ]; then
    compile "$FOUNDATION/NSString+ValidatedFormat.m" "$build/fuzz"
    exec "$build/fuzz" "${1:-20000}" "${2:-0}"
fi
missed=0
tab=$(printf '\t')
while IFS="$tab" read -r name change; do
    cp "$FOUNDATION/NSString+ValidatedFormat.m" "$build/mutant.m"
    perl -0pi -e "$change" "$build/mutant.m"
    if cmp -s "$FOUNDATION/NSString+ValidatedFormat.m" "$build/mutant.m"; then
        echo "STALE $name: the change no longer applies"
        missed=1
        continue
    fi
    if ! compile "$build/mutant.m" "$build/mutant" 2> "$build/mutant.log"; then
        echo "BROKEN $name: the mutant does not compile"
        missed=1
        continue
    fi
    if "$build/mutant" "${2:-20000}" "${3:-1}" > "$build/mutant.log"; then
        echo "MISSED $name"
        missed=1
    else
        echo "caught $name:$(grep -m1 'smallest:' "$build/mutant.log" | cut -d: -f2-)"
    fi
done < "$here/mutants.txt"
exit $missed
