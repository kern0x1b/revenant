#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${1:-$here/../../../../packages/frameworks/apple-backports/Foundation}
output=${2:-$(runs_fresh revenant-url)}
expectations=${3:-$here/../../device/url_expectations.h}
rm -rf "$output"
mkdir -p "$output/plain" "$output/renamed"
files=""
for file in "$sources"/RevenantURLGrammar.m "$sources"/NSCharacterSet+URLUtilities.m "$sources"/NSString+URLUtilities.m "$sources"/NSURLComponents.m "$sources"/NSURLComponents+*.m; do
    files="$files $file"
done
for file in $files; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w -c "$file" -o "$output/plain/$(basename "$file" .m).o"
done
defines=""
classes=$(nm -U "$output"/plain/*.o | sed -n 's/.* _OBJC_CLASS_\$_\(.*\)$/\1/p' | sort -u)
for class in $classes; do
    defines="$defines -D$class=RevenantHost$class"
done
selectors=""
for pair in $(nm "$output"/plain/*.o | sed -n 's/.*[-+]\[\([A-Za-z0-9_]*\)(Revenant[A-Za-z0-9_]*) \([A-Za-z0-9_]*\).*\]$/\1,\2/p' | sort -u); do
    owner=${pair%%,*} selector=${pair#*,}
    if ! echo " $classes " | tr '\n' ' ' | grep -q " $owner "; then
        selectors="$selectors $selector"
    fi
done
for selector in $selectors; do
    defines="$defines -D$selector=revenantHost_$selector"
done
echo "renamed:$defines"
for file in $files; do
    xcrun clang -fobjc-arc -fvisibility=hidden -w $defines -c "$file" -o "$output/renamed/$(basename "$file" .m).o"
done
xcrun clang -fobjc-arc -w "$here/diff.m" "$output"/renamed/*.o -framework Foundation -o "$output/diff"
"$output/diff" "$output/expectations.json"
xmake l "$here/../../common/embed.lua" "$output/expectations.json" "$expectations" url_expectations
