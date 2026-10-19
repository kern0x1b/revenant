# The EC half of the four SecKey functions of iOS 10, for the keys this package makes itself

The four public names - `SecKeyCreateSignature`, `SecKeyVerifySignature`,
`SecKeyCopyKeyExchangeResult` and `SecKeyIsAlgorithmSupported` - are in
`Security/SecurityFunctions10_0_1.m`, once, for two kinds of key at once, and this file is the half
that answers for a key of **this package's kind**: one that carries its own private scalar, beside
the `kSecValueData` `SecKeyCreateWithData` would have left, and that the release's keychain
therefore does not hold. A key of the release's own keychain is signed, verified and asked about
by the release's own `SecKeyRawSign` and `SecKeyRawVerify` in that file, beside the RSA row and
the table; the matrix of which is which is in `facts/Security/SecKey.md`, and the four registry rows
are in `registry/Security/ios10keys.json`.

**This file defines no public `SecKey*` symbol.** `Security/SecKeyElliptic10.m` exports five
`Charon`-prefixed names - `CharonSecurityKeyIsPortEC`, `CharonSecKeyECCarries`,
`CharonSecKeyECSign`, `CharonSecKeyECVerify`, `CharonSecKeyECExchange` - and one shared error
builder, `CharonSecKeyFail`, which `internal_symbol()` keeps out of the library's API. The
dependency runs one way, public to internal, so no band can leave this file out and find a call
undefined: it exports nothing a release can already have, and the public file was in every band
already. The other arrangement is the one that was refused - the four public names were defined in
both files, and the 6.1.3 gate answered
`duplicate symbol '_SecKeyCreateSignature' in: Security/SecKeyElliptic10.o and
Security/SecurityFunctions10_0_1.o`, with three more behind it.

`SecKeyCreateSignature`, `SecKeyVerifySignature`, `SecKeyCopyKeyExchangeResult` and
`SecKeyIsAlgorithmSupported` arrived with `SecKey` in iOS 10. `Security/SecKey100.m` already carries
the rest of that surface — random keys, the public half, encrypt and decrypt, the external
representation — over the release's own keychain, and recorded the four of these as `absent` because
iOS 6.1.3 has no curve to sign with. This is the other half of that decision.

## Why the arithmetic is a package and not a file in this one

iOS 6.1.3's CommonCrypto has no elliptic curve at all: the armv7 shared cache of that release exports
no `kCCAlgorithm*` symbol, no `CCEccKey` and no `kCCKeySizeEC256` (measured, `coordination/corpus` and
the cache itself), and `SecKeyCreateSignature` is iOS 8. So the curve arithmetic is taken rather than
written: `charon@micro-ecc` is Kenneth MacKay's micro-ecc, BSD-2, pinned at
`541b3a78026420a3e369c4c9281c396b5e531113`, built for the port's architecture as a static archive with
every symbol hidden. The JOSE around it — SHA-256, the minimal DER a JOSE verifier reads, the low-s
half, the `0x04` tag Apple's own Security writes — is `CharonCKWebAuth.c` in that package, and the
ECDH is now beside it.

Three entry points were added to that wrapper for this file, and they are the whole of the difference
between signing a message and signing a digest:

- `CharonCKDigestSignES256` and `CharonCKDigestVerifyES256` sign and verify a **digest the caller
  already took**. The wrapper's existing pair hashes the message first, and Security's
  `…ECDSASignatureDigestX962SHA256` says *Digest*: the 32 bytes the caller hashed are the message, and
  hashing them again would sign a different message than the one asked for. The message-level pair is
  now these two with a SHA-256 in front, so the DER reading and the low-s step exist once.
- `CharonCKSharedSecretES256` is the ECDH: `uECC_shared_secret` between a 32 byte private key and a
  65 byte uncompressed public point, which micro-ecc has and the wrapper had no use for.

The package's recipe also builds that wrapper now (`packages/m/micro-ecc/xmake.lua`). It did not:
`on_install` compiled `uECC.c` alone and installed only micro-ecc's own three headers, so
`CharonCKWebAuth.h` was in the package's source and not in its `include/`, and nothing that included it
could compile. That was a gap in the package, not in its users, and it is fixed at the source.

## The signing is the release's own

A key of an application on this release lives in iOS 6's keychain: `SecKeyCreateRandomKey`
(`Security/SecKey100.m`) makes it with the **release's own** `SecKeyGeneratePair`. And the release can
sign with it: `SecKeyRawSign` and `SecKeyRawVerify` are iOS 2.0, both are in the armv7 shared cache of
iOS 6.1.3, and they take an elliptic key and a digest. So for a key of the release's keychain this
file does no arithmetic at all: it calls `SecKeyRawSign` and reads the two halves of the signature
where the release put them.

