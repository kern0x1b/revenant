#!/bin/sh
# The kSecKeyAlgorithm constants: every value the port carries must be the host's own, and a value
# written from a rule rather than from a measurement must go red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
work=$(cd "$here/../../../.." && pwd)
obj="$work/packages/a/apple-backports/Security/SecurityConstants11_0.m"
build=${BUILD:-$(runs_fresh revenant-security)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
libs="-framework Foundation -framework Security"

# 0. the case is what the names list says, so a constant cannot go unasked
xmake l "$here/gen-security-cases.lua" --check

# 0b. every name the list gives has a registry row and a definition, both ways, and a removed row must go red
xmake l "$here/check-registered.lua" --control

# 1. the host's own Security.framework
xcrun clang $common "$here/main.m" "$here/cases.m" $libs -o "$build/system"
"$build/system" > "$build/system.tsv"
echo "the host answered: $(xmake l "$here/compare.lua" --count "$build/system.tsv")"

# 2. the port's own object
xcrun clang $common -I"$work/packages/a/apple-backports" "$here/main.m" "$here/cases.m" "$obj" $libs -o "$build/port"
"$build/port" > "$build/port.tsv"

# 3. the comparison, and a mutation that must go red
xmake l "$here/compare.lua" "$build/system.tsv" "$build/port.tsv"
api=$(head -1 "$here/algorithms.txt")
cp "$obj" "$build/mutant.m"
xmake l "$here/mutate.lua" "$build/mutant.m" "$api" "NotTheHostsValue" > /dev/null
xcrun clang $common -I"$work/packages/a/apple-backports" "$here/main.m" "$here/cases.m" "$build/mutant.m" $libs -o "$build/mutant"
"$build/mutant" > "$build/mutant.tsv"
if xmake l "$here/compare.lua" "$build/system.tsv" "$build/mutant.tsv" | grep -q "DIFFERS $api"; then
    echo "  caught: $api"
else
    echo "MUTANT SURVIVED: $api"; exit 1
fi
echo "mutations: all caught"
