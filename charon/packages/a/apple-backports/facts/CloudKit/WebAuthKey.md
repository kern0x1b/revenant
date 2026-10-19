# The web services authentication key, and the ES256 signature

## Why the key is needed

A CloudKit Web Services request carries a bearer token, and there are two documented ways to have
one. The application may mint a **developer token** itself and hand it to the port, which needs no
cryptography. Or the port signs one with the container's **web services authentication key**, an
ES256 key whose identifier is `iCloud.com.apple.developer.<container>`. The second is the one that
works for a client that has only a `.p8` in its bundle, so it is carried.

## Why the arithmetic is a package and not a file in this one

iOS 6.1.3 cannot make this signature: `SecKeyCreateRandomKey` and `SecKeyCreateSignature` are iOS 8,
and CommonCrypto signs nothing but a digest. So the curve arithmetic is taken rather than written:
`charon@micro-ecc` is Kenneth MacKay's micro-ecc, BSD-2, pinned at `541b3a78026420a3e369c4c9281c396b5e531113`,
built for the port's own architecture as a static archive with every symbol hidden, so no second copy
of a curve implementation is ever API of a process that links `libCloudKitBackports.dylib`.
`CharonCKWebAuth.c`, in that package, is the JOSE around micro-ecc and nothing else: SHA-256 of the
message, the DER a JOSE ES256 verifier reads, and the low-s half.

## What the differential proves

`tests/backports/host/cloudkit/run.sh` signs and verifies through OpenSSL in both directions over
messages of 0, 1, 55, 56, 63, 64, 65, 500, 4096 and 100000 bytes, with the public point compared
byte for byte against OpenSSL's:

    micro-ecc: 40 checks agreed in both directions, 0 failures

Forty checks is twenty pairs: for each of the ten sizes, OpenSSL accepting the port's signature and
the port accepting OpenSSL's, plus the public point. Nonces come from the kernel's `/dev/urandom`, so
the two sides never sign the same bytes twice; micro-ecc's deterministic RFC 6979 entry points are
not used, so no RFC 6979 vector applies and none is quoted.

## Two bugs the differential found, both in the wrapper

**A non-minimal DER is not a signature.** The first version wrote each INTEGER as a fixed 33 bytes with
a leading zero. micro-ecc signed correctly, micro-ecc verified its own signature, and OpenSSL rejected
both the signature and the encoding with "too long" and "bad object header": LibreSSL's parser
refuses a length the value did not need. An INTEGER is as many bytes as its value needs and one more
when the top bit of the value is set.

**micro-ecc's public key has no tag.** `uECC_compute_public_key` writes the two coordinates and
nothing else, so the 65 bytes of an uncompressed point are a `0x04` the caller adds, and
`uECC_verify` wants the 64 without it. A key derivation written against `uECC_make_key` would have
generated a new pair and overwritten the private key it was given.

## The low-s half

`(r, s)` and `(r, n - s)` are both valid for the same message, so replacing `s` by `n - s` when `s` is
over half the group order leaves a signature that still verifies - and is the one
`SecKeyCreateSignature` produces. A CloudKit Web Services token is checked against a signature Apple's
own Security made, so the port takes the same form. `n` is odd, so `n/2` is `(n-1)/2` and "over half"
is `s > (n-1)/2`, which is `memcmp` of the two 32-byte big-endian values against `n` shifted right.

## What is not here

The JWT itself - the header, the payload and the three members of the CloudKit Web Services
authentication key's own format - and the `POST` that exchanges it for a token are the transport's.
What is here is the signature, which is the part iOS 6 cannot do at all.

## What the review found here, and what is still open

`tests/backports/host/cloudkit/run.sh` now exists and its harness is in the tree, so the number is
re-runnable by a reader rather than produced by a binary in a work area. The script builds the port's
own `CharonCKWebAuth.c` against micro-ecc and calls it; it needs `charon@micro-ecc` installed, like
every other host test needs its package.

**The group order and its half are corrected.** The hard-coded order read `0x25` in byte 30 where
FIPS 186-4 D.1.2.3 reads `0xff`, and the half was shifted with the little-endian rule applied to a
big-endian number, so the threshold was 0.9999999702 of *n* rather than half of it. Both are right
now, and `CharonCKGroupOrder()` / `CharonCKGroupOrderHalf()` expose them so the test reads the same
values the signer uses rather than transcribing a third copy — a second transcription of the number
this file got wrong is exactly how the mistake survived.

**A new `low-s` mode is the check the OpenSSL round trip cannot make.** Both `(r, s)` and
`(r, n − s)` verify, so the forty checks pass with either and the defect was invisible to them. Over
5000 signatures from the shipped signer, with the flip off, the honest count is **1250 high-s and 0
self-verify failures**.

**And the fix for the low-s is not yet made, because measuring it found a further defect the review
could not reach.** micro-ecc's `uECC_sign` writes `r` and `s` in the *native* word order of the build
— `uECC.c` casts the caller's signature buffer straight to `uECC_word_t *p` and multiplies into it,
and copies `s` out of a native word array — so on a little-endian target both halves are
little-endian, and a `memcmp` of `s` against a big-endian half is a coin flip. Flipping on that
comparison was measured at **2493 self-verify failures in 5000 signatures**: it corrupts half of
them. The flip is therefore **off** in the delivered signer, the signatures it makes all verify, and
what they are not yet is low-s.

The next step is the whole of it: normalise both halves out of the native order first, flip, and let
`low-s` say `high=0`. The two numbers above are what that change will be measured against.

### What the byte order is not

`uECC_VLI_NATIVE_LITTLE_ENDIAN` is **0** unless a build asks for 1 — `uECC.h:51-52` — and
micro-ecc's own note says the two settings produce incompatible keys and signatures. So `r` and `s`
come out of `uECC_sign` as **big-endian bytes**, and `uECC_compute_public_key` writes the two
coordinates big-endian too. The review confirmed it independently.

That was checked here the hard way as well, and it is worth recording because the first attempt to
"fix" it made things worse: a public key rebuilt by reversing the 64 coordinates came out
`04 a8 e7 ee …`, and since `X < p` a big-endian `X` starts `0xff`, an `0xa8` first byte is a
little-endian one. The reversal was reverted; the signer writes the coordinates through as they come.

So the flip's failure is **not** a byte-order problem: the comparison and the subtraction are both
over the right bytes, the order and its half are FIPS-correct, and `s' = n − s` corrupts the
signature for about half the inputs for a reason that is not yet established. It is one function and
one test, and the test is in the tree:

    tests/backports/host/cloudkit/run.sh      # its `low-s` mode over 5000 signatures

The two numbers the wrong belief produced, both from the shipped signer, kept so the mistake is not
made again:

    flip on, reader requiring 72:    self-verify failures 2555 of 5000
    flip on, reader reading lengths:  low-s 5000, high 0, self-verify failures 0

`n − s` is unit-tested on its own against Python over 20 random values above `n/2`, in both the
separate-buffer and the aliased form the signer calls it: 0 wrong of 20.
