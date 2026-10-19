# WebGL on a 2011 GPU

WebGL works on this phone. `canvas.getContext("webgl")` returns a context,
shaders compile, and a triangle drawn by the GPU reads back with the colour it
was given, on a PowerVR SGX543MP2 that Apple stopped shipping software for three
major releases ago.

```
webgl-context           WebGL 1.0
webgl-clears            16,64,192,255
webgl-links-a-program
webgl-draws-a-triangle  255,89,0,255
webgl-without-errors    0x0
```

Those are five of the checks in `tests/device/web-platform.html`, run on the
device by `tests/device/run.py`, so a regression is a failing test rather than a
discovery.

WebGL **2.0** is not here and will not be: it needs OpenGL ES 3.0 and this
silicon is an ES 2.0 part. That is a ceiling, not a milestone.

## Why it took a backend

`ENABLE_WEBGL` was off because the only GL backend in the tree,
`GraphicsContextGLCocoa`, goes through ANGLE's Metal renderer, and Metal needs an
A7. ANGLE has backends on CGL for macOS, EGL for Linux and Android, WGL for
Windows - and nothing for a device whose only GL API is EAGL.

The WebCore side of WebGL needed none of that work: all 3535 lines of
`GraphicsContextGLANGLE.cpp`, with every piece of WebGL validation and security
in it, is already platform independent.

## What was written

**`src/libANGLE/renderer/gl/eagl/`** - the backend, modelled on `cgl/`:

- `DisplayEAGL` creates an `EAGLContext` for ES2, makes it current, and opens
  `OpenGLES.framework` with `dlopen` because EAGL has no `getProcAddress`.
  Everything macOS-specific in the CGL version - pixel formats, virtual screens,
  the dual-GPU dance - has no counterpart here and is gone rather than stubbed.
- `PbufferSurfaceEAGL` is the CGL surface with the names changed: renderbuffer
  and framebuffer code with nothing platform-specific in it.
- `IOSurfaceSurfaceEAGL` is the one that had no model. `EGL_ANGLE_iosurface_client_buffer`
  is how a canvas leaves the GPU for the compositor; the CGL backend implements it
  with `CGLTexImageIOSurface2D`, which points an existing texture object at
  another texture's storage. GLES has no such call. What it has is
  `CVOpenGLESTextureCache`, which makes a texture of its own out of the surface,
  so this surface creates that texture and hands the name over:
  `attachToFramebuffer` gives it to the framebuffer, and `EGL_BindTexImage` gives
  it to the texture object the caller named, which uses it in place of its own
  until the image is released. That last step needed one seam in ANGLE proper:
  `SurfaceGL::getBindTexImageTextureID`, which every other backend answers with
  zero, and a texture that knows the name it is holding is not its own to delete.
- `DeviceEAGL` answers nothing, because EAGL has no device object to name.
- `Display.cpp` selects the backend in the three places that decide a display.

**The build.** ANGLE had never been compiled for armv7. Three things were in the
way, all inert for other platforms: `OpenGL::GLES` had no definition here
(the finder looks for a pkg-config `glesv2`, which is a Linux install, and GLES
is a framework here); ANGLE refuses to build against an SDK older than iOS 17,
which is the Metal backend's floor and does not apply to a GLES build; and the
Metal renderer had to go, since it cannot compile against this SDK and could
never run on this GPU. `common/system_utils_ios.cpp` was added, because the file
the port removes - `system_utils_mac.cpp` - was the only definition of
`GetSharedLibraryExtension`.

**The WebCore side.** `GraphicsContextGLCocoa` asks for the GLES platform rather
than Metal, leaves the Metal feature overrides alone, drops the power preference
(one GPU, no extension to choose between them - and a display attribute the
backend does not advertise is rejected outright), and replaces the Metal
shared-event completion signal, which has no fence equivalent in GLES 2.0, with
a finish and a direct call.

