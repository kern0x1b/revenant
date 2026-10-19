# The Metal layer, iOS 8.0

`CAMetalLayer` came in iOS 8.0: a layer that hands out textures to draw into with Metal, `nextDrawable` at a time. An
application makes one as the layer of a view, gives it the device `MTLCreateSystemDefaultDevice()` answered, and
asks it for a drawable each frame.

Source: QuartzCore of the arm64 shared cache of iOS 12.0 - the method list of `CAMetalLayer`, and
`-[CAMetalLayer setMaximumDrawableCount:]` at `0x18549a2b8`, with the exception it raises: name
`CAMetalLayerInvalidMaximumDrawableCount` and reason `failed trying to set maximumDrawableCount to %lu outside of the valid range of [2, 3]`;
the defaults are the ones the header of iOS 16.4 documents, and were not read from the cache.

## What it is

A `CALayer` that keeps a device, a pixel format (BGRA8 unless told, `MTLPixelFormatBGRA8Unorm`), whether it is for the framebuffer only
(yes), a drawable size (the size of its bounds in pixels until it is set), whether it presents with the transaction (no), a
colour space, whether `nextDrawable` may time out (yes), a maximum of drawables (3, 2 or 3 allowed), and answers a drawable for each
`nextDrawable`.

## Where iOS 6 differs

The layer of this package draws into OpenGL ES: the first `nextDrawable` of a layer whose device is the one of the port makes a
layer of OpenGL ES beneath it, as large as the drawable size, and answers a drawable whose texture is that layer's framebuffer; the
drawable is shown when the command buffer that presents it is committed. A layer with no device, or a device that is not the port's,
answers `nil`, as the header says it does when no drawable is available. `preferredDevice` is `nil`. The maximum of drawables raises the
exception of iOS 12 for a value outside 2 to 3, and the port keeps one framebuffer and answers a drawable of it each time. The properties of
iOS 16 (`wantsExtendedDynamicRangeContent`, `EDRMetadata`, `developerHUDProperties`) are kept as three settings and used for nothing, and
they are kept by the port rather than by the release: `Metal/CAMetalLayer+ExtendedRange16.m` is a category that holds each in an associated
object, as the 11.0 and 11.2 properties beside it are. The claim this file used to make - that `@dynamic` on a layer means the release's
`CALayer` supplies an accessor that keeps the value - is false for these three and was measured rather than assumed: they are declared in
`CAMetalLayer.h:119`, `:128` and `:141` and so are the layer's own rather than `CALayer`'s, all six selectors are in none of the 113981
selectors of 6.1.3 nor of the 70062 of 4.3, 4.3's `CALayer` is 249 instance and 10 class methods with none of them, and `CAEDRMetadata` -
the class that would fill the second - is 0 of the 7187 class names of 4.3, as `CAMetalLayer` itself is. The names stay on the `@dynamic`
at `CAMetalLayer8.m:8` because that line is what stops that file synthesising a second accessor pair for a property another file answers.
