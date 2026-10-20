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
echo "FAIL host/musickit/run.sh: its Python steps are gone and not yet ported to Lua: the inline block PY at line 93" >&2
exit 1
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

python3 - "$work" <<'PY'
import base64, subprocess, sys, os
work = sys.argv[1]
parts = [open(os.path.join(work, 'part%d.txt' % i)).read().strip() for i in range(3)]
if len(parts) != 3 or parts[0] == 'nil':
    print("FAIL: mint returned no token")
    raise SystemExit(1)
def b64u(text):
    return base64.urlsafe_b64decode(text + '=' * (-len(text) % 4))
header, payload, signature = b64u(parts[0]), b64u(parts[1]), b64u(parts[2])
print("header  :", header.decode())
print("payload :", payload.decode())
print("signature bytes:", len(signature), "(JOSE ES256 is the raw r || s, 64)")
if len(signature) != 64:
    print("FAIL: the signature part is not the raw pair")
    raise SystemExit(1)
n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC63FF51
if int.from_bytes(signature[32:], 'big') > n // 2:
    print("FAIL: the signature is not low-s")
    raise SystemExit(1)
def der_int(value):
    body = value.lstrip(b'\x00') or b'\x00'
    if body[0] & 0x80:
        body = b'\x00' + body
    return bytes([0x02, len(body)]) + body
inner = der_int(signature[:32]) + der_int(signature[32:])
open(os.path.join(work, 'sig.der'), 'wb').write(bytes([0x30, len(inner)]) + inner)
open(os.path.join(work, 'signing.txt'), 'w').write(parts[0] + '.' + parts[1])
subprocess.run(['openssl', 'ec', '-in', os.path.join(work, 'key.pem'), '-pubout',
                '-out', os.path.join(work, 'pub.pem')], capture_output=True)
verified = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', os.path.join(work, 'pub.pem'),
                           '-signature', os.path.join(work, 'sig.der'),
                           os.path.join(work, 'signing.txt')], capture_output=True, text=True)
print("OpenSSL  :", verified.stdout.strip() or verified.stderr.strip().splitlines()[-1])
raise SystemExit(0 if 'Verified OK' in verified.stdout else 1)
PY
