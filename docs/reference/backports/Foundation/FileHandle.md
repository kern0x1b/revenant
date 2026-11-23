# FileHandle: the Swift API of iOS 13 on iOS 6

The Swift runtime's `Foundation` overlay does not include the upstream `FileHandle.swift`, so Swift code compiled for iOS 6
sees only the Objective-C members the SDK headers declare. The later Swift surface is carried by two files:

| Layer | File | What it does |
| --- | --- | --- |
| Objective-C | `frameworks/Backports/src/Foundation/NSFileHandle+Errors13.m` | the iOS 13 refined members over the iOS 6 descriptor calls, with `NSFileHandleOperationException` translated to `NSError` |
| Swift | `toolchain/src/swift-runtime/overlay/Foundation/FileHandle.swift` | `readToEnd()`, `read(upToCount:)`, `write(contentsOf:)`, `offset()`, `seekToEnd()`, `seek(toOffset:)`, `truncate(atOffset:)`, `synchronize()` and `close()`, with the null device's no-op results |
| Adapter | `toolchain/src/swift-runtime/overlay/Foundation/RevenantFileHandleShims.h` | a Clang shim that lets the Swift overlay call the refined Objective-C members, including the four that Swift imports without a `__` name |

`read(upToCount:)` returns nil when no byte was read, as Apple's implementation does; an empty read at the end of a regular
file is the empty `NSData` the Objective-C layer returns. `write(contentsOf:)` writes every `DataProtocol` region through the
same refined write. Errors are the `NSError`s of the Objective-C layer; the `@nonobjc` extension members do not replace the
Objective-C selectors, so Objective-C callers keep the old dispatch. `synchronize()` ignores `EINVAL` and `EROFS`, as Apple's
implementation does for special files and read-only volumes: `swift-corelibs-foundation`,
`Sources/Foundation/FileHandle.swift`, lines 632–639 (`if errno == EINVAL || errno == EROFS { return }`),
<https://github.com/swiftlang/swift-corelibs-foundation/blob/main/Sources/Foundation/FileHandle.swift#L632-L639>.
`ENOTSUP` is not suppressed there, and is not suppressed here either. The runtime app case
`frameworks/Backports/tests/runtime/cases/foundation_file_handle.m` exercises the Objective-C layer for armv7 on iOS 6.1.3;
`frameworks/Backports/tests/availability/file_handle.swift` typechecks the Swift surface at an iOS 6 deployment target.
