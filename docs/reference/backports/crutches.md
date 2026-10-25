# Crutches: the stand-ins of the Backports lowering

Work that stands in for the native behaviour, with the measurement that shows what it does and the limit that would
remove it. The entries describe the Backports lowering on the branch `work/telegram-backports`. An open entry is one
whose removal has not landed. A removed entry stays below, with the commit that removed it.

## Open

### C2. Armv7 iOS 6.0 proof is a typecheck with a known reproduction gap

- Stands in for: a full CI compile of the Foundation overlay. The local proof typechecks the overlay sources with the same compiler, target, stdlib and patched shims as CI; it does not run IR generation or emit objects.
- Gaps: `NSValue.swift` and `CGFloat.swift` are gyb templates that were not expanded; the `ObjectiveC`, `CoreFoundation`, `CoreGraphics` and `Dispatch` swiftmodules come from release `prebuilt-swift-runtime-b3c2a6ae…`.
- Measurement: the same reproduction reproduced CI's `Measurement.swift:23:15` errors before the fix, and reports zero errors after.
- Removed by: the CI full build of the head (the `swift-runtime` prebuild and its check).

### C3. Extension guard cleared for every member of the extension

- Stands in for: a per-operator lowering. The Equatable and Comparable requirements of `Measurement` are witnessed by operators inside `extension Measurement {`, whose guard covers the operators too.
- Widens: every other member of that extension reaches the iOS 6.0 floor.
- Measurement: the armv7 iOS 6.0 typecheck compiles those members with CI's compiler. Nothing has been run on an iOS 6 device.
- Removed by: a device run of the `Measurement` members on iOS 6.

### C4. Non-public and type-level guards cleared by rule

- Stands in for: naming each declaration. The lowering clears the guard of an implemented struct, class or enum, of non-public members of an implemented type, and of file-scope internal functions.
- Widens: these declarations reach the iOS 6.0 floor.
- Measurement: the armv7 iOS 6.0 typecheck compiles them with CI's compiler. Their bodies have not been run on an iOS 6 device.
- Removed by: a device run.

### C6. Reduced check for the two weak classes in the lowering test

- Stands in for: a compile-time check of the members of `NSDateInterval` and `NSURLComponents`. Both classes keep their class-level guard by design (the guard table records them as weak imports), so the IMPLEMENTED probe refers to them through `id` receivers.
- Measurement: the rest of the probe still checks typed receivers and the lowered headers at armv7 iOS 6.0.
- Removed by: the export dependency for these classes (the Backports library that exports them, linked into the runtime); the probe then returns to typed receivers.

### C7. Export dependency for weak classes and UIFocusSystem: pending

- The runtime's UIKit overlay imports `_OBJC_CLASS_$_UIFocusSystem` weakly (guard table, `UIKit.swift:398`); Telegram's `UIKitRuntimeUtils` needs the class unguarded.
- Removal: the runtime links the Backports UIKit library that exports the class, so the load check's exports include it. Pending implementation.

### C8. Vision requests beyond iOS 6 image-analysis engines

- Stands in for: `VNDetectRectanglesRequest`, `VNRecognizeTextRequest`, `VNClassifyImageRequest`, `VNGeneratePersonSegmentationRequest`, `VNGenerateForegroundInstanceMaskRequest`, and the barcode symbologies other than QR and PDF417.
- Why: iOS 6 Core Image has face detection, but no rectangle, OCR, built-in image-classification, or subject-segmentation engine. Barcode requests use zxing-cpp for QR and PDF417 because Telegram needs them for QR login and passport scanning; the other symbologies are not implemented.
- Behavior: unsupported requests and unsupported requested barcode symbologies complete with `VNErrorUnsupportedRequest` in `VNErrorDomain`.
- Measurement: generated QR and PDF417 fixtures test decoded payloads, symbology, normalized bounds, and corner coordinates. No broad accuracy comparison against Apple's Vision has been run.
- Removed by: an iOS 6 implementation measured against the corresponding Vision requests, or a source change that no longer requires those requests.

## Removed

### C1. Member list generated from a stand-in SDK install

- Was: the member and device lists were generated from the `iphoneos-sdk 26.2` install `…/14632581444d4c67a8eee6a6172f4e0a` through `REVENANT_GEN_SDK`, while CI resolves `…/d322b52c69944e4a9c3f3d2a883a9259`.
- Measurement that removed it: with the same code, the two installs give identical member and device lists (0 changed lines). The 26 lines that differed came from a stale committed list after the deprecation rule changed, not from the installs.
- Removed in: `77cf0704e` (list regenerated from `d322…`, the package CI resolves).

### C5. Device check skipped on CI

- Was: `device_members_test` skipped on CI, because the checks job did not restore the iOS 6.0 armv7 shared cache that holds the inventory.
- Removed in: `e01213a11` (the checks job restores the cache with the key the other jobs use, fetches it on a miss, and asserts the inventory is in place), and `75413488d` (the cache restore lacks `classes_armv7.json`, so the job writes it with the firmware `classes` action when absent).