**IOSurface support.** WebGL's whole presentation path is built on WebCore's
`IOSurface`, and `HAVE(IOSURFACE)` was off for this port. Turning it on cost four
small things: the IOKit types WTF needs are declared locally, since the iOS SDK
has no public IOKit headers; `IOSurfaceAccelerator` is unlinked, because it is an
iOS 8 framework and linking it stops the engine loading at all; two symbols this
release lacks - `kIOSurfaceName` and `CGIOSurfaceContextCreateImageReference` -
are supplied by the compatibility library, the second by calling the copying form
this release does have; and ownership identity is turned off with the task
identity token it depends on.

Of the 44 IOSurface symbols WebCore imports, exactly two were missing on this
device. The rest have been there since 2012.

**One regression, found by the suite and fixed.** With IOSurface support on,
canvas image buffers moved to the IOSurface backend - the request had always been
`RenderingMode::Accelerated`, and the missing backend had been silently falling
through to a bitmap. A CoreGraphics context over an IOSurface drops the four
non-separable blend modes, and the suite caught all four. Canvas keeps the bitmap
backend on this port; WebGL makes its own IOSurfaces and does not go through
there.

## Getting the canvas onto the screen

Everything above can be true while the canvas is a white rectangle, and for a
while it was: a context, a clear, a triangle, all of it read back correctly with
`readPixels`, and nothing on the display. Reading back and presenting are
different paths, and only one of them was working. Two things were in the way.

**The order of the two schedulers.** A canvas hands the compositor its finished
surface in the rendering update's preparation step, and the compositor picks it
up when layers are flushed. In WebKit2 those are the same pass. In WebKit1 the
layer flush is driven by the layer-flush scheduler and the rendering update by
its own, and here the flush went first every time: the layer was displayed
before the canvas had been prepared, saw no surface, and cleared itself. Nothing
marks the layer again afterwards, so on a page that draws once - which is most
WebGL demos and every screenshot test - the frame never arrived at all.
`-[WebView _flushCompositingChanges]` now prepares the page's canvases before it
hands the layers over, through a `Page` entry point that the rendering update
uses as well.

**What CoreAnimation will accept as layer contents.** Upstream gives the layer
the IOSurface itself, which this release's CoreAnimation takes without
complaining and never draws. It is given a `CGImage` over the same surface
instead - `IOSurface::createNativeImage`, which is the path `toDataURL` was
already proving correct on this device.

`tests/device/gl-present.py` is the check that would have caught this: a canvas
cleared to red, a screenshot, and the share of the page area that is actually
red. It reads 97%.

### The freeze that only an animation could show

`CVOpenGLESTextureCache` hands out textures and expects a flush to let go of
them. This backend never flushed, so every IOSurface it had ever wrapped stayed
referenced: `IOSurfaceIsInUse` answered true for the drawing buffer WebKit was
about to reuse, WebKit dutifully destroyed it and made a new surface, and after
the first frame the web thread stopped answering entirely - no crash, no log, a
page that simply stopped. Releasing the surface's texture and flushing the cache
in `releaseTexImage` is the documented shape of this API, and it is what the
frame-rate numbers above are measured on.

## What Khronos' conformance suite says

The suite is not vendored - it is cloned separately and served from the Mac, and
`tests/device/conformance.py` runs named tests on the phone. What has been run
so far, and what it found:

| Area | Result |
| --- | --- |
| Framebuffers and renderbuffers, 5 files | 699 pass, 0 fail |
| Context attributes, alpha/depth/stencil/antialias | 524 pass, 0 fail |
| Reading pixels, 2 files | 373 pass, 0 fail |
| State, enums, buffers, error reporting, 4 files | 368 pass, 0 fail |
| Texture size, formats, copies, default texture | 242 pass, 0 fail |
| `rendering/draw-arrays-out-of-bounds` | 30 pass, 0 fail |
| `textures/misc/texture-npot` | 84 pass, **2 fail** |
| `rendering/culling` | 13 pass, **4 fail** |

