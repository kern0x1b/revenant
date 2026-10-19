#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${NATURALLANGUAGE_HARNESS:-$here/../../device}
build=${NATURALLANGUAGE_BUILD:-$(runs_folder charon-naturallanguage-host)}
rm -rf "$build"
mkdir -p "$build"
renames="-DNLTokenizer=CharonHostNLTokenizer -DNLLanguageRecognizer=CharonHostNLLanguageRecognizer"
for name in $(sed -n 's/^NSString \*const \(NLLanguage[A-Za-z]*\) .*/\1/p' "$FOUNDATION/NLLanguage.m"); do
    renames="$renames -D$name=CharonHost$name"
done
objects=""
for source in NLLanguage.m NLTokenizer.m NLLanguageRecognizer.m; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -c "$FOUNDATION/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework NaturalLanguage -framework Foundation -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" | head -60 || true
echo "log=$build/log"
exit $result
