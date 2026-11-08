# CIImage orientation by CGImagePropertyOrientation on iOS 6

`-[CIImage imageByApplyingCGOrientation:]` (Swift `oriented(_:)`) and `-[CIImage imageTransformForCGOrientation:]` (Swift
`orientationTransform(for:)`) are iOS 11 members. The iOS 6.0 CoreImage has neither.

Measured in the iOS 6.0 shared cache (`.cache/dyld/6.0/classes_armv7.json`): `CIImage` has `imageByApplyingOrientation:`
and `imageTransformForOrientation:`, the EXIF-number forms that the SDK marks iOS 8.0 (Swift `oriented(forExifOrientation:)`
and `orientationTransform(forExifOrientation:)`). They are device members: `device-members.txt` lists them, because
`apple.lowered` reads the old availability macro `NS_AVAILABLE(10_10, 8_0)` as well as `API_AVAILABLE`. The backport does not
replace them.

The backport (`frameworks/Backports/src/Graphics/CIImageCGOrientation11.m`) adds the two missing selectors and forwards each
to the EXIF form with the same number. `CGImagePropertyOrientation` and the EXIF orientation are the same numbers, 1 to 8.

## Checked

- `frameworks/Backports/tests/CoreImage/orientation_test.m` (host, `CoreImageBackports_orientation_test`) checks on a system
  that has both forms that they agree for every number from -1 to 9 on three extents, that an image of infinite extent keeps
  the identity transform in both, and that the right orientation swaps the sides. Its `--negative` run fails.
- `frameworks/Backports/tests/lowering_test.lua` compiles calls of all four selectors at armv7 iOS 6.0 with
  `-Werror=unguarded-availability`.
- The Swift lines of Telegram that call `oriented(_:)` and `oriented(forExifOrientation:)` typecheck against the lowered SDK.

Not measured on a device: that iOS 6's EXIF forms give the transforms the host's give. The forwarding rests on that
agreement, which the host test shows for the system it runs on.
