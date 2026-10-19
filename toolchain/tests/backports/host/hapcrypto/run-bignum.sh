#!/bin/sh
# run.sh — checks the bignum HAP's pairing arithmetic is written on, against an independent
# implementation: the cases are generated with Python's pow and the answers diffed.
#
# The two shapes are the point. `pow` is what a modular exponentiation makes, and what the check that
# came first covered: two full-width operands, 32 to 3072 bits. `mul` is what SRP-6a makes and what that
# check never reached: a narrow k, x or u against a full-width v, a narrow value reduced on its own,
# and a 2000-bit value against a narrow one. The defect in `mont_finish` that the second shape found
# is in the tree's history; the first shape passing without it is why both are here.
#
# The cases and the answers are both text, so a failure is a diff and not a judgement.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
revenant=${REVENANT:-$here/../../../..}
crypto="$revenant/packages/a/apple-backports/HomeKit/RevenantHAPBignum.m"
build=${BUILD:-$(runs_fresh revenant-hapcrypto)}
mkdir -p "$build"

cc -O2 -I"$revenant/packages/a/apple-backports/HomeKit" -o "$build/bignum" "$here/bignum.c" "$crypto"

cases=$build/cases.txt
answers=$build/answers.txt
expected=$build/expected.txt

python3 - "$cases" "$expected" <<'PYTHON'
import random, sys

cases, expected = sys.argv[1], sys.argv[2]
random.seed(20260927)

def is_prime(n, rounds=16):
    if n < 2:
        return False
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            return n == p
    d, r = n - 1, 0
    while d % 2 == 0:
        d //= 2
        r += 1
    for _ in range(rounds):
        a = random.randrange(2, n - 1)
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(r - 1):
            x = x * x % n
            if x == n - 1:
                break
        else:
            return False
    return True

def prime(bits):
    while True:
        candidate = random.getrandbits(bits) | (1 << (bits - 1)) | 1
        if is_prime(candidate):
            return candidate

# RFC 5054's own 1024-bit and 3072-bit groups, read from the RFC's text. The 1024-bit one is the group
# the RFC's own test vector is built at, and the values below are that vector's k and v.
# RFC 5054's groups, as the numbers themselves. The same two values are read out of a real
# HomeKit and out of OpenSSL's own table, in facts/HomeKit/RevenantHapCrypto.md; a literal here is
# what the check needs, and it is not a place to put a value read from somewhere that could move.
N1024 = int(
    "EEAF0AB9ADB38DD69C33F80AFA8FC5E86072618775FF3C0B9EA2314C9C256576D674DF7496EA81D3383B4813D692C6E0E0D5D8E250B98BE48E495C1D6089DAD1"
    "5DC7D7B46154D6B6CE8EF4AD69B15D4982559B297BCF1885C529F566660E57EC68EDBC3C05726CC02FD4CBF4976EAA9AFD5138FE8376435B9FC61D2FC0EB06E3"
    , 16)
N3072 = int(
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B"
    "E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF"
    , 16)

k = 0x7556AA045AEF2CDD07ABAF0F665C3E818913186F
v = int("7E273DE8696FFC4F4E337D05B4B375BEB0DDE1569E8FA00A9886D8129BADA1F1"
        "822223CA1A605B530E379BA4729FDC59F105B4787E5186F5C671085A1447B52A"
        "48CF1970B4FB6F8400BBF4CEBFBB168152E08AB5EA53D15C1AFF87B2B9DA6E04"
        "E058AD51CC72BFC9033B564E26480D78E955A5E29E7AB245DB2BE315E2099AFB", 16)
x = 0x94B7555AABE9127CC58CCF4993DB6CF84D16C124
a = 0x60975527035CF2AD1989806F0407210BC81EDC04E2762A56AFD529DDDA2D4393
narrow = 0xDEADBEEFCAFEF00D
wide = pow(2, 2000) + 12345

rows = [
    # the SRP shapes
    ("mul", k, v, N1024, (k * v) % N1024),
    ("mul", v, v, N1024, (v * v) % N1024),
    ("mul", k, k, N1024, (k * k) % N1024),
    ("mul", x, v, N1024, (x * v) % N1024),
    ("mul", a, v, N1024, (a * v) % N1024),
    ("mul", narrow, narrow, N3072, (narrow * narrow) % N3072),
    ("mul", wide, narrow, N3072, (wide * narrow) % N3072),
]
# the exponentiation shape, the one the first check covered and the fix must not have broken
for bits in (32, 61, 64, 96, 128, 160, 192, 224, 255, 256, 288, 384, 512, 768, 1024, 1536, 2048, 3072):
    modulus = prime(bits)
    base = random.randrange(2, modulus)
    exponent = random.randrange(2, modulus)
    rows.append(("pow", base, exponent, modulus, pow(base, exponent, modulus)))

with open(cases, "w") as f:
    for kind, left, right, modulus, _ in rows:
        f.write("%s\t%X\t%X\t%X\n" % (kind, left, right, modulus))
with open(expected, "w") as f:
    for kind, left, right, modulus, want in rows:
        f.write("%X\n" % want)
PYTHON

# The RFC's text is read from the work area when it is there and skipped when it is not, so that the
# products and the exponentiations over generated primes still run on a machine without it. The SRP
# cases are the ones that need it, and a run without them says so rather than passing quietly.
"$build/bignum" < "$cases" > "$answers"
if diff -u "$expected" "$answers" > "$build/diff.txt"; then
    count=$(wc -l < "$cases" | tr -d ' ')
    echo "ok   bignum: $count cases, 0 failures"
    exit 0
fi
echo "FAIL bignum: the answers differ from the independent implementation"
head -20 "$build/diff.txt"
exit 1
