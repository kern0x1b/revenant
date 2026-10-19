#!/bin/sh
# run.sh - the port's P-256 signature and ECDH (charon@micro-ecc's arithmetic and this repository's
# JOSE around it) against the host's own Security.framework, in both directions: a signature the port
# makes must verify under the host's key, a signature the host makes must verify under the port's, and
# both sides must reach the same shared secret.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
package=${PACKAGE:-$here/../../../../packages/m/micro-ecc}
build=${SECKEYCURVE_BUILD:-$(runs_fresh charon-seckeycurve)}
rm -rf "$build"
mkdir -p "$build"
clone="$build/micro-ecc"
git clone --quiet --depth 1 https://github.com/kmackay/micro-ecc.git "$clone" > /dev/null 2>&1
[ -f "$clone/uECC.h" ] || { echo "FAIL micro-ecc did not clone: no uECC.h in $clone"; exit 1; }
xcrun clang -std=c11 -Os -w -fno-strict-aliasing -I"$clone" -I"$package/files" \
    -c "$clone/uECC.c" -o "$build/uECC.o"
xcrun clang -std=c11 -Os -w -fno-strict-aliasing -I"$clone" -I"$package/files" \
    -c "$package/files/CharonCKWebAuth.c" -o "$build/wrapper.o"
