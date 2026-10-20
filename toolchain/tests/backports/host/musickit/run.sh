#!/bin/sh
# The end-to-end check for a minted Apple Music developer token: mint one from a key generated here
# and ask OpenSSL to verify the signature over the first two parts joined by a dot, which is what a
# JOSE verifier does.
#
# It exists because the two checks this module has are not enough on their own: the C differential
# proves the signature, and a base64url unit test proves the encoding, and neither can see a token
# that is well formed in each half and wrong as a whole. This can - and did, three times.
#
# The module is built for the host with the toolchain's own macOS Swift, because the port's
# swift-runtime ships its standard library for iOS only. The C the module reaches is compiled for the
# host here for the same reason.
#
#   sh run.sh

set -e
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
# Four levels up is the repository root, as in every other suite under tests/backports/host: five is
# its parent, and the run as written looked for packages/frameworks/musickit there and found the worktrees
# directory - "clang: error: no such file or directory: '.../worktrees/packages/frameworks/musickit/files/RevenantC.c'".
root=$(cd "$here/../../../../" && pwd)
musickit=${REVENANT_ROOT:-$root}/packages/frameworks/musickit
revenant=${REVENANT_ROOT:-$root}
openssl=${OPENSSL:-openssl}
work=$(runs_fresh revenant-musickit-jose)
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

# uECC's headers, from the package the recipe installs: that is what RevenantCKWebAuth.h and uECC.h are
# included against, and the installed include/ is exactly the set the recipe chose to install.
uecc=$(ls -d "$HOME"/.xmake/packages/m/micro-ecc/*/* 2>/dev/null | head -1)
if [ -z "$uecc" ]; then
    echo "SKIP: revenant@micro-ecc is not installed; build it once and this runs"
    exit 0
fi
swiftc=${SWIFTC:-}
# Which swiftc: the one that can load a standard library for the host, found by trying rather than by
# asking xcrun which one is first. Two are on this machine and they report the same version, and the
# one xcrun names cannot be used:
#   $ /Library/Developer/CommandLineTools/usr/bin/swiftc -O -o probe probe.swift
#   error: unable to load standard library for target 'arm64-apple-macosx27.0.0'
# while /usr/bin/swiftc compiles the same file. The module is Swift, so a compiler that cannot load
# the standard library is not a compiler for this check.
if [ -z "$swiftc" ]; then
    printf 'let _ = 0\n' > "$work/probe.swift"
    for candidate in /usr/bin/swiftc "$(xcrun -sdk macosx --find swiftc 2>/dev/null)"; do
        [ -x "$candidate" ] || continue
        if "$candidate" -O -o "$work/probe" "$work/probe.swift" >/dev/null 2>&1; then
            swiftc=$candidate
            break
        fi
    done
    [ -n "$swiftc" ] || { echo "SKIP: no swiftc here can load a standard library for the host"; exit 0; }
    echo "swiftc: $swiftc"
fi

# uECC's *sources*, at the commit packages/libraries/micro-ecc/xmake.lua pins. They are not in the installed
# package - it ships include/ (headers) and lib/ (the archive), and the archive is armv7 because the
# recipe builds it for the device, so a host link cannot use it either. The three paths this run tried
# before - include/uECC.c and two guesses beside the package - all miss, and the error was "no such file
# or directory". A clone of the pinned commit is the same bytes the recipe builds its archive from, and
# it is the same thing the other two suites that need the curve do (microecc/run.sh, seckeycurve/run.sh).
commit=541b3a78026420a3e369c4c9281c396b5e531113
[ -f "$work/uECC/uECC.c" ] || git clone --quiet --filter=blob:none --no-checkout https://github.com/kmackay/micro-ecc.git "$work/uECC" 2>/dev/null &&
    git -C "$work/uECC" fetch --quiet --depth 1 origin "$commit" 2>/dev/null &&
    git -C "$work/uECC" checkout --quiet "$commit" 2>/dev/null
if [ ! -f "$work/uECC/uECC.c" ]; then
    echo "SKIP: micro-ecc at $commit could not be fetched, so uECC.c is not here to compile"
    exit 0
fi

"$openssl" ecparam -name prime256v1 -genkey -noout -out "$work/key.pem" 2>/dev/null
"$openssl" pkcs8 -topk8 -nocrypt -in "$work/key.pem" -out "$work/key8.pem" 2>/dev/null

xcrun -sdk macosx clang -O1 -w -I "$musickit/files/include" -I "$revenant/packages/libraries/micro-ecc/files" \
     -I "$uecc/include" -c "$musickit/files/RevenantC.c" -o "$work/shim.o"
xcrun -sdk macosx clang -O1 -w -I "$revenant/packages/libraries/micro-ecc/files" -I "$uecc/include" \
     -c "$revenant/packages/libraries/micro-ecc/files/RevenantCKWebAuth.c" -o "$work/web.o"
xcrun -sdk macosx clang -O1 -w -I "$work/uECC" -c "$work/uECC/uECC.c" -o "$work/u.o"

"$swiftc" -O -module-name M -import-objc-header "$musickit/files/include/MusicKitC.h" \
     -I "$musickit/files/include" -Xcc -I"$uecc/include" -Xcc -I"$revenant/packages/libraries/micro-ecc/files" \
     -o "$work/mint" "$here/main.swift" "$musickit/files/MusicKit/Authorization.swift" \
     "$work/shim.o" "$work/u.o" "$work/web.o"

# The four arguments: the key, the two identifiers the token is minted for, and the directory the
# three parts are written into - this run's scratch directory, which is what the checker below reads.
"$work/mint" "$work/key8.pem" ABCDE12345 TEAMID9999 "$work"

runs_xmake l "$here/verify.lua" "$work"