The first risk this document listed - framebuffer completeness for formats other
than RGBA8 - is answered: 699 checks over attachment format combinations, none
failing.

Two bugs it found, both fixed here:

- **A context asked for without an alpha channel was lost on creation.** WebKit
  asks for `GL_RGB` as the pbuffer's internal format, and this backend accepted
  only BGRA and RGBA, so `EGL_CreatePbufferFromClientBuffer` failed and the page
  got a lost context. The CGL backend serves `GL_RGB` from the same BGRA surface
  and so does this one now.
- **And then read back transparent.** A surface that has an alpha channel serving
  a context that asked for none has to answer opaque: ANGLE swizzles the alpha
  away when sampling once the surface says `hasEmulatedAlphaChannel`, and the
  surface's own bytes are cleared to opaque once, which is what CGL does.

Two that are still open, and both of them are this driver rather than this port:

- **NPOT cube maps do not sample.** Two checks in `texture-npot`; NPOT 2D
  textures are fine, which is what OpenGL ES 2.0's core allowance covers.
  Asked directly, outside ANGLE and WebKit, the driver samples green from an 8x8
  cube map and black from a 5x5 and a 7x7, with no GL error at all. The driver names no npot extension of any kind. Making this pass
  would mean ANGLE rescaling NPOT cube maps to a power of two behind the page's
  back, which nothing in the GL backend does today.
- **Face culling is unreliable when the colour attachment came from an
  IOSurface.** Four checks in `rendering/culling`. Three framebuffers were
  measured - a renderbuffer, a plain texture, and a texture the CoreVideo cache
  made from an IOSurface, which is what a canvas draws into here - with `BACK`,
  `FRONT` and `FRONT_AND_BACK` against each, three passes apiece.

  The first two are right every time. The IOSurface one is not right and not
  even stable: left alone its answers move from pass to pass, as though the
  state landed a draw late, and the same draws are correct against the other two
  attachments in the same process, with the same GL calls, and no GL error
  anywhere. ANGLE is not involved - beacons had already shown it sending
  `glCullFace` and `glEnable(GL_CULL_FACE)`, with the driver reporting
  `enabled=1 mode=0x408` at the moment of the draw.

  Four ways to make the driver notice the state in time were measured and none
  works: `glFlush` before the draw, `glFinish`, rebinding the framebuffer, and a
  redundant `glEnable(GL_CULL_FACE)`. With any of them the answer stops moving
  and settles on not culling at all.

  Nor is there a format to escape into: CoreVideo on this release refuses to
  make a texture from a `BGRA` IOSurface asked for as `GL_BGRA_EXT` internally,
  refuses an `RGBA` IOSurface outright, and a plain `GL_BGRA_EXT` texture makes
  an incomplete framebuffer. The one combination that works is the one the port
  already uses.

  So the way out is the attachment itself, and it costs what was removed for
  speed: render into a plain texture and copy into the IOSurface when the frame
  is presented. That is a trade - conformant culling against a copy per frame -
  and not a bug to be fixed quietly. Nothing in the device suite or the
  eight-site sweep depends on culling today.

## What is left

- **Conformance, the rest of it.** What has been run is below; the suite has
  hundreds of files and this is a few dozen of them.
- **The `GL_Finish` per frame.** Metal signals frame completion through a shared
  event; GLES 2.0 has no fence, so the frame is waited for instead. It is the
  same guarantee and a worse way to get it.
- **Performance.** A spinning triangle holds 28-30 frames a second at every
  canvas size measured (64x64, 320x240, 320x480), so the cost is per frame - the
  prepare, the `CGImage` over the surface, and the drawing buffer's own
  bookkeeping - rather than per pixel. Nothing heavier has been measured, and
  the per-frame cost is where a real page will feel this port.
  `tests/device/gl-frame-rate.py` prints the numbers.
