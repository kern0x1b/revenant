# The functions OpenGL ES 3.0 added, iOS 7

OpenGL ES 3.0 arrived with iOS 7 on the A7 and later; the drivers of iOS 6 are ES 2.0. An application that draws with ES 2.0 and
asks for an ES 3.0 context first - and falls back when it gets none - still names the ES 3.0 functions, and does not start when
the release does not have them.

Source: `tests/backports/tools/gen-es3.py` writes `OpenGLES/ES3Functions.m` and the registry from the SDK: the ES 3.0 header
against the ES 2.0 header for the names and their types (99 functions), the shared caches of iOS 6.0 to 7.0.1 for the extensions the
release has and the five names it exports already. `device/opengles.m` calls them in an ES 2.0 context on the iPhone 4S.

## What the port does

25 of the functions have an ES 2.0 extension of the release that answers the same: the vertex array objects (`OES_vertex_array_object`),
the occlusion queries (`EXT_occlusion_query_boolean`, with the `GL_ANY_SAMPLES_PASSED` target), the fence syncs (`APPLE_sync`), the
mapping of a range of a buffer (`EXT_map_buffer_range`), the multisampled renderbuffer (`APPLE_framebuffer_multisample`), `glInvalidateFramebuffer`
(`EXT_discard_framebuffer`), the immutable texture (`EXT_texture_storage`), the program parameter and the 64-bit integer state. The function
looks the extension up by its name when it is called, and answers as it does; when the driver has not that extension it fails
as the rest do. `glGetStringi` answers the i-th name of the extension string. The context of `kEAGLRenderingAPIOpenGLES3` is not one
the release makes - `-initWithAPI:` answers `nil` for it - so an application that asks for one first and falls back gets the ES 2.0
context it would.

## What it cannot do

The other 74 have no ES 2.0 extension on this hardware - the 3D textures, the transform feedback, the uniform blocks, the samplers,
the integer attributes, the instanced draws, the framebuffer blit and the buffer copy - and answer as an ES 3.0 call in an ES 2.0
context ought to: nothing happens, `GL_INVALID_ENUM` is set (by a bind of the texture target zero, which no state depends on) and
the answer is zero or null. `kEAGLColorFormatSRGBA8` is a name for a format the release's drawable does not have.

## Where the release already has the names

The OpenGLES of iOS 3.0 to 4.3.5 already exports the seven query calls (`glGenQueries` to `glGetQueryObjectuiv`) under
their ES 3.0 names; 5.0 to 6.1.6 does not, and 7.0 does again (the held armv7 and armv7s caches). They are compiled into an object of
their own, `ES3Queries.m`, so that a band of a release that exports them takes the release's, and one that does not takes these.
Their registry rows stay at 7.0: the release this port runs on, 6.1.3, has none of them.
