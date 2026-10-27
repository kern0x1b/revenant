# Security on iOS 6: access control, keys and shared credentials

The values the Security backport answers, where each came from, and what has no measurement yet. The backport is
`frameworks/Backports/src/Security`; its host tests are `tests/security_access_control_test.lua` and
`tests/security_shared_web_test.lua`.

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

## What is implemented, and what is not

- **Implemented, host-tested against macOS:** the SecAccessControl type, its creation rules and equality; the shared
  credential calls' validation and completion; the shared password's shape.
- **Implemented, measured on the iPad 2:** the LocalAuthentication answers above (no YES for device-owner).
- **Open, not measured:** device-owner authentication with a passcode set, and whether an app can verify a passcode
  through `MKBUnlockDevice` (its signature and entitlement are unknown).
- **Implemented, not verified on iOS 6:** `SecKeyCopyExternalRepresentation` on a private key reads the stored data
  through the key's persistent reference (`kSecValueRef` with `kSecReturnPersistentRef`, then `kSecValuePersistentRef`
  with `kSecReturnData`) and returns it when it is a PKCS#1 private key. This waits for the keychain answer above.
- **Not implemented:** `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate` and `SecItemDelete` honouring
  `kSecAttrAccessControl`; the Secure Enclave key emulation; the EC private export that the emulation needs. Two
  decisions are open. The first is how an emulated EC key is represented: iOS 6 has no EC `SecKeyRef` to return,
  so the key is either a backport type or a keychain item the release can wrap. The second is the user-presence gate:
  iOS 6 has no passcode prompt for an app, so a gate that requires one has to fail closed until a prompt exists.
