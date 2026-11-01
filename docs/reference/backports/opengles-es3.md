# OpenGL ES 3 on iOS 6: what the Backports do

The iOS 6 OpenGLES framework on the iPhone 4S (SGX543, IMGSGX543-73.16.1) is OpenGL ES 2.0 only. `src/OpenGLES/ES3Functions.m`
gives the ES3 entry points to an app built for iOS 7 and later. Each one does one of three things:

- **forwards** to the ES2 extension that carries the same function on iOS 6 (`glBindVertexArray` to `glBindVertexArrayOES`);
- **emulates** the subset of the call that ES2 can express exactly, and raises an error for the rest;
- **refuses** the call: it sets a GL error (`GL_INVALID_ENUM`, through a bind of texture 0) and does nothing else.

A refusal is a GL error the app can see with `glGetError`, never a silent no-op. The emulations are the only functions that
return success on a call they do not fully perform, and each one is limited to the cases where the ES2 result is the same.

## Emulated cases

| Function | Accepted (no error) | Refused with an error |
| --- | --- | --- |
| `glReadBuffer` | `GL_BACK` on the default framebuffer, `GL_COLOR_ATTACHMENT0` on a framebuffer object | every other mode, including `GL_NONE` |
| `glDrawBuffers` | one buffer, `GL_BACK` (default framebuffer) or `GL_COLOR_ATTACHMENT0` (framebuffer object) | any other count or buffer, including `GL_NONE` |
| `glClearBufferfv` | `GL_COLOR` and `GL_DEPTH` on draw buffer 0; the clear runs `glClear` and restores the clear value | other buffers and draw buffers |
| `glClearBufferiv` | `GL_STENCIL` on draw buffer 0 | integer colour buffers (ES2 has none) |
| `glClearBufferfi` | `GL_DEPTH_STENCIL` on draw buffer 0; depth and stencil cleared in turn | other buffers |
| `glDrawArraysInstanced` | `instancecount == 1`, which is `glDrawArrays` | any other instance count |
| `glDrawElementsInstanced` | `instancecount == 1`, which is `glDrawElements` | any other instance count |
| `glDrawRangeElements` | any range with `end >= start`, drawn as `glDrawElements` (the range is a hint) | `end < start` (`GL_INVALID_VALUE`) |
| `glVertexAttribDivisor` | divisor 0, the only divisor ES2 has | any non-zero divisor |
| `glGetUniformBlockIndex` | returns `GL_INVALID_INDEX` with no error, which is what ES3 returns for a program with no uniform blocks | none (ES2 programs have no uniform blocks) |
| `glInvalidateSubFramebuffer` | no-op: an invalidated region may keep its contents | none |

`glClearBuffer*` runs through `glClear`, so the scissor test and the colour, depth and stencil write masks apply as they
do to `glClearBuffer*` in ES3. The clear values are saved and restored around the call.

## Refused

These raise a GL error on iOS 6 and are not emulated:

- Transform feedback: `glBeginTransformFeedback`, `glEndTransformFeedback`, `glBindTransformFeedback`,
  `glDeleteTransformFeedbacks`, `glGenTransformFeedbacks`, `glIsTransformFeedback`, `glPauseTransformFeedback`,
  `glResumeTransformFeedback`, `glTransformFeedbackVaryings`, `glGetTransformFeedbackVarying`.
- Uniform blocks: `glBindBufferRange`, `glBindBufferBase`, `glGetActiveUniformBlockiv`, `glGetActiveUniformBlockName`,
  `glUniformBlockBinding`, `glGetUniformIndices`, `glGetActiveUniformsiv`, `glCopyBufferSubData`, `glGetBufferParameteri64v`.
- Samplers: `glGenSamplers`, `glDeleteSamplers`, `glIsSampler`, `glBindSampler`, `glSamplerParameter*`, `glGetSamplerParameter*`.
- Integer vertex attributes and uniforms: `glVertexAttribIPointer`, `glVertexAttribI4*`, `glGetVertexAttribI*`,
  `glUniform1ui`..`glUniform4uiv`, `glGetUniformuiv`, `glClearBufferuiv`, `glGetFragDataLocation`.
