# Security on iOS 6: access control, keys and shared credentials

The values the Security backport answers, where each came from, and what has no measurement yet. The backport is
`frameworks/Backports/src/Security`; its host tests are `tests/security_access_control_test.lua`,
`tests/security_shared_web_test.lua`, `tests/security_item_test.lua` and `tests/security_key_test.lua`.

## Sources

- **macOS 27.0.1 (26A434), Command Line Tools SDK.** The real system for the shared parts: SecAccessControl,
  SecKey export and key operations, and the shared web credential calls. The access-control and shared-credential
  parity tests compile one fixture against this system's Security framework and against the backport source, and
  require identical output.
- **iPad 2 (iPad2,2) on iOS 6.1.3.** The real system for what iOS 6 has: the keychain and SecKey on the release
  itself. Its keychain answers are blocked; see below.
- **Not available.** No iOS 8+ device or simulator is on this machine (only the Command Line Tools, no Xcode). The
  iOS 8+ answers for SecAccessControl error paths, Secure Enclave keys and valid shared web credential requests are
  therefore not measured on iOS, and the backport follows the macOS answers where they exist.

## Access control (SecAccessControlCreateWithFlags), measured on macOS

- The protection must be one of `kSecAttrAccessibleWhenUnlocked`, `AfterFirstUnlock`, `Always`,
  `WhenUnlockedThisDeviceOnly`, `AfterFirstUnlockThisDeviceOnly`, `AlwaysThisDeviceOnly` or
  `WhenPasscodeSetThisDeviceOnly`. A NULL protection, a non-string and any other string give `errSecParam` (-50).
- These flag sets give -50: `Or` with `And`; `biometryAny` with `biometryCurrentSet`; `userPresence` with
  `biometryAny`, `biometryCurrentSet`, `devicePasscode`, `companion`, `Or`, `And`, or the reserved bit 2
  (`1 << 2`).
- These are accepted: any single flag; `biometryAny` with `devicePasscode`, `companion` or `Or`; `devicePasscode`
  with `companion` or `Or`; `userPresence` with `privateKeyUsage` or `applicationPassword`; `Or` with
  `privateKeyUsage`, `applicationPassword` or `devicePasscode`; unknown bits above bit 2 (`1 << 20` with
  `biometryAny` was accepted).
- The type name is `SecAccessControl`. `CFEqual` holds when protection and flags are both equal. macOS's `CFHash`
  is identity-based; the backport's hash agrees with its equality instead, which is the contract the release keeps.

## Secure Enclave keys, measured on macOS

- An ephemeral key with `kSecAttrTokenIDSecureEnclave`, `ECSECPrimeRandom`, 256 bits and `privateKeyUsage` is
  created without an entitlement. Its token reads `com.apple.setoken`.
- `SecKeyCopyExternalRepresentation` on the private half gives NULL with `NSOSStatusErrorDomain` -4 and the text
  "export not implemented for key" followed by the key. This is the answer the backport gives for such a key.
- The public half exports as 65 bytes beginning `04`.
- ECDSA signing (X9.62, SHA-256) with `privateKeyUsage` alone verifies, and `ECDHKeyExchangeStandard` gives 32
  bytes. Neither asked for user presence.
- Permanent Secure Enclave keys were not measured; only ephemeral ones.

## Software keys, measured on macOS

- EC P-256 private export: 97 bytes, `04 || X || Y || K`. Public export: 65 bytes, `04 || X || Y`.
- RSA-2048 private export: 1190 bytes beginning `30 82 04 a2`, which is PKCS#1 `RSAPrivateKey`.

## Shared web credentials, measured on macOS

- `SecAddSharedWebCredential` with a NULL or empty fqdn: callback with `errSecParam` (-50), asynchronously.
- `SecAddSharedWebCredential` with a valid fqdn, with or without a password: callback with -4, "SecAddSharedWebCredentialSync
  not supported on this platform".
- `SecRequestSharedWebCredential` with a NULL or empty fqdn: callback with NULL credentials and -50.
- `SecRequestSharedWebCredential` with a valid fqdn: no callback within 90 seconds on this headless machine. It waits
  on something this process cannot answer, so the answer is unmeasured. The backport gives -4, the same answer its
  Add gives for a valid fqdn on the same release.
- `SecCreateSharedWebCredentialPassword` on macOS gives 15 characters in four groups of three separated by hyphens,
  with a digit, an upper-case and a lower-case letter. The backport's 200 samples have the same shape.

## iPad 2 on iOS 6.1.3

- `Security.framework` does not export `kSecAttrKeyTypeECSECPrimeRandom`. A binary that references it fails at launch
  with `Symbol not found`. The backport defines the constant as `"73"`.
