# Metal linear texture alignment on iOS 6

`-[MTLDevice minimumLinearTextureAlignmentForPixelFormat:]` is the iOS 11 query for the alignment that `offset` and
`bytesPerRow` must have when a texture is made over a buffer. Swift sees it as `minimumLinearTextureAlignment(for:)`.
Telegram's `DrawingMetalView.swift` rounds its row size up to this alignment, and the build failed there because the SDK
marks the member iOS 11.0 or newer. The device (`frameworks/Backports/src/Metal/MTLDevice11.m`) now implements it, and
`frameworks/Backports/tools/lowered-members.txt` lists it as a protocol member of `MTLDevice`, so the lowered SDK no
longer carries the availability and Telegram compiles unpatched.

## What it returns

The size in bytes of one texel of the pixel format, from the device's own format table (`RevenantMetalTexelBytes` in
`frameworks/Backports/src/Metal/RevenantMetalTexture.m`, the table `getBytes` and `replaceRegion` use):

| Pixel format | Bytes |
| --- | --- |
| R8Unorm | 1 |
| RG8Unorm, R16Float | 2 |
| RGBA8Unorm, BGRA8Unorm, RG16Float, R32Float | 4 |
| RGBA16Float | 8 |
| RGBA32Float | 16 |

Every value is a power of two, which Telegram's `alignUp` requires. A pixel format the device cannot make a texture of
(none, depth, stencil, compressed) raises `NSInvalidArgumentException`, which is what the SDK's documentation says an
invalid format does.

Why the texel size and no more (reasoned, not measured as a limit): the textures of this device are OpenGL ES 2.0
textures, not linear memory. Rows go in with `glTexSubImage2D` at `GL_UNPACK_ALIGNMENT` 1 and come out with
`glReadPixels` at `GL_PACK_ALIGNMENT` 1, so a row may start at any byte offset, and ES 2.0 has no query that reports a
larger row alignment. The texel size is the smallest alignment that keeps every texel whole. For `bgra8Unorm`, the format
Telegram asks about, the alignment is 4, so `alignUp(width * 4, 4)` is `width * 4` and Telegram's rows are tight.

## A latent readback bug the probe found

The probe round-trips BGRA rows at widths 1 to 1001 through `replaceRegion` and `getBytes` at row strides of the
device alignment, 16, 64 and 256 bytes and compares them byte for byte.

- Before the fix, on the iPhone 4S (iOS 6.1.3): 3 of 18 checks failed. The padded strides (16, 64, 256) came back with
  red and blue swapped, starting at width 1. The tight stride (width times 4, the device alignment) was exact.
- Cause: `revenantReadRegion:` read tight rows in the texture's own format (`GL_BGRA_EXT` for BGRA8Unorm) but read padded
  rows as `GL_RGBA` into a scratch buffer and copied them out as they were. The upload path already used the texture's
  own format for both.
- After the fix, the same checks on the same phone passed. Padded rows are read in the texture's own format too, and a
  four-channel row is copied whole instead of texel by texel.

## The slice forms of `getBytes` and `replaceRegion`

Telegram's `Texture.createCGImage` (`DrawingMetalView.swift`), `MetalImageView` and `AnimationCompressor` call
`getBytes(_:bytesPerRow:bytesPerImage:from:mipmapLevel:slice:)`. The device implemented only the four-argument
`getBytes:bytesPerRow:fromRegion:mipmapLevel:`, which the SDK documents as the convenience for the slice form. The slice
form carries no availability of its own in the SDK, so the compiler never complained, and a call to it would have found no
selector at run time (reasoned from the source and `lowered-members.txt`, not run before the fix).

`RevenantMetalTexture` now implements `getBytes:bytesPerRow:bytesPerImage:fromRegion:mipmapLevel:slice:` and
`replaceRegion:mipmapLevel:slice:withBytes:bytesPerRow:bytesPerImage:`. A texture of this device is one 2D image, so the
slice must be 0 and the region's depth 1; anything else is refused with a log line and touches no bytes. `bytesPerImage` is
not used: a 2D texture has one image per slice, and Telegram passes the whole image size there.

## Cost of padded rows (measured on the iPhone 4S, 1001 by 1001 BGRA8Unorm)

| | Tight stride 4004 | Padded stride 4096 |
| --- | --- | --- |
| `replaceRegion` | 6.4 ms | 9.0 ms |
| `getBytes`, before the fix | 12.6 ms | 62.1 ms |
| `getBytes`, after the fix | 12.1 ms | 26.3 ms |

The after row is the last of two runs (the other measured 28.0 ms for the padded readback). The padded path stays slower:
ES 2.0 has no `GL_PACK_ROW_LENGTH`, so a padded readback goes through a scratch buffer and one copy per row, and an upload
makes one `glTexSubImage2D` call per row.

## Checked

- `frameworks/Backports/tests/device_probe/linear_main.m` (target `MetalLinearProbe`, run on the iPhone 4S): 21 checks of
  the alignment of nine pixel formats, the exception for four invalid ones, the four stride round trips, and the slice
  forms (slice 0 round trip, slices 1 refused for read and write). All 21 passed. Its `--negative` run reports 1 passing
  check and 20 failing ones; the passing one only asks for a device.
- `frameworks/Backports/tests/metal_lowering/main.swift`, run by `metal_lowering_test.lua`: Telegram's `alignUp` and a
  row size taken from `minimumLinearTextureAlignment(for: .bgra8Unorm)` typecheck at armv7 iOS 6.0 against the lowered SDK.
  Without the line in `lowered-members.txt` the same test fails with Telegram's error, `'minimumLinearTextureAlignment(for:)'
  is only available in iOS 11.0 or newer`.
- The ObjC acceptance probe of `lowering_test.lua` calls the member on an `id<MTLDevice>`.

## Not covered

- A texture made over a buffer (`newTextureWithDescriptor:offset:bytesPerRow:` on an `MTLBuffer`) is still refused with a
  log line and `nil`. The buffer's bytes are plain memory and ES 2.0 cannot map them as texture storage, so the alignment
  describes a texture this device cannot make. Code that asks for the alignment and then makes such a texture gets `nil`.
- `getBytes` still reads 8-bit channels only; half and full float formats are refused with a log line, as before.
- A sweep of the other Metal members the Telegram sources call, against what the device implements, found only the slice
  forms missing among the members `DrawingMetalView.swift` uses (its calls on devices, textures, queues, command buffers and encoders were checked against the device's sources). The
  same check was not completed for the other Metal-using modules; of those, `MetalImageView` and `AnimationCompression`
  were read and use Metal only behind `#available(iOS 12.0, *)`, which is false on iOS 6.