# OpenSSL is the oracle for the exchange: the host's own SecKeyCopyKeyExchangeResult reads through
# an in-memory key and dies (measured, a SIGSEGV inside Security.framework), so the two P-256 pairs
# and the secret OpenSSL derives from them are made here and the differential compares that file
# with what the port derives from the same keys.
openssl ecparam -genkey -name prime256v1 -noout -out "$build/one.pem" 2>/dev/null
openssl ecparam -genkey -name prime256v1 -noout -out "$build/two.pem" 2>/dev/null
openssl ec -in "$build/one.pem" -pubout -out "$build/one.pub.pem" 2>/dev/null
openssl ec -in "$build/two.pem" -pubout -out "$build/two.pub.pem" 2>/dev/null
openssl pkeyutl -derive -inkey "$build/one.pem" -peerkey "$build/two.pub.pem" -out "$build/openssl.secret" 2>/dev/null
# OpenSSL prints the private scalar in the fewest nibbles it needs, and with a sign pad on the top byte,
# so its printed length is not a constant: 66 digits when the top byte is 0x80 or above, 64 when it is
# 0x40..0x7f, 62 when it is below 0x40, and so on. The check further down used to accept 64 and 66 and
# nothing else, and failed the run on a key OpenSSL had printed correctly - measured on a key whose top
# byte was 0x0f, which printed 62 digits. So the number is normalised here, once: the leading zeros that
# are not part of the number go, an odd count gains one, and what is left is left-padded to the 64 digits
# of a 32 byte scalar. Anything longer than 66 is a real failure and not a formatting one.
pad_scalar() {
    hex=$(cat)
    case "$hex" in
        ""|*[!0-9a-fA-F]*) echo "pad_scalar: not hex: \"$hex\"" >&2; return 1 ;;
    esac
    if [ "${#hex}" -gt 66 ]; then
        echo "pad_scalar: more than 33 bytes of scalar: \"$hex\"" >&2
        return 1
    fi
    while [ "${#hex}" -gt 0 ]; do
        case "$hex" in
            0*) hex=${hex#0} ;;
            *) break ;;
        esac
    done
    if [ $(( ${#hex} % 2 )) -ne 0 ]; then
        hex="0$hex"
    fi
    while [ "${#hex}" -lt 64 ]; do
        hex="0$hex"
    done
    printf '%s' "$hex"
}

openssl ec -in "$build/one.pem" -text -noout 2>/dev/null | sed -n '/priv:/,/pub:/p' | sed -e 's/priv://' -e 's/pub://' -e 's/^[[:space:]]*//' -e '/^$/d' | tr -d ' \n:' | pad_scalar | fold -w2 > "$build/one.scalar"
openssl ec -in "$build/one.pem" -pubout -outform DER 2>/dev/null | tail -c 65 > "$build/one.point"
openssl ec -in "$build/two.pem" -text -noout 2>/dev/null | sed -n '/priv:/,/pub:/p' | sed -e 's/priv://' -e 's/pub://' -e 's/^[[:space:]]*//' -e '/^$/d' | tr -d ' \n:' | pad_scalar | fold -w2 > "$build/two.scalar"
openssl ec -in "$build/two.pem" -pubout -outform DER 2>/dev/null | tail -c 65 > "$build/two.point"
[ -s "$build/openssl.secret" ] || { echo "FAIL openssl made no shared secret: nothing to compare the port's against"; exit 1; }
for one in one two; do
    bytes=$(tr -d '\n' < "$build/$one.scalar" | wc -c | tr -d ' ')
    if [ "$bytes" != 64 ]; then   # 32 bytes, which is what pad_scalar above leaves
        echo "FAIL openssl gave no 32 byte scalar for key $one ($bytes hex digits)"
        exit 1
    fi
done
# The port's own four public functions, renamed, so the differential holds the port's code and not only
# the wrapper it calls. TWO files hold them between them: SecurityFunctions10_0_1.m owns the four public
# names and Security/SecKeyElliptic10.m holds the curve for the keys this package makes itself. They are
# compiled together and linked together, which is what the library's own link does - and the reason they
# are compiled with the same four -D renames is that the four names are defined once between them, and a
# second definition is what the 6.1.3 gate refused:
#
#   duplicate symbol '_SecKeyCreateSignature' in: Security/SecKeyElliptic10.o and Security/SecurityFunctions10_0_1.o
#
# The private entry points of the release's keychain (SecKeyCopyPublicBytes, SecKeyCopyAttributeDictionary
# and the rest) do not exist on the host, and neither does the keychain half of the release-key path:
# an in-memory key is in no keychain, so the release's own SecItemCopyMatching answers errSecItemNotFound
# for every one of them (measured, attrs.m in the evidence of this suite's design). port-shims.h answers
# both shapes from the host's own Security, and the differential says which key is of which kind.
port=${PORT:-$here/../../../../packages/a/apple-backports/Security}
renames="-DCharonCKPublicPoint=charonHostCharonCKPublicPoint
    -DSecKeyCreateSignature=charonHost_SecKeyCreateSignature
    -DSecKeyVerifySignature=charonHost_SecKeyVerifySignature
    -DSecKeyCopyKeyExchangeResult=charonHost_SecKeyCopyKeyExchangeResult
    -DSecKeyIsAlgorithmSupported=charonHost_SecKeyIsAlgorithmSupported
    -DSecItemCopyMatching=charonHost_SecItemCopyMatching
    -DSecKeyCopyAttributeDictionary=charonHost_SecKeyCopyAttributeDictionary"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -include "$here/port-shims.h" $renames \
    -c "$port/SecurityFunctions10_0_1.m" -o "$build/functions.o"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -include "$here/port-shims.h" $renames \
    -c "$port/SecKeyElliptic10.m" -o "$build/port.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$here/../../device" -I"$package/files" \
    "$here/differential.m" "$here/../../device/check.m" "$build/uECC.o" "$build/wrapper.o" \
    "$build/functions.o" "$build/port.o" "$here/port-shims-impl.m" \
    -framework Foundation -framework Security -o "$build/differential"
"$build/differential" "$build"

# The matrix: one mutation per cell of the sixteen, each held to a red check that names its cell. The driver
# runs this script once per mutant with SECKEYCURVE_MUTANT set, and that guard keeps a mutant's run from running
# the matrix again.
if [ -z "${SECKEYCURVE_MUTANT:-}" ]; then
    scratch=$(runs_fresh charon-seckeycurve-cells)
    xmake l "$here/mutate-cells.lua" "$port" "$here" "$scratch"
fi