Which is where the release put them is the release's business, not an assumption, and both shapes are
read: a 64 byte answer is the two 32 byte halves of a P-256 signature, and an answer that begins with
`0x30` is the SEQUENCE of two INTEGERs already. A result that is neither is refused with
`errSecInternalError` rather than guessed at. `r` and `s` are put in the **low-s half**, which is the
form Apple's own `SecKeyCreateSignature` produces and which a CloudKit web services token is checked
against; `(r, s)` and `(r, n - s)` are both valid signatures of the same message, so the low-s one is
the one that is Apple's. An elliptic key has no padding, so the call is made with `kSecPaddingNone`;
if the release refuses that, it is asked once more with the `kSecPaddingPKCS1` it also names, and
whichever it accepts is the one its answer comes from.

**Which padding an EC key of this release takes, and whether it hands back the halves or the DER, is
measured by a probe on the release itself**, `tests/backports/device/seckey-ecraw.m`, run in the
emulator at 6.1.3 (`tests/backports/host/seckeycurve/emulate.sh`, one heavy job). It is queued; the
code above handles either answer, so nothing waits on it to be correct, only to be known.

## The keys this package makes are the only ones the curve is for

`charon@micro-ecc` is reached for a key **this package created and holds the scalar of** — the
`SecKeyCreateWithData` and the elliptic arm of `SecKeyCreateRandomKey` that are the next piece of work,
and which mark their keys with a `CharonSecKeyScalar` attribute the two functions here look for. For
every key of the release's keychain the curve is not used: the release signs and verifies, and the
exchange below is not available at all.

## The exchange, and why a release key cannot do it

**Measured, not assumed**: the armv7 shared cache of iOS 6.1.3 exports `SecKeyRawSign` and
`SecKeyRawVerify` and **no elliptic key agreement of any kind**. Its one key agreement is the
finite-field `SecDH` family — `SecDHComputeKey`, `SecDHGenerateKeypair`, `SecDHCreate` — which is not a
curve, and there is no `SecKeyCopyExchangeKey`, `SecKeyExchangeKey`, `SecKeyECDH` or
`SecKeyCreateFromData` anywhere in it. The same probe asks the release for each of those names by
`dlsym` and prints what it finds.

So `SecKeyIsAlgorithmSupported` answers **NO** for a key exchange on a key of the release's keychain,
and `SecKeyCopyKeyExchangeResult` refuses such a key with `errSecParam` and that reason, rather than
making a shared secret over a scalar it would have to guess at. For a key of this package it answers
YES and derives the secret over the curve, as `facts/Security/SecKeyElliptic.md` describes: the X
coordinate of the shared point for an algorithm whose name ends in no digest, and its SHA-256 for one
that does.

## What the port answers

- `SecKeyCreateSignature` returns a **DER** ECDSA signature (the SEQUENCE of two INTEGERs, each as
  short as its value needs) of the 32 byte digest given, in the **low-s half**, which is the form
  Apple's own `SecKeyCreateSignature` produces and the one a CloudKit web services token is checked
  against. A nil key or data, an algorithm other than `…ECDSASignatureDigestX962SHA256`, a digest that
  is not 32 bytes, and a key whose scalar cannot be found, each answer NULL with a `CFError` in
  `NSOSStatusErrorDomain` naming which; a failure of the curve itself is `errSecInternalError`.
- `SecKeyVerifySignature` answers true when that DER is a signature of that digest under the point the
  key publishes, false otherwise, and **a signature that is not a signature is a false and not an
  error** — which is what the host does, and what a caller of a verify loop relies on. The same four
  refusals as above, with `errSecParam`.
- `SecKeyCopyKeyExchangeResult` returns the **X coordinate of the shared point**, 32 bytes, for an
  algorithm of the ECDH family whose name ends in no digest, and the **SHA-256** of it for one that
  does — which is what Security's two families (`…StandardX963*`, `…CofactorX963*`) say they hand
  back, and what a caller needs to make a key with. There is no `kSecKeyAlgorithmECDH` constant in any
  SDK this port builds against, only that family, and the header of the function tells the caller to
  pass "kSecKeyAlgorithmECDH", which is the family's own prefix; so the *name* is matched.
- `SecKeyIsAlgorithmSupported` answers true for sign and verify with
  `kSecKeyAlgorithmECDSASignatureDigestX962SHA256` and for key exchange with any algorithm of that
  ECDH family, false for encrypt and decrypt (P-256 has no encryption in Security's own vocabulary
  either), false for every other algorithm — the RSA ones are `SecKey100.m`'s business and it answers
  for those — and false for a key the release publishes no point for. A nil key or algorithm is false.

