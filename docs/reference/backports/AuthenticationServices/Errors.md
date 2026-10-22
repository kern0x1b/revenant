# AuthenticationServices error structs, measured

What `frameworks/Backports/src/AuthenticationServices/Errors.swift` carries, what it was checked against, and where it
differs from the host. Measured on 2026-10-17 from the `v-impl-appintents` worktree of the toolchain, with
the commands named below.

## What is carried

The spec rows are `the deleted registry package spec/AuthenticationServices/swift.tsv`: the four error
structs and their `Code` containers, 80 rows in all.

| Type | Rows | Carried |
| --- | --- | --- |
| `ASAuthorizationError` (struct, `_nsError`, `init(_nsError:)`, `errorDomain`, 11 static constants, `Code`) | 15 + 16 `Code` (its case rows and `rawValue`, `init(rawValue:)`, `RawValue`, `_ErrorType`) | all |
| `ASCredentialIdentityStoreError` (3 constants, `Code`) | 7 + 8 | all |
| `ASExtensionError` (5 constants, `Code`) | 9 + 10 | all |
| `ASWebAuthenticationSessionError` (3 constants, `Code`) | 7 + 8 | all |

The check was by name: each row's name was searched for in the file. 64 rows are named in the file
verbatim. The other 16 are the `init(_nsError:)` of each struct (written out) and the `init(rawValue:)`,
`rawValue` and `RawValue` of each `Code`, which the enum's raw type supplies. All 80 are carried.

Conformances follow the `_BridgedStoredNSError` shape that CloudKit's `CKError` uses. The probe
below confirms the host answers the same way: `CustomNSError`, `Hashable`, `Error`, `Equatable` and
`Sendable` all hold, and each `Code` is `_ErrorCodeProtocol`. `Code` needs its error type to be
`_BridgedStoredNSError` to conform, which is why the structs are declared that way.

## Domains and codes

- Domains: `com.apple.AuthenticationServices.AuthorizationError` (`ASAuthorizationErrorDomain`,
  the Backports `frameworks/Backports/src/AuthenticationServices/ASConstants13_0.m`),
  `ASCredentialIdentityStoreErrorDomain` and `ASExtensionErrorDomain` (`ASConstants12_0.m`),
  `com.apple.AuthenticationServices.WebAuthenticationSession` (`ASWebAuthenticationSession.m`).
  The host reads the same four strings (below).
- Codes: the `enumconst` rows of `declarations.tsv`, column `value`. `ASAuthorizationError` 1000 to
  1010, `ASCredentialIdentityStoreError` 0 to 2, `ASExtensionError` 0, 1, 100, 101, 102,
  `ASWebAuthenticationSessionError` 1 to 3.

## Measured against the host

The oracle is the macOS host's AuthenticationServices (macOS 27, Swift 6.4). The probe is
`frameworks/Backports/tests/SwiftRuntime/AuthenticationServices/errors/main.swift`, built twice:

- `swiftc -O main.swift` against the host's framework;
- `swiftc -DOURS -O main.swift files/AuthenticationServices/Errors.swift` against the file.

Results, from the two runs' stdout:

| Probe | Result |
| --- | --- |
| The four domain strings | identical on both |
| Wrapping a foreign NSError (`not.ours`, 1000): code, user info count, domain | identical |
| `canceled` built from its domain and code: code, user info count, domain | identical (1001, 0, the domain) |
| `_nsError` equality after a round trip | identical (`true`) |
| `storeBusy`, `credentialIdentityNotFound`, `canceledLogin` built as errors | identical |
| Conformance to `CustomNSError`, `Hashable`, `Sendable` | identical (true) |
| Conformance of each `Code` to `_ErrorCodeProtocol` | identical (true) |
| Static constant raw values (1001, 1010, 0, 101, 3) | identical |
| Non-code lines of the output | 11 of 11 identical |

### The divergence: the shape of each `Code`

On the host, `Code(rawValue:)` is not failable and the type is not a Swift enum. The probe prints
`ASAuthorizationError(rawValue: n)` and `ASWebAuthenticationSessionErrorCode(rawValue: n)`-style
descriptions for every `n` in the range, -1 included, and the host never prints a `none`. The file,
following the 26.2 SDK's declarations (`enum Code: Int`, with cases), is a failable enum whose
description is the case name.

- The host prints 1039 code lines (every `n` of the loops answers); the file prints 38 (its 20 cases
  and 18 `none`). No line is identical in both outputs: a case is printed by name on the file side
  and as `...(rawValue: n)` on the host side.
- 18 of the file's lines are `none` where the host answers with a value. These are the values
  outside the enum's cases (for example `ASExtensionError.Code(rawValue: 2)`).
- Which one a device shows is not measured: the iOS 26.2 SDK is not on the host to ask. The file
  follows the SDK's declared shape, because a program compiled against that SDK uses cases and
  `switch` on them. The same divergence was measured for CloudKit's `CKError.Code` ([CKError measured](../CloudKit/CKError.md)),
  so the two stay consistent.
- The probe prints every line, so a change on either side shows as a diff.

## Planted control

The probe has to be able to see a wrong answer. A scratch copy of the file with the WebAuthenticationSession
domain changed to `...WebAuthenticationSessionX` (outside the repository, under the run folder) was
built and diffed against the host output. The diff reports both lines that print the domain
(`domains` and `web-canceled`). So the domain lines are checked, and the control is seen.

## armv7

Toolchain: revenant@swift 6.4.0 (`swiftc` under its package folder, Apple Swift version 6.4). SDK:
iPhoneOS16.4 from the `iphoneos-sdk` 16.4 package, folder `081db8db...`. Runtime resource: a run-folder
symlink farm over the installed swift-runtime 6.4.0 `lib/swift` (variant `1b938f...`, the one whose
`share/lift/vfs.yaml` the CKError facts name), with `iphoneos/layouts-armv7.yaml` copied from the
toolchain's `legacy_layouts/iphoneos/` beside it. The object compile needs that layout file: without it
the compiler stops with "Cannot read legacy layout file".

- Typecheck: `swiftc -target armv7-apple-ios6.1.3 -sdk <iPhoneOS16.4.sdk> -resource-dir <farm>
  -vfsoverlay <variant>/share/lift/vfs.yaml -parse-as-library -typecheck files/AuthenticationServices/Errors.swift`
  exits 0, no diagnostics. The CKError file takes the same command and exits 0 too.
- Object: the same flags with `-wmo -O -module-name AuthenticationServices -c`. A Mach-O `arm_v7`
  object of 64204 bytes with 318 defined global symbols (`llvm-nm -g --defined-only`).

## Not measured

- The object was not linked and not run on an armv7 image, the emulator or a 4S.
- The device's `Code` shape (see above).
- Whether the swift-runtime recipe builds this file. It is not wired into `xmake.lua` yet: the
  runtime install is blocked on the lift's measured set, and wiring the file changes the runtime
  digest. It is built and typechecked standalone meanwhile, as the brief asks.
- The host's error text and `localizedDescription` for each code. Only the domain, codes and user
  info were compared.
