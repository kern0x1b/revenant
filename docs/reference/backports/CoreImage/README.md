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
  a device that is not the backport's, and keep the options on the context. The command-queue forms use the queue's device.
  `render:toMTLTexture:commandBuffer:bounds:colorSpace:` draws into the texture without a copy through memory: it makes the device's GL context current, binds the
  framebuffer of the texture, clears the part of the texture the bounds cover to transparent (`drawImage:` blends over what is there, a Metal render replaces it),
  and calls `drawImage:inRect:fromRect:` of a context for the call's colour space. The framebuffer binding, viewport, scissor, clear colour and colour mask of the
  GL context are restored afterwards. The texture's row 0 is the bottom row of the image (the convention of a default, non-flipped Metal destination as
  CoreImage uses it), which is the orientation `drawImage:` gives, so there is no flip. The colour space of a call cannot be given to `drawImage:`, which uses the
  output colour space of its context, so the first call with a colour space makes a context of the same EAGL context and the options of the first one with that
  output colour space, and keeps it; a call with no colour space uses the working colour space of the context as the output (nothing to convert), or none when
  the working colour space is `NSNull`. Texture formats are BGRA8, RGBA8 and RGBA16F; another format, an image of null or infinite bounds, a texture of a
  type other than 2D, and RGBA32F draw nothing (see Gaps).
- `CIImageMetalTexture9.m`: `imageWithMTLTexture:options:` and `initWithMTLTexture:options:` wrap the texture's GL name with `initWithTexture:size:flipped:colorSpace:`
  (`flipped:NO`, the colour space from `kCIImageColorSpace`, where `NSNull` means none). Only a 2D texture of the backport in BGRA8 or RGBA8 gives an image;
  any other gives nil. `metalTexture` returns the texture for an image made with no options and nil for any other image.
- `render:toCVPixelBuffer:` is CoreImage's own and needed no work; the probe checks that it takes an image of a texture.

Gaps (C54): one render still goes through memory and one format draws nothing. (1) With no colour space in the call and CoreImage's default working colour
space (the context made without `kCIContextWorkingColorSpace`), `drawImage:` cannot give the working-space values that `render:toBitmap:colorSpace:NULL`
gives: a context with `kCIContextOutputColorSpace` set to `NSNull` converts to device RGB like one with the default, and iOS 6 has no
`kCGColorSpaceGenericRGBLinear` to name the default working space; that call keeps the old route, `render:toBitmap:` and `replaceRegion:`. (2) RGBA32F: the GPU
has no framebuffer for the texture (`glCheckFramebufferStatus` 0x8cdd) and iOS 6.1.3 does not export `kCIFormatRGBAf`, so the call draws nothing; the code
before this change read the missing constant and crashed (measured, a segmentation fault in the probe). (3) The `commandBuffer` argument is not used: the backport's
encoders and this draw both issue GL commands at once on the same context, so a render is ordered with the passes encoded before and after it. (4) The first
call with a colour space makes a `CIContext`; the time of that call was not measured.

Checked on the iPhone 4S (iOS 6.1.3, 2026-11-09), `frameworks/Backports/tests/device_probe/ci_metal_main.m` (target `CIMetalProbe`), 19 of 19 (the `--negative` run fails 17): a context for the
device with and without options; the size of an image of a texture; `metalTexture` for an image made with and without options; the first texture row is the
bottom row of the image; rendering an image of a texture into a texture gives the same rows back; bounds that pick a 2 by 2 part to the texture's origin; BGRA channel
order; a pixel buffer rendered from the image holds the top row first; the values equal CoreImage's own render through memory (largest difference 0 on a
256-level ramp) for each of three working colour spaces (none, generic RGB, default) with each of three colour spaces in the call (none, device RGB, generic RGB), and under
the default working space the colour space of the call changes the values by more than 8 (so the comparison can tell them apart); a render replaces a texture that held 0x77 with translucent
pixels and a transparent margin as the memory route does; a render raises no GL error and restores the framebuffer, viewport, scissor box and enable, clear colour and colour mask; the
filter and wrap parameters of the texture that is read do not change; a half-float texture receives the image; a context made for the software renderer renders the same
rows; a render into a full-float texture returns with no GL error; a texture of an unsupported format gives no image.

Timing on the A5 (same probe, a noise texture scaled by 0.9, the mean of 10 renders, the GPU finished with `glFinish` before the clock stops): 512 by 384 took 8.9 ms
through memory and 1.8 ms drawn; 1024 by 768 took 27.3 ms and 5.7 ms. The memory route, kept for the one case above, still costs that.

Not measured: that a Metal pass of the backport that reads the texture after such a render sees the values the render wrote (the probe reads the texture back with `getBytes:`, which reads the
same framebuffer); MediaEditor's own frames.

Found while measuring, not caused by this change: a Metal texture of 4 by 2 or 8 by 2 texels does not give back what `replaceRegion:` wrote when read with `getBytes:`,
while 4 by 4 and 2 by 2 do. The probe uses 4 by 4 and 2 by 2. The cause is in the texture backport or the driver and is not investigated here.