- `SecKeyGeneratePair` with the EC key type returns -4 (`errSecUnimplemented`).
- Every keychain call returns -25308 (`errSecInteractionNotAllowed`): a lookup of an absent item, a generic password
  added with each accessibility class, and key generation. The calls were made from an SSH session as root, as
  `mobile`, and from an app launched through SpringBoard with `keychain-access-groups`. The device is unlocked, has no
  passcode, runs `securityd`, and has `keychain-2.db`. `keybagd` is not running. The cause is not yet found, so the
  persistent-reference read of a private key (gap 3) and the storage of an emulated key are not measured on iOS 6.
  The probe is `tests/Security/device/probe.c`, built by the `SecurityProbe` target. It also reads the MobileKeyBag lock
  state before the keychain calls: `MKBGetDeviceLockState(NULL)` returns 3 and `MKBDeviceUnlockedSinceBoot()` returns 1
  (no passcode, nothing changed). `MKBUnlockDevice` is exported (checked with `dlsym`, not called).

## LocalAuthentication, measured on the iPad 2

- `tests/LocalAuthentication/device/probe.m` compiles the backport's `LAContext.m` and `LAErrorDomain.m` into a binary and
  runs it on the iPad 2 (6.1.3, no passcode).
- Biometrics policy: `canEvaluatePolicy` NO, code -6, and `evaluatePolicy` the same. -6 is `kLAErrorTouchIDNotAvailable`,
  which is `kLAErrorBiometryNotAvailable` in the macOS 27 SDK (`LAPublicDefines.h`). The iPad has no Touch ID.
- Device-owner policy: `canEvaluatePolicy` NO, code -5 (`Passcode not set.`), and `evaluatePolicy` the same. -5 is
  `kLAErrorPasscodeNotSet` in the macOS 27 SDK. The answer follows the MobileKeyBag state 3, which is the no-passcode
  reading above.
- iOS 6 has no LocalAuthentication framework, so the answers above follow the iOS 8+ contract. They are reproduced
  without an iOS 8+ device, so the iOS 8+ values are not measured.
- With a passcode set the backport answers NO with `LAErrorNotInteractive` (-1004). That path is not measured: the
  set-passcode state needs a device with a passcode, and iOS 6 offers an app no passcode prompt to verify. The backport
  never answers YES for device-owner authentication.

## MobileKeyBag and the passcode, from the 6.1.3 image

Read from the iOS 6.1.3 MobileKeyBag image (`/System/Library/PrivateFrameworks/MobileKeyBag.framework/MobileKeyBag`, taken
with `xmake firmware --library=... extract 6.1.3` and disassembled with `llvm-objdump --triple=thumbv7-apple-ios6.1`).
Nothing was called on any device.

- `MKBUnlockDevice` takes one argument, in r0. The wrapper reads it as a `CFDataRef`: `CFDataGetBytePtr` and
  `CFDataGetLength` give the bytes and their length, and `_AppleKeyStoreUnlockDevice` sends them to the kernel as the input
  struct of selector 9 of the AppleKeyStore user client. The image does not show what the bytes must hold (the passcode as
  typed, or a value derived from it). The kernel decides.
- The return value is the wrapper's status. The kernel's codes map as follows: 0 gives 0; 0xE00002E2 gives -2; 0xE00002F0
  gives -8; 0xE00002CE gives -3; 0xE00002C9 gives -9. Any other non-zero code gives -1 and writes a log line.
- Before the call the wrapper connects to the AppleKeyStore user client (`_connect_to_service`). With no connection it
  returns 0xE00002BC. The privilege that decides whether the call is allowed is in the kernel, which this image does not
  contain. No entitlement name appears in MobileKeyBag; the only service name is `com.apple.mobile.keybagd`, which is not
  the AppleKeyStore path.
- The lock state is `MKBGetDeviceLockState` (3 is the no-passcode state, measured on the iPad 2), with
  `MKBDeviceUnlockedSinceBoot` beside it.

What this does and does not settle:

- An app can verify a passcode only if the kernel allows the call from an app's process, and only if the argument's bytes
  are what it expects. Neither is measured. The backport therefore keeps the device-owner answer fail-closed.
- Whether a wrong argument counts against the passcode attempts, or locks the device for a while, is not known. A
  probe on an owner's device with a passcode set must not run without the owner's word.
- Measurements still open, each under a device claim: the status with an empty argument on a phone with no passcode
  (state 3), and the status from a process that runs as `mobile` rather than root. The passcode type setting (simple or
  complex) is not located in the image yet.

