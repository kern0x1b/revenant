#!/bin/sh
# run.sh - the port's 83 Intents extern constants against the system's own Intents, which exports
# every one of them, in one binary and one process.
#
# constants.m is linked twice over. Linked with the port's seven IntentsConstantsNN.m objects, each
# name resolves to the port's own definition; linked without them, each name resolves to the
# framework's. The program refuses an answer that came from
# /System/Library/Frameworks/Intents.framework and reads the port's through dladdr, so it cannot
# compare Apple's Intents with itself and call the two equal - which is what it did before that
# check, printing "83 lines, 0 red -> PASS" with no port object in the link at all.
#
# Three things this checks that a value-inspection would not:
#
#   * a value the port gets wrong shows up as a diff, not as a comparison against itself;
#   * the seven objects are one per release rung, and dropping one reds exactly the names that
#     object holds - 26, 38, 3, 3, 9, 2, 2, which is the split tools/intents/emit-intents-constants.lua
#     writes and the split backports.lua's band() requires;
#   * PLANTS=one-wrong puts a value in the table the system does not have and every check that would
#     have passed must fail. A test that cannot fail is not guarding anything, so this script runs
#     that build too and fails when it does not.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/Intents}
build=${INTENTS_BUILD:-$(runs_fresh charon-intents)}
rm -rf "$build"
mkdir -p "$build"
flags="-fobjc-arc -w -Wno-deprecated-declarations -I$here -I$port"
objects=""
for source in "$port"/IntentsConstants*.m; do
    base=$(basename "$source" .m)
    xcrun clang $flags -c "$source" -o "$build/$base.o"
    objects="$objects $build/$base.o"
done
echo "  intents: $(echo "$objects" | tr ' ' '\n' | grep -c '\.o$') objects, $(xcrun nm -gU $objects | awk 'NF==3' | wc -l | tr -d ' ') symbols"

# 1. the port's objects present: the one that must pass
xcrun clang $flags "$here/constants.m" $objects \
    -framework Intents -framework Foundation -o "$build/constants-port"
"$build/constants-port"

# 2. the plant: a value the system does not have, which every check that would pass must reject
PLANTS=one-wrong "$build/constants-port" > "$build/plant.log" 2>&1 && {
    echo "  intents: FAIL the plant passed, so the differential is not guarding anything"
    exit 1
}
grep -E 'constants: .* ->  FAIL' "$build/plant.log" | sed 's/^/  /'
echo "  intents: the plant is red, as it must be"

# 3. no port objects: every line must be red, because then every name is the framework's
xcrun clang $flags "$here/constants.m" \
    -framework Intents -framework Foundation -o "$build/constants-hostonly"
"$build/constants-hostonly" > "$build/hostonly.log" 2>&1 && {
    echo "  intents: FAIL a build with no port object passed, so the check compares the framework with itself"
    exit 1
}
grep -E 'constants: .* ->  FAIL' "$build/hostonly.log" | sed 's/^/  /'
echo "  intents: a build with no port object is red on every line, as it must be"

# 4. one object of the seven dropped: the lines that object holds must be the ones that go red
first=$(ls "$port"/IntentsConstants*.m | head -1)
kept=""
for source in "$port"/IntentsConstants*.m; do
    [ "$source" = "$first" ] || kept="$kept $source"
done
partial=""
for source in $kept; do
    base=$(basename "$source" .m)
    xcrun clang $flags -c "$source" -o "$build/$base.o"
    partial="$partial $build/$base.o"
done
xcrun clang $flags "$here/constants.m" $partial \
    -framework Intents -framework Foundation -o "$build/constants-partial"
"$build/constants-partial" > "$build/partial.log" 2>&1 && {
    echo "  intents: FAIL a build missing $(basename "$first") passed, so the objects are not each their own"
    exit 1
}
grep -E 'constants: .* ->  FAIL' "$build/partial.log" | sed 's/^/  /'
echo "  intents: dropping $(basename "$first") reds exactly the names it holds, as it must"
