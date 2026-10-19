# CCRandomGenerateBytes

Introduced in iOS 8.0 (`API_AVAILABLE(macos(10.10), ios(8.0))` in the SDK's CommonRandom.h):
`CCRNGStatus CCRandomGenerateBytes(void *bytes, size_t count)`. It lives in `libCommonCryptoBackports.dylib`,
built with the `commoncrypto` config.

## What the release has

- The 6.1.3 shared cache (armv7) exports `_SecRandomCopyBytes` and `_kSecRandomDefault` from Security,
  and `_CCRandomCopyBytes`, `_kCCRandomDefault`, `_kCCRandomDevRandom` and `_arc4random_buf` from libSystem.
  It does not export `_CCRandomGenerateBytes` (checked with `tools/image-exports.lua 6.1.3 armv7`).
- The status values are the SDK's own (CommonCryptoError.h): kCCSuccess 0, kCCParamError -4300,
  kCCRNGFailure -4307.

## Behaviour

| input class | answer |
|---|---|
| count 0, any pointer (NULL included) | kCCSuccess; nothing written |
| bytes NULL, count > 0 | kCCParamError; nothing written |
| bytes valid, count > 0 | SecRandomCopyBytes(kSecRandomDefault, count, bytes); kCCSuccess if it answers errSecSuccess, kCCRNGFailure otherwise |

The bytes come from the release's own generator, so they are as random as the device's. The port
does not construct a second generator.

## Host measurements (macOS, the oracle)

- count 0, NULL or valid: 0. count 1, 16, 4096, 1 MiB, 4 MiB, 16 MiB with a valid buffer: 0.
- NULL with count 1: -4300 (kCCParamError).
- count SIZE_MAX with a valid buffer: the host process crashes (signal 11) inside SecRandomCopyBytes, the same
  as the host's own SecRandomCopyBytes. A count larger than the caller's buffer is a caller error on the host.
  The differential does not compare that input class. The port inherits the crash on the same input.

## What the differential asserts, and what it does not

- Status codes per input class, against the host's CCRandomGenerateBytes (the oracle), for each class above.
- Output length: the bytes past `count` are untouched (canary bytes), and the `count` bytes are written. The
  second half is checked by "not all bytes equal the canary", which is a write check, not a randomness test.
- It does NOT test the randomness of the bytes. Statistical tests on random output are not an oracle for a
  generator: a correct generator and a broken one both pass a byte histogram at this size. The bytes are
  the release's own generator's; the port's contract is the call, not the entropy.

## Device status

Device-unverified: the host run measures the host, not the 6.1.3 SecRandomCopyBytes. Its answer for count 0 and
for NULL is measured on the host only, and the 6.1.3 generator's status is assumed to be errSecSuccess on success,
as the header states.