## SecItem access control on iOS 6

- `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate` and `SecItemDelete` are defined by the backport and forwarded to the
  system's Security image through `dlsym`, as the IOSurface wrapper does. On a system that enforces access control (iOS
  8 and later, detected by `SecAccessControlGetTypeID`) the forwarders pass every call through unchanged.
- On iOS 6 an item that carries `kSecAttrAccessControl` with a user-authentication flag is gated in the backport. A query
  that forbids UI gets `errSecInteractionNotAllowed` (-25308). A query that allows UI runs the LocalAuthentication
  device-owner evaluation first and fails when that evaluation is refused, so with no passcode set the gate fails closed.
  The gate's state is a sidecar generic-password item keyed by the SHA-256 of the item's persistent reference.
- The contract the host test checks (`tests/Security/items/contract.c`) is a literal: add ok, copy and update without UI
  -25308, cleanup ok. It is not a macOS oracle. macOS refuses to add an access-control item from a command-line process
  (-34018, `errSecMissingEntitlement`), so the release's answers were not measured on the host. The device has not confirmed it.

## Secure Enclave keys on iOS 6: the representation

iOS 6 has no Secure Enclave, and the Security calls that take an EC key (`SecKeyCreateRandomKey` with
`kSecAttrTokenIDSecureEnclave`, `SecKeyCreateSignature`, `SecKeyCopyKeyExchangeResult`) are iOS 8 and later. An app that
asks for a Secure Enclave key needs three things back: a `SecKeyRef` it can hold and pass to the SecKey calls, a public
key it can export, and the same key after a relaunch, looked up by its application tag. The private half must never
leave the backport.

The decision: on the device the key is a genuine `SecKeyRef`, so `CFGetTypeID(key) == SecKeyGetTypeID()` and the system's
SecKey calls work on it. The backport makes it with `SecKeyCreate`, which is in the 6.1.3 Security image; the call is
looked up with `dlsym` and passed a descriptor of the backport's own (`frameworks/Backports/src/Security/SecureEnclaveKey9.m`,
the `TARGET_OS_IPHONE` branch). The descriptor is the version 2 `SecKeyDescriptor` of Apple's open source Security
(Security-55179.13, `sec/Security/SecKeyPriv.h`):

- `version` 2 and `extraBytes` 0, so the system leaves `key` NULL. The descriptor's `init` stores a pointer to the
  backport's state there, and `destroy` frees it.
- `rawSign` (private keys only), `rawVerify`, `blockSize` (32), `copyDictionary`, `getAlgorithmID` (3, ECDSA) and
  `copyPublic` (the 65-byte point) do the work through micro-ecc. `encrypt`, `decrypt` and `compute` are NULL. The system
  checks `encrypt` and `decrypt` for NULL before it calls them, and nothing in 55179.13 calls `compute`, so key agreement
  goes through the backport's exchange path (`RevenantSecKeyECExchange`).
- The state holds the tag, the 65-byte point, the scalar of an ephemeral key, and the flags. A permanent key keeps its
  scalar in the keychain.

Evidence for the layout on iOS 6.1.3. The 6.1.3 Security image was extracted and disassembled with
`llvm-objdump --triple=thumbv7-apple-ios6.1 --mcpu=cortex-a8` (`otool` cannot read the extracted image). It exports
`SecKeyCreate` and the SecKey accessors the backport calls. `SecKeyCopyPublicBytes` reads the descriptor's `version` at
offset 0 and returns -4 below 2. The release reads `rawSign` at +0x14, `blockSize` at +0x28, `copyDictionary` at +0x2c and
`copyPublic` at +0x34, which is the open source v2 layout on armv7 (the `key_class` field at +0x8 and `key` at +0xC). The
constants come from the same headers: `kSecKeyEncodingBytes` is 7 and `kSecECDSAAlgorithmID` is 3. The scratch sweep that
removed the extracted image came after this check, so the image is not on disk to re-read.

On the host, macOS has no `SecKeyCreate`, so the host build keeps the backport's own CoreFoundation type `RevenantSecKey`
with the same state (the `#else` branch). That type is only the host's fallback. Its `CFGetTypeID` is not
`SecKeyGetTypeID()`, and the host parity test covers the backport's public API (`SecKeyCopyPublicKey`,
`SecKeyCopyExternalRepresentation`, sign, verify, key agreement), not the system's SecKey accessors on the key.

Keychain material for permanent keys:

- the private scalar, service `org.revenant.secure-enclave.private`, account the hex of the application tag, stored with
  the key's protection class and its `SecAccessControl`. Every read goes through `SecItemCopyMatching`, so the gate of the
  SecItem layer applies to each signature and exchange;
