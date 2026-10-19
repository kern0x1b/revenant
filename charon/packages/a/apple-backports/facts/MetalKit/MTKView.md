# MTKView, iOS 9

Part of the Tier 2 Metal/MetalKit verdict. The earlier sweep's reasoning - no GPU driver, so no
Metal - does not reach a view: `MTKView` is a `UIView` backed by a `CAMetalLayer`, and this port
already carries a real, working `CAMetalLayer` (`facts/Metal`, `CAMetalLayer8.m`) over its
Metal-over-OpenGL-ES-2.0 device.

## What the port does

`+layerClass` answers `CAMetalLayer`, so every `MTKView` instance is backed by a real layer this
port's Metal already draws through. `device`, `colorPixelFormat`, `framebufferOnly`,
`presentsWithTransaction` and `colorspace` all forward to that layer's own real properties.
`drawableSize` reads and writes the layer's own `drawableSize`. `currentDrawable` is the layer's
real `-nextDrawable` (`CharonMetalNextDrawable`). `clearColor`/`clearDepth`/`clearStencil` are held
and used to build a real `MTLRenderPassDescriptor` in `currentRenderPassDescriptor`, attaching the
current drawable's texture and, when `depthStencilPixelFormat` is not `MTLPixelFormatInvalid`, a
real depth/stencil texture created through the device's own `-newTextureWithDescriptor:`, cached
and rebuilt only when the drawable size changes.

A `CADisplayLink` drives the draw loop at `preferredFramesPerSecond` (default 60) whenever the view
is in a window, not paused, and not `enableSetNeedsDisplay`; each tick calls `-draw`, which resizes
the layer's `drawableSize` to the view's own bounds when `autoResizeDrawable` is on (the default),
then calls the delegate's `-drawInMTKView:` if one is set, or a subclass's own `-drawRect:`
override if the delegate isn't. `enableSetNeedsDisplay` switches to `UIView`-style
`-setNeedsDisplay`-driven redraws instead, tearing down the display link. `-releaseDrawables`
drops the cached depth/stencil texture, recreated lazily on next access, as the header describes.

## What differs from the release

`multisampleColorTexture` always answers `nil`: this port's Metal-over-ES2 bridge does not
implement multisample resolve, so `sampleCount` is stored but never triggers the MSAA texture the
header describes - a real, stated gap, not a silent one (an application that reads
`multisampleColorTexture` after setting `sampleCount > 1` gets `nil`, the honest "no such texture"
answer, not a crash). `mtkView:drawableSizeWillChange:` is never called, since the drawable is
either kept exactly at the view's bounds (`autoResizeDrawable` on) or left exactly as the
application set it (off) - there is no separate resize event to report. `preferredDrawableSize` is
not carried (macOS-only in the header, unreachable on this platform). `depthStencilAttachmentTextureUsage`
and `multisampleColorAttachmentTextureUsage` (iOS 13) are held and default to `MTLTextureUsageRenderTarget`
as the header documents, but only the depth/stencil one has anywhere real to apply, since
`multisampleColorTexture` is never built (above).
