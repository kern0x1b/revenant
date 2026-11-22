# AVSampleBufferDisplayLayer: the pixel formats it draws on iOS 6

iOS 6's own `AVSampleBufferDisplayLayer` accepts an uncompressed frame and draws nothing for it (measured on the
iPhone 4S in [the system class page](SampleBufferDisplayLayerSystemClass.md)). The Backports category on that class
(`src/AVFoundation/AVSampleBufferDisplayLayer8.m`) wraps `enqueueSampleBuffer:`: after the system's own call it turns the
image buffer of a displayable sample into a `CGImage` on the CPU and makes it the layer's `contents`. The formats it draws
are:

| Format | Path |
| --- | --- |
| `kCVPixelFormatType_32BGRA`, `kCVPixelFormatType_32ARGB` | the bytes are copied into memory the image owns |
| `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange` (`420v`), `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange` (`420f`) | converted to BGRA by `revenant_copy_planar_image` |

Any other format, and a compressed frame, leaves no image from Backports; a compressed frame is left to the system queue.
The layer does not use `CIContext`: on iPhone4,1 6.1.3 a `420v` or `420f` sample sent through `CIImage` and `CIContext`
produced no image (`contents` nil), and creating the context at setup crashed inside CoreImage.

## The matrix

The conversion reads the `YCbCrMatrix` attachment of the image buffer, then the `YCbCrMatrix` extension of the format
description.

| Matrix | Result |
| --- | --- |
| `ITU_R_601_4` | BT.601 |
| `ITU_R_709_2` | BT.709 |
| absent | BT.709, whatever the size of the frame |
| anything else (`SMPTE_240M`, `ITU_R_2020`, a value that is not a string) | refused: no image, `contents` stays nil |

A refused frame does not fail the layer: the system reports no failure on iOS 6, so `status` is `Rendering` after the
enqueue as for any other frame and `error` stays nil.

The rule for an absent matrix is Apple's: `VTPixelTransferSession` on macOS converts a `420v` buffer of 720x480,
720x576, 960x540, 1280x720, 1920x1080 and 16x16 with no `YCbCrMatrix` attachment to the BT.709 result, identical to the
buffer marked `ITU_R_709_2` (Y 0x90, Cb 0x70, Cr 0x90 gives red 178, green 144, blue 115), while the buffer marked
`ITU_R_601_4` gives red 175, green 142, blue 117. The same probe on `CIImage` ignores the attachment and always gives
the 709 result, so it is not a reference for 601.

## What the case checks

`tests/runtime/cases/avfoundation_display_layer_formats.m` draws each row above on the emulator at iOS 6.1.3, through
`enqueueSampleBuffer:` of a layer of the system class, and compares the three channels of the layer's image separately
(Y 0x90, Cb 0x70, Cr 0x90; the neutral rows use Cb = Cr = 0x80): 601 video range 175/142/117, 709 video range
178/144/115, 601 full range 166/138/116, neutral gray 149 (video) and 144 (full). The rows with no matrix at 480 and 720
lines expect the 709 values. A `SMPTE_240M` sample expects no contents and a `status` of `Rendering`, not `Failed`. The
case runs with `REVENANT_RUNTIME_CASES=avfoundation_display_layer_formats ./xmakew test -P . backports_runtime/avfoundation_display_layer_formats`
on a `--tests=device` configuration; its negative control inverts every check and must fail all of them.
