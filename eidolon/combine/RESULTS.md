# OpenCombine 0.14.0+ (1c6f02c) on armv7 iOS 6.1.3 — test results

Build: `combine/build.sh ios` (Swift 6.4 charon@swift, -target armv7-apple-ios7.0, runtime of the Swift session, overlays 5.4.3 ported),
`combine/stage-ios.sh` (link at iOS 6.0, @executable_path), import check `check.lua` against 6.0 and 6.1.3: 0 strong missing.
Tests: upstream Tests/OpenCombineTests with `combine/xctest` (XCTest API shim), list generated from the symbol graph (`gentests.py`).
URLSessionTests.swift excluded (subclasses NSURLSession, iOS 7).

| where | tests | passed | failed | crashed |
|---|---|---|---|---|
| macOS 27 arm64 host (CLT swiftc 6.4) | 1469 | 1464 | 5 | 0 |
| iLEmu iPhone4,1 iOS 6.1.3, old study runtime (runs.noindex/ocl1..15) | 1453 | 1437 | 1 | 15 |
| iLEmu iPhone4,1 iOS 6.1.3, **charon@swift-runtime 9c2013** (`build.sh pkg`, `stage-pkg.sh`, runs.noindex/ocp1..4) | 1453 | 1448 | 1 | 3 (+1 skipped: QoS, iOS 8) |

Host failures: DispatchQueueSchedulerTests x4 (assume mach timebase 1/1; Apple silicon is 125/3), MapKeyPathTests.testMapKeyPathReflection (reflection text of newer Swift).
iOS failure: MapKeyPathTests.testMapKeyPathReflection (same as host).

iOS crashes (each skipped and resumed by `combine/emu-loop.sh`):
- DispatchQueueSchedulerTests x7 (SchedulerTimeType*, StrideFrom*): trap in `SchedulerTimeType.Stride.magnitude.getter` = `Int(_nanoseconds: Int64)`; the public API (same as Apple Combine) returns Int, 32 bits on armv7. 64-bit assumption of the API, not of the runtime.
- DispatchQueueSchedulerTests.testScheduleActionOnceNow: fault inside libdispatch from overlay `DispatchQueue.async(group:qos:flags:execute:)` (QoS, iOS 8 API).
- PrintTests.testSynchronization: fault inside libdispatch from overlay `DispatchQueue.concurrentPerform` (`__swift_dispatch_apply_current`).
- RecordTests.testRecordDecode: trap in overlay `Dictionary._conditionallyBridgeFromObjectiveC` → `_NativeDictionary.init(_unsafeUninitializedCapacity:allowingDuplicates:)` (JSON decode path). Not analysed.
- RunLoopSchedulerTests x2, TimerPublisherTests x3: `Timer.tolerance` → weak `CFRunLoopTimerSetTolerance` (iOS 7) is NULL on iOS 6; crash at first call.

## On charon@swift-runtime (19.09.2026)

Build: `combine/build.sh pkg` against the charon@swift-runtime 6.4.0 installation (charon main 70c716c,
mark 9c2013b4…) in `../xmake-global`, target `armv7-apple-ios6.0` with `-bundled-swift-runtime`, **availability
checking on** for the libraries. That check found what the old build hid: OpenCombineFoundation's `URLSession`
publishers (iOS 7) — dropped from the iOS 6 variant — and the timer tolerance calls (iOS 7) — now behind
`#available`. Tests compile with the check off (they are not shipped); the runner now flushes each status line,
so a crash is attributed to the test that was running. Stage: `stage-pkg.sh` (@executable_path install names).

Result: 1448 passed, 1 failed (MapKeyPathTests.testMapKeyPathReflection — reflection text of newer Swift, fails on
the macOS host too), 3 crashed, 1 skipped up front:
- DispatchQueueSchedulerTests.testStrideFromDispatchTimeInterval, testStrideFromNumericValue — the 32-bit
  `Stride.magnitude` (`Int(_nanoseconds: Int64)`) of the public API, as before;
- RecordTests.testRecordDecode — JSON decode through overlay dictionary bridging, as before;
- skipped: DispatchQueueSchedulerTests.testScheduleActionOnceNow — QoS is an iOS 8 API.

Compared with the old runtime, 12 crashes are gone: the SchedulerTimeType tests, `concurrentPerform`
(PrintTests.testSynchronization), and the RunLoop/Timer tests that called the iOS 7 tolerance setter.
