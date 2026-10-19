# The seckeycurve host case: what it builds, and what it cannot see

The case that holds the port's P-256 surface to the host's own `Security.framework` and to OpenSSL, in
both directions. `run.sh` is the whole of it: one line each for the two keys, the differential, the
matrix of sixteen mutations (`mutate-cells.lua`), the result. It is a `clang` compile and a run on this Mac,
so it is not a build and the machine's load does not apply.

## It holds two port files together, and that is the point

`SecKeyIsAlgorithmSupported`, `SecKeyCreateSignature`, `SecKeyVerifySignature` and
`SecKeyCopyKeyExchangeResult` are the four Security calls of iOS 10. They are defined **once**, in
`packages/a/apple-backports/Security/SecurityFunctions10_0_1.m`, for two kinds of key at once:

| key kind | sign and verify | exchange | what the port reads to tell them apart |
| --- | --- | --- | --- |
| a key of the **release's** keychain | `SecKeyRawSign` / `SecKeyRawVerify` with the padding the package's own map chooses | refused, `errSecParam` | the release's keychain, through `SecItemCopyMatching` |
| a key of the **port's own kind** | the curve, `charon@micro-ecc`, in `SecKeyElliptic10.m` | the curve | the marker `CharonSecKeyScalar` beside a 32-byte `kSecValueData` |
| a class the release takes nothing from | refused | refused | `!rsa && !ec` |

`run.sh` therefore compiles **both** files with the same `-D` renames and links both, which is what the
library's own link does. Two objects of one library defining one public name is a link error - the
6.1.3 gate answered with four of them - and this case is what would have shown it earlier, because it is
the one place the public symbol is called with a real key.

## What the shims answer, and none of it is the port's code

`port-shims.h` answers what the *release* offers and the host does not have, in the shape of the
release's own calls. `port-shims-impl.m` holds the state and the definitions, because the header is
included by both port files and a non-static definition in it is defined twice - the same class of
defect the gate found, one level down.

| the release's call | what the host cannot do | what answers it here |
| --- | --- | --- |
| `SecKeyRawSign`, `SecKeyRawVerify` | not declared by the macOS SDK at all (iOS 2.0) | the host's own signing and verification, at the algorithm the **padding** names: `kSecPaddingNone` is an elliptic key, the four PKCS1 digest paddings are RSA keys |
| `SecKeyCopyPublicBytes`, `SecKeyCreateFromPublicData`, `SecKeyGetAlgorithmID` | private entry points no SDK declares | the host's own key, and a SubjectPublicKeyInfo the way the release serialises one |
| `SecItemCopyMatching` | an in-memory key is in **no keychain**: the host answers `errSecItemNotFound` (-25300) for every key this case makes - measured | what the harness says each key's class is, which is the one attribute the release-key path reads |
| `SecKeyCopyAttributeDictionary` | private | the marker and the 32-byte scalar, for a key the harness registered as the port's own kind; the host's own attributes for every other |

No keychain is touched, `kSecAttrIsPermanent` is never set, no `SecItem*` call reaches a real keychain,
and every key dies with the process.

## The matrix, and the two cells no key can see

The sixteen cells - four kinds of key by sign, verify, exchange and `IsAlgorithmSupported` - are driven by
`mutate-cells.lua`, one mutation each, each required to have a red check **that names that cell**. `run.sh`
runs it after the differential on every run, and a mutation that survives fails the run. Fourteen are held
there. Two - signing and verifying with a key of a class the release takes nothing from - cannot be: the host's
own primitive refuses a 128-bit AES key exactly as the port does, so nothing observable moves. They are held by the pure table,
`CharonSecurityCarries(operation, algorithm, false, false)`, which is the Security band's own case,
`tests/backports/host/security/supported.m`, which the driver names rather than counting them green.

One cell is worth naming because it changed: the **release-EC sign** cell's mutant is the *buffer
size*, not the padding. Which padding a 6.1.3 elliptic key takes cannot be seen from a host at all -
the host's own `SecKeyCreateSignature` accepts `kSecPaddingPKCS1` for an elliptic key as readily as
`kSecPaddingNone`, measured - so that question belongs to `emulate.sh` and is not claimed here.

## What this case measures, and what it does not

Measured, on this Mac, `checks=93 failures=0`: the release-key path in both directions for 0, 65 and
130-byte messages, the low-s half on both sides, the host refusing under SHA-384, the curve's signature
verifying under the host and the host's verifying through the curve, the exchange equal to OpenSSL's own
secret for the same two keys byte for byte with the digest-named form equal to SHA-256 of it, the RSA
row, and the class the release takes nothing from.

Not measured, and named in the facts files rather than here: anything on a device. Which padding the
6.1.3 release takes for an elliptic key, and whether it hands back the halves or a DER, is
`tests/backports/host/seckeycurve/emulate.sh`'s question and it has not run.