## What was measured, and what was not

**Measured**, against the host's own Security.framework in both directions
(`tests/backports/host/seckeycurve`, **93 checks, none differing**): a signature the port makes verifies
under the host's `SecKeyVerifySignature`, and one the host makes verifies through the port, for
messages of 0, 65 and 130 bytes; the host refuses the port's signature under SHA-384, so the
algorithm is not being ignored; the port refuses the host's signature for another message; every
signature is the low-s half on **both** sides over 24 samples, which is the form only Apple's own
producer takes; and the shape of what a P-256 key exports is read from the host — the 65 byte
uncompressed public point, the 97 byte private blob, and the two candidate windows in it that only one
of which derives the key's own published point.

**The port's own curve is measured too, and how it got there is part of this file.** The three
`CharonCK*` calls of `SecKeyElliptic10.m` are behind the marker `kCharonSecKeyScalar`, which only
`SecKeyCreateWithData` would put on a key, and until this was measured **nothing in the repository
executed them at all**: the one call the differential made passed a key of the host's, so every run
took the release's `SecKeyRawSign` path, and a mutant that returned half the DER from the curve's own
signing left the run byte-identical (`checks=55 failures=0`, the same log hash as the pristine run).
The suite now builds the key the port would have built — the point and the scalar OpenSSL printed for
one of the two keys `run.sh` makes, through the host's `SecKeyCreateWithData`, whose own note is that
it "does not add keys to any keychain" — and registers it as the port's kind, so the curve runs and is
held to two oracles: micro-ecc's signature verifies under the host's `SecKeyVerifySignature`, a
signature the host makes verifies through the port's own reader, and the port's exchange is OpenSSL's
own secret for the same two keys, byte for byte, with the digest-named form checked against SHA-256 of
OpenSSL's bytes. The same mutant now gives `checks=78 failures=3`.

**What is still not measured: the release's own answers, and any device run.** Every measurement above
is the port on a host. Which padding an EC key of the **release** accepts, and whether it hands back
the halves or a DER, is what the queued emulator probe settles, and it has not run; and no key of the
release's keychain carries the marker, so the curve's own path is unreachable on a device until
`SecKeyCreateWithData` is written. The rows of `registry/Security/ios10elliptic.json` now say which of
the two paths each `effect` describes, and the second one says it is measured on the host only.

The **ECDH is held to OpenSSL**, not to the host, and the reason is measured: the host's own
`SecKeyCopyKeyExchangeResult` reads through a key that is only in memory and dies with a SIGSEGV inside
Security.framework. So `run.sh` makes two P-256 pairs with OpenSSL, derives the secret OpenSSL makes
from them, and the differential compares that with what the port derives from the same two keys, byte
for byte — after checking that the scalar and the point OpenSSL printed are one key (the scalar derives
the point OpenSSL published for it) and not the other. The exchange is then made in both directions and
a third pair of keys is shown to give a third secret.

**Not measured yet: the release's own answers.** The probe that settles them is
`tests/backports/host/seckeycurve/emulate.sh`, which builds `tests/backports/device/seckey-ecraw.m` for
6.1.3 and runs it in the emulator, and it has not run: this session did not run it and no log of it
exists in this tree, which is the honest state of it. Until it does, which padding an EC key of the
release takes and whether it answers the halves or the DER is written down as "both are read" rather
than as a fact, and no path above may be read as a claim about the device. The gate that would build
this file has not run either.

**What was here before, and why it is gone.** The first version of this file found the private scalar
by scanning every 32 byte window of the release's keychain blob and keeping the one whose derived
public point matched the key's own. That was a crutch — a guess about a shape nobody had read, dressed
as a check — and it is replaced by the release's own `SecKeyRawSign`, which needs no shape at all. The
scan is not in the tree, and `Security/SecKeyElliptic.md` no longer depends on a keychain blob being
anything in particular.

**One thing this cost to find**, and it is the kind the differential exists for: the wrapper's
`CharonCKSignES256` hashed the message and passed `sizeof digest` to `uECC_sign`. When the digest-level
entry point was factored out, `digest` became a pointer parameter and `sizeof` became eight — so
micro-ecc was asked to sign an eight byte hash. The port's own verification accepted those signatures
(the same wrong length went in and came out), and only the host's `SecKeyVerifySignature` refused
them. The length is now `CC_SHA256_DIGEST_LENGTH` by name. What it costs is that `LAPublicKey`, `LAPrivateKey` and the rights API
of LocalAuthentication, which are built on these four, should not be carried before one device run has
confirmed the extraction — that is the next round, and it is named in the delivery rather than guessed at.
