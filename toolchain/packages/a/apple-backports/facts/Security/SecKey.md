# The SecKey functions of iOS 10

iOS 10 replaced the old key API with five functions that take a CFError instead of an OSStatus and name an algorithm
instead of a padding. A program built against them and run on iOS 6 does not fail politely: the weak reference is NULL
and the call goes to address zero on the path that makes its keys, which is usually the path that starts the program.
None of the five needs anything iOS 6 has not got.

Read from: the armv7 shared cache of iOS 6.1.3, for what Security exports and for the armv7 code of the private entry
points, disassembled; the caches of iOS 6.0, 6.1.6, 7.0, 7.1.2, 8.0, 8.4.1, 9.0, 9.3.6 and the armv7s cache of 10.3.4,
which all export the same private entry points, so no band of the package loses them; `SecKey.h` and `SecItem.h` of SDK
16.4 for the signatures, the padding values and the algorithm names; the host's own Security for the shape of the
CFError and of the two external representations.

## What iOS 6 already has

Security of iOS 6.1.3 exports `SecKeyGeneratePair`, `SecKeyEncrypt`, `SecKeyDecrypt`, `SecKeyRawSign`,
`SecKeyRawVerify` and `SecKeyGetBlockSize` as public API, and these private entry points, which are the ones that make
the difference:

- `SecKeyCopyPublicBytes(SecKeyRef, CFDataRef *)` at 0x32e90511. It asks the key's own class for its public bytes and
  answers `errSecUnimplemented` for a class that has none.
- `SecKeyCreateFromPublicData(CFAllocatorRef, CFIndex algorithmID, CFDataRef)` at 0x32e90545, which reads the data's
  bytes and length and hands them to `SecKeyCreateFromPublicBytes` at 0x32e90525; that one divides the algorithm
  identifier - 1 is RSA and 3 is elliptic curve - and calls `SecKeyCreateRSAPublicKey` or `SecKeyCreateECPublicKey`
  with the encoding those two want. The port never names that encoding itself: the release's own function knows it.
- `SecKeyGetAlgorithmID(SecKeyRef)` at 0x32e904fd, which asks the key's class and answers 1 where the class does not
  say, so an RSA key of the release answers 1.
- `SecKeyCopyAttributeDictionary(SecKeyRef)`, the dictionary a key hands to `SecItemAdd`.

## The five functions

`SecKeyCreateRandomKey` hands the parameters to `SecKeyGeneratePair` untouched, releases the public half and answers
the private key, which is what iOS 10 answers. `kSecAttrIsPermanent`, `kSecAttrKeyType`, `kSecAttrKeySizeInBits`,
`kSecPrivateKeyAttrs` and `kSecPublicKeyAttrs` are all names iOS 6 exports and reads itself, so the meaning of the
dictionary is the release's, not the port's. A key type the release's generator will not make - and it has RSA and
elliptic curve - comes back as NULL and a CFError holding its OSStatus.

`SecKeyCopyPublicKey` is `SecKeyCopyPublicBytes` followed by `SecKeyCreateFromPublicData` with the key's own algorithm
identifier. Where the release cannot serialise a public half it answers NULL, which the header states is the answer
when no public key is available.

`SecKeyCreateEncryptedData` and `SecKeyCreateDecryptedData` turn the algorithm into the padding of the release's own
`SecKeyEncrypt` and `SecKeyDecrypt`, in a buffer of `SecKeyGetBlockSize` bytes cut to the length the release wrote:

| algorithm | padding of iOS 6 |
| --- | --- |
| `kSecKeyAlgorithmRSAEncryptionRaw` | `kSecPaddingNone` |
| `kSecKeyAlgorithmRSAEncryptionPKCS1` | `kSecPaddingPKCS1` |
| `kSecKeyAlgorithmRSAEncryptionOAEPSHA1` | `kSecPaddingOAEP` |

`SecKeyCopyExternalRepresentation` answers the PKCS#1 bytes of the key it is given: 270 of them for the public half of
a 2048-bit RSA key, a `SEQUENCE` of the modulus and the exponent, and 1193 for the private key, a `SEQUENCE` that
starts with a version of zero and holds nine integers. The port takes the data out of the key's attribute dictionary
and parses it before it trusts it: nine integers starting at zero is a private key and is answered as it stands.
Otherwise it asks for the public bytes and answers them only where the key is proven to be a public one - either its
attribute dictionary holds exactly those bytes, which a private key's does not, or the dictionary names the key class
as public. Where neither holds, the answer is NULL and a CFError.

