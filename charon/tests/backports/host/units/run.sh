#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh charon-units)}
sources=${SOURCES:-$(cat "$here/sources.txt")}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers"
rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -I"$FOUNDATION" -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
done
renames=""
for name in $(xcrun nm -gU "$BUILD"/plain/*.o | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=CharonHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet $renames -I"$FOUNDATION" -c "$FOUNDATION/$source" -o "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$BUILD"/renamed/*.o -framework Foundation -o "$BUILD/differential"
# -v also writes the numbers the mapper's host kind reads, under the run directory. The default output is
# untouched: without -v the file is not written and the differential prints only its summary.
if [ "${1:-}" = "-v" ]; then
    values="$here/../../../../.agent-work/runs/units/host-values.tsv"
    mkdir -p "$(dirname "$values")"
    # The header is written here and not in the program: the counts are the program's own summary line,
    # and the date and the command belong to the run. The rows go to a body file the program appends to,
    # and this is what the mapper reads, so a row can cite a run and a command.
    status=0
    output=$(HOST_VALUES="$values.body" "$BUILD/differential" "$@" 2>&1) || status=$?
    printf '%s\n' "$output"
    [ "$status" -eq 0 ] || exit "$status"
    summary=$(printf '%s\n' "$output" | tail -1)
    checks=$(printf '%s' "$summary" | sed -n 's/^\([0-9][0-9]*\) checks.*/\1/p')
    failures=$(printf '%s' "$summary" | sed -n 's/^[0-9][0-9]* checks, \([0-9][0-9]*\) failures.*/\1/p')
    {
        printf '# checks %s failures %s run %s cmd sh tests/backports/host/units/run.sh -v\n' \
            "$checks" "$failures" "$(date -u +%Y-%m-%d)"
        printf '# class\tunit\tdirection\tv\thost %%17g\thost bits\tport bits\tverdict\n'
        cat "$values.body"
    } > "$values"
    rm -f "$values.body"
    echo "host values: $values"
else
    "$BUILD/differential" "$@"
fi