- the public point (65 bytes), service `org.revenant.secure-enclave.public`, `AfterFirstUnlockThisDeviceOnly`, so a
  lookup of the public key needs no gate.

Why the keychain holds the material:

- A key that lives only in memory dies with the process. A Secure Enclave key survives a relaunch, so the keychain holds it.
- A scalar stored as a plain keychain item, with no access control, could be read by anything under the app's access
  group with no gate. Carrying the access control on the item keeps the gate on each use.

What the key answers (`SecKeyCreateRandomKey`, `SecKeyCopyPublicKey`, `SecKeyCopyExternalRepresentation`,
`SecKeyCreateSignature`, `SecKeyVerifySignature`, `SecKeyCopyKeyExchangeResult`):

- Create: P-256 only, 256 bits. A permanent key needs an application tag, and the tag must be free.
- Export: the private half returns -4 with "export not implemented for key", the answer the macOS oracle gives. The public
  half returns the 65-byte point beginning `04`.
- Sign and verify: ECDSA, X9.62, SHA-256, through micro-ecc. The signature is DER.
- Key exchange: raw ECDH, `kSecKeyAlgorithmECDHKeyExchangeStandard` and `kSecKeyAlgorithmECDHKeyExchangeCofactor`. P-256
  has cofactor 1, so the two agree. The X9.63 KDF variants return -50, because the backport does not derive keys.
- Lookup: `SecItemCopyMatching` with `kSecClassKey` and an application tag returns the key when the system does not
  enforce access control. Delete removes both items.

Caveats:

1. The device check of the genuine `SecKeyRef` is not run yet. It needs the type identity, the system's
   `SecKeyGetBlockSize`, `SecKeyGetAlgorithmID`, `SecKeyCopyPublicBytes` and `SecKeyRawSign` on the key, and the `-25308`
   theory (an app bundle with a `keychain-access-groups` entitlement). All of it waits for the batch prebuilt of the
   armv7 build and an iphoneos configure. Telegram's `LocalAuth.swift` type check (`getPrivateKey`, in
   `~/Git/reference/Telegram-iOS-release-13.0.0`, outside `ios/`) is the caller this serves.
2. A key whose access control asks for user presence or a passcode fails closed on iOS 6 until the passcode prompt is
   built. The LocalAuthentication device-owner answer with no passcode is -5.
3. Ephemeral keys live in memory. Permanent keys need the keychain, which returns -25308 on the iPad 2 (see above), so the
   permanent path is not measured on iOS 6.

Host verification (`tests/security_key_test.lua`): one fixture runs against macOS's Security framework and against the
backport with the emulation on. The outputs must equal each other and a literal contract: create, the export length and
prefix, the export refusal -4, sign and verify (own, other key, tampered message), and the ECDH length and symmetry. The
backport's DER signature and public point must verify with `openssl dgst -sha256 -verify` (LibreSSL 3.3.6), and a changed
message must fail. micro-ecc is fetched at its pinned commit by `tests/Security/micro_ecc.lua`.

## What is implemented, and what is not

- **Implemented, host-tested against macOS:** the SecAccessControl type, its creation rules and equality; the shared
  credential calls' validation and completion; the shared password's shape; the Secure Enclave key's public API (create,
  copy public, export refusal, sign, verify, key agreement) against the macOS oracle.
- **Implemented, checked only against the literal contract on the host:** the SecItem forwarders and the access-control
  gate; the Secure Enclave key lookup and delete that `SecItemCopyMatching` and `SecItemDelete` reach for an application
  tag.
- **Implemented, not verified on iOS 6 hardware:** the genuine `SecKeyRef` of the device branch (type identity and the
  system's SecKey calls on it); the permanent keys and their keychain lookups, which wait for the keychain on the iPad 2;
  `SecKeyCopyExternalRepresentation` on a private software key, which reads the stored data through the key's persistent
  reference (`kSecValueRef` with `kSecReturnPersistentRef`, then `kSecValuePersistentRef` with `kSecReturnData`) and
  returns it when it is a PKCS#1 private key.
- **Implemented, measured on the iPad 2:** the LocalAuthentication answers above (no YES for device-owner).
- **Open, not measured:** device-owner authentication with a passcode set, the passcode entry that matches the system's,
  and whether an app can verify a passcode through `MKBUnlockDevice` (its argument is a `CFDataRef` and its privilege is in
  the kernel; see "MobileKeyBag and the passcode"). The
  user-presence gate fails closed until that entry exists.
- **Not implemented:** the passcode prompt. Until it exists, every gate that needs user presence or a passcode fails closed.
