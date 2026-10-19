#!/bin/sh
# run.sh - the port's P-256 signing and verification, held to the host's own Security in BOTH
# directions: a signature the port makes must verify under the host's SecKeyVerifySignature, and one
# the host makes must verify through the port. `--mutated` breaks the port's sign on purpose and every
# check must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
package=${PACKAGE:-$here/../../../../packages/m/micro-ecc}
build=${MICROECC_BUILD:-$(runs_fresh revenant-microecc)}
rm -rf "$build"
mkdir -p "$build"
clone="$build/micro-ecc"
git clone --quiet --depth 1 https://github.com/kmackay/micro-ecc.git "$clone" > /dev/null 2>&1
[ -f "$clone/uECC.h" ] || { echo "FAIL micro-ecc did not clone"; exit 1; }
xcrun clang -std=c11 -O0 -g -w -fno-strict-aliasing -I"$clone" -I"$package/files" -c "$clone/uECC.c" -o "$build/uECC.o"
xcrun clang -std=c11 -O0 -g -w -fno-strict-aliasing -I"$clone" -I"$package/files" -c "$package/files/RevenantCKWebAuth.c" -o "$build/wrapper.o"
# ASan, because a crash inside CF is nearly always the caller's arguments and ASan says which.
xcrun clang -fobjc-arc -fsanitize=address -g -O0 -Wall -Wno-deprecated-declarations -I"$here/../../device" -I"$package/files" \
    "$here/differential.m" "$here/../../device/check.m" "$build/uECC.o" "$build/wrapper.o" \
    -framework Foundation -framework Security -o "$build/differential"
"$build/differential" "$@"
