#!/bin/sh
# run.sh — checks the HAP crypto layer against the published test vector of every primitive it wraps:
# RFC 7748 for X25519, RFC 8032 for Ed25519, RFC 8439 for ChaCha20-Poly1305, RFC 5869 for HKDF and
# FIPS 180-4 for the two hashes. The crypto is C over a vendored Monocypher, so the check is a host C
# program: there is no framework, no SDK and no device in it, and a difference is a difference in the
# arithmetic rather than in a link.
#
# It builds Monocypher out of the TARBALL the recipe pins, which the shared xmake store's package cache
# keeps, and never from the network: what is checked here must be the bytes the package is built from.
# It used to copy packages/m/monocypher/monocypher.c, a vendored copy this tree deliberately does not
# have: the recipe says why in its own comment - "The sources come from Monocypher's own tarball, not
# from a copy in this tree: xmake builds a package in its own source directory, which does not hold a
# vendored file" - so the harness died on "cp: .../packages/m/monocypher/monocypher.c: No such file or
# directory" while the package itself builds from the tarball every day. Re-vendoring the file would
# put back exactly what the recipe removed, so the sources are read where they are.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
charon=${CHARON:-$here/../../../..}
crypto="$charon/packages/a/apple-backports/HomeKit/CharonHapCrypto.m"
recipe="$charon/packages/m/monocypher/xmake.lua"
build=${BUILD:-$(runs_fresh charon-hapcrypto)}
mkdir -p "$build/monocypher"

# The pin, read out of the recipe rather than written down here: the version and the sha256 both come
# from its add_versions() line, so a bumped Monocypher moves this check with it and a stale copy of
# the digest cannot outlive it. Measured on this machine: the tarball in the cache is
# 38d07179738c0c90677dba3ceb7a7b8496bcfea758ba1a53e803fed30ae0879c, the pin's own.
pin=$(sed -n 's/.*add_versions("\([^"]*\)", "\([a-f0-9]*\)").*/\1 \2/p' "$recipe" | head -1)
version=$(echo "$pin" | cut -d' ' -f1)
sha=$(echo "$pin" | cut -d' ' -f2)
[ -n "$version" ] && [ -n "$sha" ] || {
    echo "FAIL: no add_versions(\"<version>\", \"<sha256>\") in $recipe, so there is no pin to check the"; echo "      Monocypher sources against"
    exit 1; }

# WHERE THE SOURCES ARE. HAPCRYPTO_MONOCYPHER names a tarball or a directory of them; without it the
# shared store's package cache is searched the way the other host tests find an SDK, under $HOME and
# with a version in the path. Nothing outside this machine is used and nothing is fetched.
tarball=${HAPCRYPTO_MONOCYPHER:-}
if [ -z "$tarball" ]; then
    tarball=$(ls "$HOME"/.xmake/cache/packages/*/m/monocypher/"$version"/monocypher-"$version".tar.gz 2>/dev/null | head -1)
fi
if [ -n "$tarball" ] && [ ! -f "$tarball" ]; then
    echo "FAIL: HAPCRYPTO_MONOCYPHER names $tarball, which is not a file"
    exit 1
fi
if [ -z "$tarball" ]; then
    echo "FAIL: no Monocypher $version tarball under \$HOME/.xmake/cache/packages/*/m/monocypher/$version/, so"
    echo "      the crypto this checks cannot be built. Build the package once (xmake require --extra"
    echo "      package=m/monocypher), or set HAPCRYPTO_MONOCYPHER to the tarball or a directory of sources."
    exit 1
fi
got=$(shasum -a 256 "$tarball" | cut -d' ' -f1)
[ "$got" = "$sha" ] || {
    echo "FAIL: $tarball is sha256 $got and the recipe pins $sha, so these are not the sources the package is"
    echo "      built from and nothing here would be checking the same bytes twice"
    exit 1; }
echo "monocypher: $version, sha256 as pinned, from $tarball"

# Monocypher's sources include each other as "monocypher.h", and the release keeps the Ed25519 pair
# under src/optional/ while the two it needs are under src/, so the copies are laid out the way its own
# build lays them out: both sources and both headers in one directory.
tar xzf "$tarball" -C "$build" "monocypher-$version/src/monocypher.c" "monocypher-$version/src/monocypher.h" \
    "monocypher-$version/src/optional/monocypher-ed25519.c" "monocypher-$version/src/optional/monocypher-ed25519.h"
cp "$build/monocypher-$version/src/monocypher.c" "$build/monocypher-$version/src/monocypher.h" \
   "$build/monocypher-$version/src/optional/monocypher-ed25519.c" "$build/monocypher-$version/src/optional/monocypher-ed25519.h" \
   "$build/monocypher/"

cc -O2 -I"$build" -I"$charon/packages/a/apple-backports/HomeKit" \
   -o "$build/vectors" "$here/vectors.c" "$crypto" \
   "$build/monocypher/monocypher.c" "$build/monocypher/monocypher-ed25519.c"

output=$("$build/vectors")
printf '%s\n' "$output"
case "$output" in
    *"all vectors agree"*) echo "ok" ;;
    *) echo "FAIL: a primitive disagrees with its published vector"; exit 1 ;;
esac
