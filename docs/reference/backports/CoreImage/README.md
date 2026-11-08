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

# CIColor named colours and the Metal bridge of CIContext and CIImage on iOS 6

Telegram's MediaEditor uses `CIColor.clear`, `CIColor.black`, `CIColor.white` (iOS 10), `CIContext(mtlDevice:options:)` (iOS 9) and, in its
renderer, `CIImage(mtlTexture:options:)` and `render(_:to:commandBuffer:bounds:colorSpace:)` (iOS 9). Each is implemented, not guarded.

## CIColor

`frameworks/Backports/src/Graphics/CIColor10.m` defines the class methods `blackColor`, `whiteColor`, `grayColor`, `redColor`, `greenColor`, `blueColor`,
`cyanColor`, `magentaColor`, `yellowColor` and `clearColor` (Swift `CIColor.black` and the others), the colour-space initialisers and factories of iOS 10
(`init(red:green:blue:colorSpace:)`, `init(red:green:blue:alpha:colorSpace:)` and `CIColor(red:green:blue:colorSpace:)` forms) and
`initWithRed:green:blue:`. A colour is built from a `CGColor` in the given colour space, or in device RGB when the space is `NULL`; each named colour is
made once. Gray is 0.5 in each channel and clear is 0 in every channel including alpha.

Checked on the host: `frameworks/Backports/tests/CoreImage/color_test.m` (11 checks, `--negative` mode fails): the components and alpha of every named
colour and of a colour made with a colour space. Not run on a device.

## The Metal bridge

On iOS 6 a Metal device is `RevenantMetalDevice`, which owns an `EAGLContext` (`docs/explanation/backports/metal-on-ios6.md`), and a Metal texture is a
`RevenantMetalTexture` with a GL texture name. CoreImage on iOS 6 has `+[CIContext contextWithEAGLContext:options:]`, `-[CIImage initWithTexture:size:flipped:colorSpace:]`
and `-[CIContext render:toBitmap:rowBytes:bounds:format:colorSpace:]`; the backport maps the iOS 9 Metal calls onto them.

- `CIContextMetal9.m`: `contextWithMTLDevice:` and `contextWithMTLDevice:options:` return `contextWithEAGLContext:options:` of the device's context, or nil for
  a device that is not the backport's. The command-queue forms use the queue's device. `render:toMTLTexture:commandBuffer:bounds:colorSpace:` renders the
  bounds to a bitmap with `render:toBitmap:` and writes the bitmap into the texture with `replaceRegion:`. The texture's row 0 is the bottom row of the image
  (the convention of a default, non-flipped Metal destination as CoreImage uses it), so the image is flipped vertically before it is read back. Texture formats
  are BGRA8, RGBA8, RGBA16F and RGBA32F; another format, an image of null or infinite bounds, or a texture of a type other than 2D draws nothing.
- `CIImageMetalTexture9.m`: `imageWithMTLTexture:options:` and `initWithMTLTexture:options:` wrap the texture's GL name with `initWithTexture:size:flipped:colorSpace:`
  (`flipped:NO`, the colour space from `kCIImageColorSpace`, where `NSNull` means none). Only a 2D texture of the backport in BGRA8 or RGBA8 gives an image;
  any other gives nil. `metalTexture` returns the texture for an image made with no options and nil for any other image.
- `render:toCVPixelBuffer:` is CoreImage's own and needed no work; the probe checks that it takes an image of a texture.

Gaps (C54): the render goes through the CPU. CoreImage renders the bounds into a bitmap in memory and the bitmap is copied into the texture, once per call, and the `commandBuffer` argument is
ignored, so the work is complete when the call returns and a later `commit` waits for nothing. The probe passes `NSNull` for `kCIContextWorkingColorSpace` and
`kCIContextOutputColorSpace` and for `kCIImageColorSpace`, so that the values compare exactly; what the default colour management does to the values of a
bridged render was not measured.

Checked on the iPhone 4S (iOS 6.1.3, 2026-11-08), `frameworks/Backports/tests/device_probe/ci_metal_main.m` (target `CIMetalProbe`), 11 of 11:
a context for the device with and without options; the size of an image of a texture; `metalTexture` for an image made with and without options; the first
texture row is the bottom row of the image; rendering an image of a texture into a texture gives the same rows back; bounds that pick a 2 by 2 part to the
texture's origin; BGRA channel order; a pixel buffer rendered from the image holds the top row first; a texture of an unsupported format gives no image.

Found while measuring, not caused by this change: a Metal texture of 4 by 2 or 8 by 2 texels does not give back what `replaceRegion:` wrote when read with `getBytes:`,
while 4 by 4 and 2 by 2 do. The probe uses 4 by 4 and 2 by 2. The cause is in the texture backport or the driver and is not investigated here.

Not measured: the time of one render of a full-size frame on the A5; MediaEditor's own frames through the bridge.
