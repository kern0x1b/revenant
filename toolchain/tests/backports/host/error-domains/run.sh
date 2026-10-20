#!/bin/sh
# run.sh - the three Metal error domain constants against the strings Apple's own Metal holds.
#
# A MUTANT runs last: MTLLibraryErrorDomain has a suffix Apple's does not, so its comparison must turn red.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METAL=${METAL:-$here/../../../../packages/frameworks/apple-backports/Metal}
BUILD=${BUILD:-$(runs_fresh revenant-error-domains)}
sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-isysroot $sdk -fobjc-arc -I$METAL"

rm -rf "$BUILD/mutant-src"
mkdir -p "$BUILD/mutant-src"
xcrun clang $common -c "$METAL/MTLErrorDomains8.m" -o "$BUILD/domains8.o"
xcrun clang $common -c "$METAL/MTLIOErrorDomain16.m" -o "$BUILD/domainsio.o"
xcrun clang $common -framework Foundation -framework Metal -I"$here" "$here/domains.m" "$BUILD/domains8.o" "$BUILD/domainsio.o" -o "$BUILD/domains"
"$BUILD/domains"

echo "the mutant: MTLLibraryErrorDomain carries a suffix Apple's does not"
sed 's/^NSErrorDomain const MTLLibraryErrorDomain = @"MTLLibraryErrorDomain";$/NSErrorDomain const MTLLibraryErrorDomain = @"MTLLibraryErrorDomainX";/' "$METAL/MTLErrorDomains8.m" > "$BUILD/mutant-src/MTLErrorDomains8.m"
if cmp -s "$METAL/MTLErrorDomains8.m" "$BUILD/mutant-src/MTLErrorDomains8.m"; then
    echo "RUN FAILED: the mutation did not change the source" >&2
    exit 1
fi
xcrun clang $common -c "$BUILD/mutant-src/MTLErrorDomains8.m" -o "$BUILD/mutant8.o"
xcrun clang $common -framework Foundation -framework Metal -I"$here" "$here/domains.m" "$BUILD/mutant8.o" "$BUILD/domainsio.o" -o "$BUILD/mutant"
set +e
"$BUILD/mutant" > "$BUILD/mutant.out" 2>&1
set -e
if grep -q "FAIL MTLLibraryErrorDomain: the port's" "$BUILD/mutant.out"; then
    echo "ok   the mutant turns the library domain comparison red"
else
    echo "FAIL: the mutant did not turn the library domain comparison red" >&2
    cat "$BUILD/mutant.out" >&2
    exit 1
fi
