# CKRecord, not yet visible to Swift on armv7 / iOS 6.1.3

What blocks the three `CKError` record properties (`serverRecord`, `clientRecord`, `ancestorRecord`,
type `CloudKit.CKRecord`) and the CKRecord group, measured on 2026-10-17 from the
`v-impl-swift-apps-r3` worktree (fast-forwarded to `origin/main` `0ac862031b`).

## The probe

The probe, run as a scratch program:

    import CloudKit
    let r = CKRecord(recordType: "Note")
    r["title"] = "hello" as NSString
    print(r.recordType, r.recordID.recordName.count > 0)

## Generator port headers, iOS 16.4 SDK

The headers are `headers16/port/6.1.3/` (the generator's `headers` command with `--sdk 16.4`). The
module map is there: `Frameworks/CloudKit.framework/Modules/module.modulemap` declares
`framework module CloudKit` with the umbrella header `CloudKit.h` and every header of the framework.
So the module exists and imports.

Typecheck on armv7, with the vfs of those headers and the run folder's resource directory:

    swiftc -target armv7-apple-ios6.1.3 -sdk iPhoneOS16.4.sdk -resource-dir <farm> \
      -vfsoverlay headers16/port/6.1.3/vfs.yaml -typecheck probe.swift

exits 1 with:

    Frameworks/CloudKit.framework/Headers/CKRecord.h:4:9: error: '_LocationEssentials/CLLocationEssentials.h' file not found
    probe.swift:1:8: error: could not build Objective-C module 'CloudKit'

## The cause

`CKRecord.h` in the iOS 16.4 SDK's own CloudKit framework is line 4:

    #import <_LocationEssentials/CLLocationEssentials.h>

The 16.4 SDK has no `CLLocationEssentials.h` anywhere (a `find` over the whole SDK finds nothing, and no
`_LocationEssentials` framework or directory exists in it). So the import dangles in the SDK's own
header, not in the generator's copy.

The iOS 26.2 SDK does ship `System/Library/Frameworks/_LocationEssentials.framework/Headers/CLLocationEssentials.h`,
and its `CloudKit.framework/Headers/CKRecord.h` has no such import at all. A diff of the two
`CKRecord.h` files shows the 16.4 copy is an older declaration set (no `CKRecordRecordIDKey` and
its siblings, and `@property (nonatomic, readonly, ...)` where 26.2 has `@property (readonly, ...)`).

## What this means for the group

- The module map is correct: it is the generator's output, and nothing in it needs a workaround.
- The dangling import is in the SDK header the generator copies. Options, none taken here:
  1. The 26.2 SDK's CloudKit headers as the port's CloudKit headers. A probe against them earlier
     resolved the module, but the 16.4 SDK's own swiftinterface and headers still produced
     availability errors (`initWithRecordType` unavailable, `8.0` marks), so this is a mixed set.
  2. The generator drops a header import the SDK does not resolve. This is a change to the generator's
     header copy, which the coordinator has ruled out as a workaround; it needs a ruling.
  3. Build the CKRecord group against the 26.2 SDK's headers end to end, for a runtime whose release is
     26.2. Changes the runtime's SDK.

## Not measured

- An object, a link, or a run of the CKRecord probe on armv7 or the emulator.
- Whether the 26.2 headers with the 16.4 compiler resource directory give a clean typecheck.