## What it refuses, and why it refuses rather than guesses

- Every algorithm outside the three above - `RSAEncryptionOAEPSHA224` and the rest of the digests,
  the `AESGCM` variants, and everything elliptic-curve - is refused with NULL and a CFError of
  `errSecParam` whose message names the algorithm and the key, the way the system refuses an algorithm a key cannot
  perform. iOS 6's `kSecPaddingOAEP` carries no choice of digest and is SHA-1, so answering an OAEP-SHA256 call with
  SHA-1 padding would be a different cipher text under the name of the one that was asked for.
- A private key whose external representation the release does not keep is refused rather than answered with its public
  half. A caller that asks for a key's representation and is handed the public half sends the wrong thing and never
  learns of it, which is the failure this package exists to avoid.
- Every CFError is domain `NSOSStatusErrorDomain`, code the OSStatus, `userInfo` with `NSDescription`, which is the
  shape the host's own Security produces; a caller that reads `error.code` reads the release's own status.

## What is not carried

**Nothing about `SecKeyCreateWithData` is claimed, in either direction.** It is **owed**: the release
*could* carry it, since `SecItemAdd` and the key classes are there, but no entry point has been written.
`DecisionTable.md` marks the row **owed** for that reason, and the registry carries **no row for it at
all** - not `absent`, because `absent` is for API only the hardware lacks and this is unfinished work,
and not `implemented`, because there is no function. A caller building a key from raw bytes on 6.1.3 gets
a NULL weak reference, and that is unrecorded on purpose until the entry point exists.

### Owed, in full

- **`SecKeyCreateWithData`** - the entry point itself, then its row.
- **The guest measurement** of the keychain halves: `SecKeyCopyAttributes`'s shaping, the key lookup
  inside `SecKeyIsAlgorithmSupported`, and an actual `SecKeyRawSign` / `SecKeyRawVerify` round trip
  through the padding mapping. Every host case so far has driven the **pure** half with no key and no
  keychain, so the padding mapping is checked and the signing is not. The slot is the coordinator's to
  give; nothing is owed to a run that has not happened.
- The 11 `SecTrust*`, 4 `SecCertificate*`, 2 `SecPolicy*` and 1 `SecAccessControl*` rows.
- The 59 inert rows, and the export.

The other five are carried, and their rows are in `registry/Security/ios10keys.json`:

| API | What it does on the release |
| --- | --- |
| `SecKeyCopyAttributes` | the key's own keychain entry, asked with two-argument `SecItemCopyMatching` (`kSecKey.h:1162`) |
| `SecKeyIsAlgorithmSupported` | the key's class against the table: four RSA PKCS1 digest algorithms for sign and verify, the two ECDSA digest algorithms for an EC key, two RSA encryption ones, key exchange refused |
| `SecKeyCreateSignature` | `SecKeyRawSign` with the padding the algorithm names - `0x8002` and `0x8003`-`0x8006` for RSA (`kSecKey.h:198-218`), `kSecPaddingNone` for an EC key and `kSecPaddingPKCS1` once if the release refuses that |
| `SecKeyVerifySignature` | `SecKeyRawVerify` with the same padding, so its PKCS1 padding is *checked* (`kSecKey.h:684-690`) |
| `SecKeyCopyKeyExchangeResult` | **implemented for a key of the port's own kind, refused for every other**: the curve answers a real secret there, and every other key gets NULL with an `NSError` in `NSOSStatusErrorDomain` and `errSecParam` naming why. The refusal rests on a measurement, not on the key's type: the armv7 shared cache of 6.1.3 exports `SecKeyRawSign`, `SecKeyRawVerify` and no elliptic key agreement of any name, its only agreement being the finite-field `SecDH` family, which is not a curve |

A refusal on the first four is NULL or `false` **with no `CFError` set**, because each signature's
documentation names no domain or code for it, and the port does not manufacture one a caller would
handle as though the SDK had promised it. **The exchange is the exception and says so**: it answers
`errSecParam`, which is the release's own code for a parameter it will not accept and the only one its
documentation leaves, and it is built in one place - `CharonSecKeyFail` - which the curve's refusals
use as well.

