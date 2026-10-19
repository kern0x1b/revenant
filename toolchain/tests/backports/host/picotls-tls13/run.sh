#!/bin/sh
# One TLS 1.3 handshake between two picotls connections, to prove the TLS stack the port builds for
# a QUIC handshake is usable.
#
# The C is the same on both sides of the port: picotls's own sources, compiled here for the host
# because a pump that has never run is a guess, and for the device by the same recipe the package
# builds it with. Where the sources come from is the installed package when there is one and a
# checkout of the pinned commit when there is not, so this runs before the package is ever built.
#
# The certificate and the key are made here, by the host's own openssl, into the build directory: the
# port's tree holds neither, and both are thrown away with the directory.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
BACKPORTS=${BACKPORTS:-$here/../../../../packages}
PICOTLS_URL=https://github.com/h2o/picotls.git
PICOTLS_COMMIT=d6c3da61b47cc3ccecaf9aa093c24e4aafebd52a
build=${PICOTLS_BUILD:-$(runs_folder revenant-picotls-tls13)}

# the sources: the installed package's, or a checkout at the commit the recipe pins
# PICOTLS_SOURCES names a checkout of the pinned commit, and the installed package is used otherwise.
source_root=${PICOTLS_SOURCES:-$(ls -d "$HOME"/.xmake/packages/p/picotls/*/ 2>/dev/null | head -1 || true)}
if [ -n "$source_root" ] && [ -d "${source_root}include/picotls.h" ]; then
    sources="$source_root"
    echo "picotls: the installed package"
else
    sources="$build/picotls"
    rm -rf "$build"
    mkdir -p "$build"
    # The PINNED COMMIT is fetched, not a branch tip and hoped for. `git clone --depth 1` brings HEAD
    # and nothing else, so `checkout <sha>` for any older commit has nothing to check out and says
    # "fatal: unable to read tree (<sha>)" - which is what this test did on a machine with no picotls
    # package installed, every time. `git fetch origin <sha>` asks for that one object by name, which is
    # what a pin needs, and the checkout is of FETCH_HEAD so nothing depends on which branch it came from.
    mkdir -p "$sources"
    git -C "$sources" init --quiet
    git -C "$sources" remote add origin "$PICOTLS_URL"
    if ! git -C "$sources" fetch --quiet --depth 1 origin "$PICOTLS_COMMIT" 2>"$build/fetch.log"; then
        echo "FAIL: picotls $PICOTLS_COMMIT could not be fetched from $PICOTLS_URL - the sources this"
        echo "      checks the port's TLS stack against are not on this machine. Build the package once"
        echo "      (xmake require --extra package=p/picotls), or set PICOTLS_SOURCES to a checkout of"
        echo "      that commit."
        sed 's/^/      /' "$build/fetch.log"
        exit 1
    fi
    git -C "$sources" checkout --quiet FETCH_HEAD
    echo "picotls: $PICOTLS_COMMIT fetched and checked out"
fi

mkdir -p "$build/obj"
# picotls-core, then picotls-minicrypto: the two archives the project itself builds, and the crypto is
# its own (minicrypto) rather than OpenSSL, which the port has no armv7 build of.
for source in lib/hpke.c lib/picotls.c lib/pembase64.c \
              deps/micro-ecc/uECC.c deps/cifra/src/aes.c deps/cifra/src/blockwise.c deps/cifra/src/chacha20.c \
              deps/cifra/src/chash.c deps/cifra/src/curve25519.c deps/cifra/src/drbg.c deps/cifra/src/hmac.c \
              deps/cifra/src/gcm.c deps/cifra/src/gf128.c deps/cifra/src/modes.c deps/cifra/src/poly1305.c \
              deps/cifra/src/sha256.c deps/cifra/src/sha512.c \
              lib/cifra.c lib/cifra/x25519.c lib/cifra/chacha20.c lib/cifra/aes128.c lib/cifra/aes256.c \
              lib/cifra/random.c lib/minicrypto-pem.c lib/uecc.c lib/asn1.c lib/ffx.c; do
    object="$build/obj/$(echo "$source" | tr / _).o"
    xcrun clang -std=c99 -Os -w -I "$sources/deps/cifra/src/ext" -I "$sources/deps/cifra/src" \
        -I "$sources/deps/micro-ecc" -I "$sources/deps/picotest" -I "$sources/include" \
        -c "$sources/$source" -o "$object"
done
xcrun clang -std=c99 -Os -w -I "$sources/include" -o "$build/probe" "$here/probe.c" "$build/obj"/*.o

# the certificate and the key, made here and left here
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 1 \
    -keyout "$build/key.pem" -out "$build/cert.pem" -subj "/CN=revenant probe" >/dev/null 2>&1
openssl pkcs8 -topk8 -nocrypt -in "$build/key.pem" -outform DER -out "$build/key.der" 2>/dev/null
# picotls's own signer takes the raw secp256r1 scalar, which is the last 32 bytes of the PKCS#8 form
python3 - "$build/key.der" "$build/key.raw" <<'PY'
import sys
open(sys.argv[2], "wb").write(open(sys.argv[1], "rb").read()[-32:])
PY

"$build/probe" "$build/cert.pem" "$build/key.raw" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" | head -20 || true
echo "log=$build/log"
exit $result
