# The eleven RFC 4754 ECDSA algorithm names (iOS 17.0)

These are names, not operations. A program that names them compiles and links against this port on iOS 6.1.3 and
reads the same strings the host's Security answers with. No operation in this port takes them.

Measured:

- Values: each name's CFString is the string the host's own Security.framework returns for it, read by dlsym off the
  host's framework and compared as strings by tests/backports/host/commoncrypto/differential-constants.c (90 constants,
  failures 0, run by tests/backports/host/commoncrypto/run.sh on macOS).
- 6.1.3: the armv7 Security image of the 6.1.3 cache exports none of the eleven names. `tools/image-exports.lua 6.1.3
  armv7 "Security.framework/Security" ""` lists 660 exports; a search for RFC4754 in them finds 0.
- Behaviour: a grep of the port's sources finds the eleven names only in SecurityNames170.m (and the older
  kSecKeyAlgorithmECDSASignatureRFC4754 in SecurityNames100.m, a different name). No operation of the port takes them,
  and an ECDSA signature in the RFC 4754 layout (r and s concatenated, each padded to the curve size) is not produced or
  checked anywhere in the port. SecKeyIsAlgorithmSupported's answer for these names was not run in this step.
- Upstream: the eleven strings match upstream's SecKeyAdaptors.m verbatim (checked by grep -F, 11 of 11).

Declared: SDK 26.2, SecKey.h, introduced 17.0; upstream's SecKeyAdaptors.m declares the same eleven strings
(apple-open-source Security, APSL-2.0), so the upstream-only route for these rows is the constant alone.

Not done: the RFC 4754 signature and verification paths. They need the ECDSA code of this port (vendored micro-ecc),
which is a separate row and not carried in this step.