- Non-square uniform matrices: `glUniformMatrix2x3fv`, `glUniformMatrix3x2fv`, `glUniformMatrix2x4fv`,
  `glUniformMatrix4x2fv`, `glUniformMatrix3x4fv`, `glUniformMatrix4x3fv`.
- Blits and layered targets: `glBlitFramebuffer`, `glFramebufferTextureLayer`.
- 3D and layered textures: `glTexImage3D`, `glTexSubImage3D`, `glCopyTexSubImage3D`, `glTexStorage3D`.
- Program binaries: `glGetProgramBinary`, `glProgramBinary`.
- Queries of internal formats: `glGetInternalformativ`.

## Forwarded

`glBindVertexArray`, `glDeleteVertexArrays`, `glGenVertexArrays`, `glIsVertexArray` (ES2 `OES_vertex_array_object`),
`glMapBufferRange` and `glFlushMappedBufferRange` (`EXT_map_buffer_range`), `glInvalidateFramebuffer`
(`EXT_discard_framebuffer`), `glTexStorage2D` (`EXT_texture_storage`), `glRenderbufferStorageMultisample` (`APPLE_framebuffer_multisample`),
the fence and sync functions (`APPLE_sync`), and the queries in `src/OpenGLES/ES3Queries.m` (`EXT_occlusion_query_boolean`).
`glGetStringi` splits `GL_EXTENSIONS` into tokens.

## EAGL: no ES3 context

`[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3]` returns nil on iOS 6, and expo-gl then creates an ES2 context
(`ios/EXGLContext.mm` in expo-gl 57.0.2). The backport does not change this. An ES3 context would report
`kEAGLRenderingAPIOpenGLES3`, and an app would then send `#version 300 es` shaders to a driver that compiles GLSL ES 1.00
only. Revenant has no GLSL ES 3.00 to 1.00 translator (the only GLSL to SPIR-V path is the host emulator's), so that context
would fail at shader compile. It is not created until such a translator exists.

### The translator this needs

The gap is the shader language, not the entry points. A GLSL ES 3.00 to GLSL ES 1.00 translator would be the missing step.
Its candidate parts, both in xmake-repo:

- glslang, the front end: GLSL ES 3.00 to SPIR-V. The emulator already uses it on the host (`emulator/src/glsl/glsl_to_spirv.cpp`,
  a 104-line wrapper behind the `emulator_vulkan` option), so the host half exists. The iOS 6 half does not: glslang would
  have to be built for armv7 as a package.
- SPIRV-Cross, the back end: SPIR-V to GLSL with `version 100` and `es`. It is not in the tree. Its ES 1.00 output rejects
  integer bit operations, uniform blocks, and some dynamic indexing, so those shaders would be refused by name, not
  translated.

The first measure is the shader corpus. The expo-gl package (57.0.2) has no ES 3.00 shader: its only shader text is the
ES 1.00 camera shader in `android/src/main/java/expo/modules/gl/GLCameraObject.java`. A prototype therefore needs shaders
chosen by someone who knows the apps that use expo-gl. Until that choice is made, no translation result is claimed.

`GL_VERSION` and `GL_SHADING_LANGUAGE_VERSION` are not changed: the backport passes the driver's own strings through, and
the driver is an ES 2.0 driver with a GLSL ES 1.00 compiler.

## Extensions on the device

The iPhone 4S driver's `GL_EXTENSIONS` list is not measured yet. The GLES2 probe did not record it (R8 in
`docs/explanation/backports/metal-on-ios6.md`). The forwards above name the ES2 extensions the SDK headers declare; whether the
device exposes each one is the open part, and a device run must record `GL_EXTENSIONS` before this page is final.

## Tests

No host test runs these paths. The emulator (`emulator/`) boots a whole iOS userland and is not a GL unit test, and macOS
has no OpenGL ES. `ES3Functions.m` is checked by compiling it for `armv7-apple-ios6.0`
(`clang -fsyntax-only -target armv7-apple-ios6.0 -isysroot <iPhoneOS 26.2 SDK>`). The device run is the test of these cases.
