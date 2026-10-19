# CIImage compositing, image buffers, linear sampling; CIFilter with input parameters

Ranks 43, 50, 58 and 59 of `coordination/corpus/band-frameworks.tsv`, all `CRASH-ON-USE`: delta,
telegram and aidoku send the selectors. The armv7 cache ladder first carries
`imageByCompositingOverImage:` and `+filterWithName:withInputParameters:` at 8.0, the four
`CVImageBuffer` initializers at 9.0; `imageBySamplingLinear` is after the ladder's last rung, so its
11.0 is the header's. Each release is its own file: `Graphics/CIImage+Compositing8.m`,
`CIImage+ImageBuffer9.m`, `CIImage+SamplingLinear11.m`.

`tests/backports/host/ciimage` builds the three for macOS with their selectors prefixed and holds
them to the host's own methods: 183 checks, 0 different - extents and 8-bit pixels of 30 composites
of translucent, opaque, clear, offset and infinite images, over nil too; 30 filter makes (five names,
one unknown, six parameter sets: none, empty, a known key, two keys, an unknown key, the input
image) compared by name, input values and the exception; the four initializers over BGRA, ARGB and
bi-planar buffers and NULL; linear sampling. An iPad 2 running 6.1.3, 17 checks, 0 failures, with
the categories built into a daemon (`tests/backports/device/ciimage.m`).

## imageByCompositingOverImage:

`CISourceOverCompositing` (iOS 5) with this image as input and the argument as background. Over
nil the host answers the image itself, the same object, and so does the port, where the filter
would give nil. On the device, half-transparent red over opaque blue is `128 0 128 255`
premultiplied where they overlap, `128 0 0 128` where only red is, blue where only blue is, over the
union of the extents.

## +filterWithName:withInputParameters:

`filterWithName:`, which on iOS (6.1.3 measured, and the host) already sets the default values,
then each parameter by its key: `CIColorControls` given only a saturation keeps brightness 0 and
contrast 1. An unknown filter is nil; an unknown key raises `NSUnknownKeyException` on the device as
on the host.

## CVImageBuffer initializers

The image buffers iOS hands out - a capture's, a decoder's, a player item output's - are pixel
buffers, so the initializers pass a pixel buffer to `initWithCVPixelBuffer:(options:)`, and answer
nil for NULL or any other kind. Measured on 6.1.3: the release's own `initWithCVPixelBuffer:` answers
nil for a pixel buffer that has no IOSurface (made by `CVPixelBufferCreate` without
`kCVPixelBufferIOSurfacePropertiesKey`), where the host makes an image; with an IOSurface both make
the 24x12 image. The port gives the release's answer rather than copy the pixels into a surface of
its own, which would make an image that no longer sees later writes to the caller's buffer.

## imageBySamplingLinear

iOS 6's CoreImage has one sampling, linear, and no way to ask for another (`imageBySamplingNearest`
is iOS 11 and not carried), so an image is its own linearly sampled image and the port answers
`self`. On the device a scaled edge half covered comes out half (`0 0 128 128`). On the host, the
explicitly linear image drawn with a margin around it equals the image's own drawing within one step
of 255 (a few edge pixels round the other way), while nearest sampling differs widely; drawn over
bounds that cut through the scaled edge, the host's explicitly linear image treats that edge
otherwise (up to 85 steps on a 7.5 by 4.5 image). The host test draws with a margin; the cut-edge
difference is the host's and has no counterpart on a release with one sampling.
