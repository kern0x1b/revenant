# CKError, measured

What `files/CloudKit/CKError.swift` carries, what it was checked against, and where it differs from
the host. Every number here was produced by the commands named in it, on 2026-10-16, from the
`v-impl-swift-apps` worktree of the toolchain.

## What is carried

The spec rows are `the deleted registry package spec/CloudKit/swift.tsv`, the CKError and CKError.Code
containers (88 rows: 47 for CKError, 41 for CKError.Code).

| Rows | Carried | Not carried |
| --- | --- | --- |
| CKError struct, `_nsError`, `init(_nsError:)`, `errorDomain`, `partialErrorsByItemID`, `retryAfterSeconds` | all | - |
| CKError static constants, one per code (37) | all | - |
| CKError.Code enum, its 37 cases, `rawValue`, `init(rawValue:)`, `RawValue`, `_ErrorType` | all | - |
| CKError `serverRecord`, `clientRecord`, `ancestorRecord` | - | 3 rows: their type is `CloudKit.CKRecord`, the class the CloudKit backports carry as Objective-C. A Swift module reaches it through the lifted headers, which is the CKRecord group of this band, not this file. |

85 of 88 rows are in the file. Nothing here is built into `libswiftCore` or the runtime yet: the
recipe does not name `files/CloudKit`, so the runtime digest is unchanged and no port links it.

## Constants

- Raw values: the `enumconst` rows of `the deleted registry package spec/CloudKit/declarations.tsv`
  (CKErrorCode, 37 values, 1 to 37). The file's cases are these values, paired by name with the
  swift.tsv rows (37 of 37 pair, none missing).
- Domain and keys: `CKErrorDomain`, `CKPartialErrorsByItemIDKey` = "CKPartialErrors",
  `CKErrorRetryAfterKey` = "CKRetryAfter". Revenant's backports define the same three strings
  (`frameworks/Backports/src/CloudKit/CKConstants8.m`), and the host reads the same values (below).

## Measured against the host

The oracle is the macOS host's CloudKit, the only one in this workspace that answers. The probe is
`harness/CloudKit/main.swift`, built twice: `swiftc -O main.swift` against the host's CloudKit, and
`swiftc -DOURS -O main.swift files/CloudKit/CKError.swift` against the file. The host is macOS 27
(Swift 6.4, Xcode CLT), not iOS 26.2, so these are behaviour facts about the host, not about the
device.

| Probe | Result |
| --- | --- |
| Domain, the three key strings | identical on both (`CKErrorDomain`, `CKPartialErrors`, `CKRetryAfter`) |
| User info read back: per-item errors (count and keys), retry interval, missing user info | identical |
| Wrapping an NSError of a foreign domain | host: constructs, no trap. The file as first written trapped (exit 133, `precondition`); the precondition was removed to match the host |
| `CKError.Code` conforms to `_ErrorCodeProtocol` | true on both |
| `CKError.Code` is an `Error` | false on the host, so the file does not conform either (the probe had asserted it; the compiler refused on both sides) |

### The one divergence: the shape of `CKError.Code`

On the host, `CKError.Code` is not a Swift enum. `Code(rawValue: n)` is not failable (it returns a
value for every `n`, -1 and 38 and 39 included), and its description is `CKErrorCode(rawValue: 11)`.
The file, following the 26.2 spec row `swift-enum Code`, is a failable enum whose description is the
case name (`unknownItem`).

- 43 lines of the 89 the probe prints differ, all of them in these two shapes: 41 `code n` lines and
  the two lines that print `Code` values (`wrapped.code`, `partial.code`). The other lines match.
- Which one a device shows is not measured here: the iOS 26.2 SDK is not on the host to ask, and
  the spec says enum. The spec is the target, so the file follows it.
- Measured reason it is not hidden: the probe prints all 43 lines, so a change in either side shows.
  If the host's shape and the spec ever agree, the differing count drops to 0, and the probe's
  output is the thing to re-read.

## armv7 typecheck

`swiftc -target armv7-apple-ios6.1.3 -sdk iPhoneOS16.4.sdk -resource-dir <swift-runtime 1b938f...>/lib/swift
-vfsoverlay <swift-runtime 1b938f...>/share/lift/vfs.yaml -parse-as-library -typecheck files/CloudKit/CKError.swift`
exits 0 with no diagnostics. The runtime is the installed `backports = true` variant (SDK 16.4, lifted
headers). This is a typecheck only: no object was written and nothing was run on an armv7 image.

## Not measured

- An armv7 object, a link, a run on the emulator or the 4S. None of it has been done.
- The three record properties. They need the CKRecord class in a Swift module.
- Whether the runtime's build (`swift-runtime` recipe) accepts `files/CloudKit`. It is not wired
  in, because wiring it changes the runtime digest and would rebuild the runtime, which is a
  separate measured step.