### The EC key type, and what an earlier version of this file said about it

**iOS 6.1.3 has an EC key type.** `SecItem.h:802-803` declares

    extern const CFStringRef kSecAttrKeyTypeEC
        API_AVAILABLE(macos(10.9), ios(4.0));

and `kSecAttrKeyTypeECSECPrimeRandom` two lines below it (`:804-805`) is `ios(10.0)` - a *different*
class, the one Apple's own 10.0 API names. An earlier version of this file read "NO EC KEY TYPE AT ALL"
off `:804-805` against `:784-785`, stepping over the two lines that say otherwise, and this same file
said the opposite 65 lines up: "A key type the release's generator will not make - and it has RSA and
elliptic curve". The second of those two sentences is the true one.

So the release's own primitive signs an EC key, and the four functions are carried for one:
`SecKeyRawSign` and `SecKeyRawVerify` take an elliptic key and a digest, and the padding is this
package's own mapping - `kSecPaddingNone`, which is what "the bytes as they are" means and is the only
padding a curve has, asked once more with `kSecPaddingPKCS1` if the release refuses that, because some
releases want the RSA padding name for the same call. **Which of the two the 6.1.3 release takes is
still unmeasured**: `tests/backports/host/seckeycurve/emulate.sh` settles it and has not run, and a
host differential cannot see it - the host's own `SecKeyCreateSignature` accepts either padding for an
elliptic key, measured, with the EC row of the padding map mutated to PKCS1: 93 checks, 0 failures.

### Two kinds of key, one public symbol

Each of the four is carried for **two** kinds of key, and this file is the one of the two that
answered for a key of the release's keychain:

| key | sign | verify | exchange | says |
| --- | --- | --- | --- | --- |
| the release's own keychain, EC or RSA | `SecKeyRawSign` with the padding above | `SecKeyRawVerify` with it | refused, `errSecParam` | the table above |
| the port's own kind: the marker `CharonSecKeyScalar` beside a 32 byte `kSecValueData` | the curve, over `charon@micro-ecc` | the curve | the curve | sign, verify and exchange |
| a class the release takes nothing from - `kSecAttrKeyTypeAES` is `ios(NA)` | refused | refused | refused | false for everything |

The public symbol for each of the four is in `SecurityFunctions10_0_1.m`, **once**, and it dispatches on
one attribute; the curve is in `Security/SecKeyElliptic10.m`, which defines no public `SecKey*` symbol
at all. That is not tidiness: two objects of one library defining one name is a link error, and the
6.1.3 gate answered with four of them -
`duplicate symbol '_SecKeyCreateSignature' in: Security/SecKeyElliptic10.o and
Security/SecurityFunctions10_0_1.o` - because this file's file and that one could not see each other.

The four functions were each *implemented twice* until that merge, and the registry could not see it:
the rows were in two different registry files, and the check asks whether a row has code, not whether
two files claim the same API. `registry/Security/ios10keys.json` holds one row per API now, and
`facts/Security/SecKeyElliptic.md` is the other half - the curve, its measurement, and the three
`Charon*` names the dispatch calls.

The matrix was four kinds of key by four functions, and every cell had a red of its own when it was measured:
sixteen cells, fourteen of them by a mutation in `tests/backports/host/seckeycurve/mutate-cells.py` (a driver
with no caller, since deleted, so that run is history), and two - signing and verifying with a key of a class
the release takes nothing from - by the pure table, because the host's own primitive refuses the same key a
128 bit AES key and no key can see that cell on a Mac (measured). That run was 93 checks, 0 failures.

### A disagreement this file had with itself

An earlier revision of this file listed all six as "stay absent ... nothing has asked for them yet",
while `DecisionTable.md` marked all six **implemented**. Both were wrong about the same five rows in
opposite directions, and neither matched the tree: five entry points existed and one did not. The
registry is what is state, so it now carries five rows in `ios10keys.json` (four implemented, one
inert) and one in `absent_Security.json`. The table's middle column is a **decision** - whether the port
*could* act - and its count line is a count of decisions, which is how a row marked implemented there
came to be a function that was never written.
