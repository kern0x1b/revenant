# HAP's crypto, and the one part of it that is not here

HomeKit Accessory Protocol pairs in two steps, and both need key agreement this release has no API
for: `pair-setup` runs SRP-6a against the accessory's setup code, and `pair-verify` runs X25519 and
Ed25519 between the controller's and the accessory's long-term keys. What is here is everything under
both of them, checked against published vectors; what is not here is SRP-6a itself, and the reason is
the group's value.

## What is here, and what it is checked against

`CharonHapCrypto.m` is a thin layer: every primitive it exposes is either iOS 6's own CommonCrypto or
Monocypher's, and the layer exists so that the transport's code reads as HAP's derivation and not as a
call into a hash library. The checks are the published vectors of each primitive, run as a host test
(`tests/backports/host/hapcrypto`), and all nine agree:

| what | vector | verdict |
| --- | --- | --- |
| X25519 | RFC 7748 §5.2 vector 1 | agrees |
| Ed25519 sign | RFC 8032 §7.1 TEST 2 | agrees |
| ChaCha20-Poly1305 ciphertext | RFC 8439 §2.8.2 | agrees |
| ChaCha20-Poly1305 tag | RFC 8439 §2.8.2 | agrees |
| ChaCha20-Poly1305 open | its own ciphertext | opens |
| HKDF-SHA256 | RFC 5869 test case 1 | agrees |
| HKDF-SHA256, no salt | RFC 5869 test case 3 | agrees |
| SHA-256("abc") | FIPS 180-4 | agrees |
| SHA-512("abc") | FIPS 180-4 | agrees |

The AEAD is `crypto_aead_init_ietf`, not Monocypher's own `crypto_aead_init_x`. That distinction is
the whole reason this library is the one: HAP's session keys are **ChaCha20-Poly1305 with a 12-byte
nonce**, the IETF construction, and the XChaCha20-Poly1305 that Monocypher's own initialiser builds
would produce a ciphertext no accessory could read. Monocypher 4.0 seals through a context rather than
through a one-shot call, so `charon_hap_seal` initialises a context, writes once, and lets it go.

`crypto_aead_write` and `crypto_aead_read` also mean the context carries the counter, so a session
that needs several frames increments the nonce itself — which is what HAP's framing does, and what
`CharonHAPSession.m` does when it lands.

## The library, and why this one

Monocypher 4.0.2, vendored at `packages/m/monocypher`, is **BSD-2-Clause OR CC0-1.0** — the licence
states both, with CC0 as the one the author intends for the public domain and BSD as the fallback.
The recipe pins the tarball's sha256 (`38d0717…0879c`) and the vendored sources are the 4.0.2 release
it names; `LICENCE.md` is installed beside the library.

The alternatives were TweetNaCl, which is public domain and has the same AEAD, and `csrp` for SRP.
TweetNaCl's 2014-04-27 tarball is no longer served from any address this machine can reach (four URLs
tried, all 404), and the two that did answer were a 403 and a different project's 404. **`csrp` is not
used at all**, and that is the better answer rather than the fallback: SRP-6a is a hundred lines of
exponentiation and hashing over a modular exponentiation this package already has in
`CharonHAPBignum.m`, and that exponentiation is checked against an independent implementation on 72
primes from 32 to 3072 bits. A vendored SRP would be a second, unverified answer to a question the
package can already answer correctly.

## SRP-6a: the group is found, and the implementation is not finished

**The group is read and cross-checked, and it is no longer a question.** RFC 5054 Appendix A's 3072-bit
group with the generator 5, taken from two independent sources on this machine and compared:

| source | what it is | result |
| --- | --- | --- |
| RFC 5054's own text | Appendix A prints the 3072-bit prime as 48 lines of hex and names the generator | g = 5, 384 bytes |
| OpenSSL 3.x | `SRP_get_default_gN("3072")` out of `/opt/homebrew/opt/openssl@3` -- the function OpenSSL's SRP asks for a group by name | g = 5, same 384 bytes |

