# AVMetadataMachineReadableCodeObject, iOS 7

Rank 6 of `coordination/corpus/crash-demand-top.tsv`, `LOAD-FAIL` for `telegram` and `provenance`:
a hard, non-weak reference to this class name kills the application at launch, not merely on
first use - the highest-ranked genuine gap in this pass's domain filter after `CAFrameRateRange`
(rank 121/123, `facts/QuartzCore/CAFrameRateRange.md`).

## What was checked before writing code

`AVMetadataObject`, this class's real superclass, is already on iOS 6.1.3 - confirmed with
`apple.objc.inventory()` against the armv7 shared cache, not assumed from the class's age.
`AVMetadataFaceObject`, a sibling subclass, ships with the release's own face detection, so the
base class is exercised and real, not a stub. No name already claims
`AVMetadataMachineReadableCodeObject` under a different meaning on this release (`inventory()`
answered absent, cleanly, the same check that found `AVAudioBuffer` and `PassKit` already claimed
under different meanings elsewhere this pass). `grep` across `packages/a/apple-backports/AVFoundation/*.m`
found no existing implementation already carrying this selector under a different registry entry.

## What the port does

An ordinary Objective-C subclass of the release's real `AVMetadataObject`, not a bridge over a
private class - the two-step check above is what makes that safe. `-stringValue` and `-corners`
are the port's own stored properties, set through a `-initWithStringValue:corners:` initializer
this port defines (not Apple's - `AVMetadataObject`'s header marks `-init`
`NS_UNAVAILABLE`, a compile-time steer toward Apple's own capture-pipeline factory that is not a
runtime restriction; a plain `objc_msgSend` reaches the real `-init` this subclass still needs).

## What this does not close

`AVCaptureMetadataOutput`, the class that would produce one of these from a live camera feed by
scanning for QR/barcode content, does not exist on this release and is not part of this row -
carrying it is separate, larger work. What this row closes is the `LOAD-FAIL`: any code path that
names `AVMetadataMachineReadableCodeObject` at compile time - an `isKindOfClass:` check after a
delegate callback that will never fire, an import, a category - no longer kills the process at
launch for referencing a symbol that was not there. An application waiting for one of these from
a real scan will wait forever, honestly, the same way it would on the 4S's camera without the
class existing at all - not crash, not fabricate a result.