**They agree hex for hex.** The same call returns the 1024- and 2048-bit groups and those agree with
the RFC too, which is the check that says the two sources are one table rather than two that share a
single entry. The prime is also what the RFC's own formula
`2^3072 - 2^3008 - 1 + 2^64 * { [2^2942 pi] + 1690314 }` produces. The generator being 5 for the
3072-bit group and 2 for the other two is the reason the agreement on the other two matters: it is a
check, not the answer.

The group is in `CharonHapSrp.inc` in the work area, generated from the RFC's text and compiled for
armv7/iOS 6.1.3.

**The implementation is written and is not finished, and the reason is a defect in the bignum, not in
the protocol.** `CharonHapSrp.m` in the work area is a complete SRP-6a over that group, and RFC 5054
Appendix B's own 1024-bit test vector pins x, v, k, A, B, u and the premaster secret individually. Four
of the seven agree:

    ok  x   ok  v   ok  k   ok  A
    FAIL B   FAIL u   FAIL S

`B = k*v + g^b mod N` is the first disagreement, and it is narrowed down to one operation: **a 160-bit
value times a 1024-bit value, through the Montgomery product, does not match an independent
implementation.** Measured, with the operands held and the arithmetic otherwise right:

| what | this package | an independent implementation |
| --- | --- | --- |
| `k * k` (narrow by narrow) | agrees | agrees |
| `k * v` (narrow by full width) | `758DD475 2C44DCC8…` | `EB79375A F210A486…` |
| `k` read at the field's width instead of its own | `BC1B60E2 FEE48393…` | `BCCBE9C1 16BD0BAD…` |

So the defect is in `CharonHAPBignum.m`'s Montgomery product for operands of different widths, and the
72-case differential that file was checked against did not reach it: every case in it used two
full-width operands, which is the shape a modexp is made of and not the shape SRP makes.

**What fixing it needs.** The Montgomery product assumes both operands occupy the modulus's own limb
count; a narrow operand leaves its high limbs zero, and the reduce loop's index arithmetic is where that
assumption shows. The two ways to fix it are to widen a narrow operand to the modulus's width before
multiplying (one line at each of the four call sites, and the reason the recorded lengths exist at all),
or to make `mont_product` and `mont_reduce` iterate over the full width for every operand rather than
over `mont->limbs`. The second is the better fix and the first is the one that unblocks the transport
today, since a narrow `k`, `x` or `u` is the whole reason this came up.

**What is in the tree and what is not.** In: the group, SHA-1 (which RFC 5054's vector needs and HAP
does not), and the bignum's big-endian conversion -- `charon_bn_from_bytes_be` / `charon_bn_to_bytes_be`
-- which was a real bug of its own, since the limb order is little-endian and every protocol value is
big-endian, and reading one the wrong way round gives a different number that still computes. Out:
`CharonHapSrp.m`, which is parked in `.agent-work/plan-and-analysis/hap-srp/` with its vector, the
OpenSSL probe and the narrowing probe, because code that fails its own test is not a delivery.

**One thing the vector settled, which is worth keeping.** RFC 5054's own Appendix B vector uses
`x = H(s | H(I | ":" | P))` -- the salt mixed in **once**. SRP-6a, and so HAP, mixes it **twice**:
`x = H(s | H(s | H(I | ":" | P)))`. Measured, not assumed: the RFC's printed x is what one application
produces and what two does not. The implementation therefore takes the count as a parameter, and the
vector runs both forms against the same code.

## `pair-verify` is not blocked

`pair-verify` needs no group: it is X25519 over a per-session ephemeral against the accessory's stored
public key, Ed25519 over the four values, and HKDF-SHA-512 for the session keys. All of that is here
and checked. What is not written is the framing — the HTTP request, the JSON body and the session's
counter — which is ordinary code and is not blocked by anything in this file.

## A note on the seed

Monocypher's `crypto_ed25519_key_pair` **destroys the seed** it is given: it wipes the 32 bytes once
it has hashed them. `charon_hap_ed25519_keypair_from_seed` therefore copies the caller's seed and
hands the library the copy. A caller who passed a string literal straight through would have had the
library write zeroes into read-only memory; the host test found that, and it is why the wrapper is
shaped the way it is rather than as a one-line pass-through.
