# air2es

Turns the render functions of a Metal library into OpenGL ES 2.0 shaders, for the iPhone 4S and the iPad 2, whose
PowerVR SGX 543 has no Metal. A `.metallib` holds AIR, LLVM bitcode with Apple's intrinsics and metadata; an
application ships that, not the Metal source, so AIR is what is translated.

    air2es MODULE.bc PREFIX                    one function: PREFIX.vert or PREFIX.frag, and PREFIX.json
    xmake l metallib2es.lua air2es LIB.metallib OUT    every function of a library into OUT, with OUT/library.json

`air2es` links LLVM (`llvm-config --libs core bitreader`); `tests/backports/host/air2es/run.sh` builds it and holds it to
the fixtures. The Metal backport reads `OUT` when an application asks for `LIB.metallib` and finds `LIB.metallib.es2`
beside it.

## What it writes

The GLSL is ES 1.00, and glslang accepts it as that. `PREFIX.json` says what the runtime has to bind, read from the
function's own metadata: the vertex attributes with the buffer, offset and stride a buffer read by vertex identifier
comes from, the uniforms with the buffer and offset each is loaded from (and the stride between instances when the
index is an instance identifier), the textures, the sizes of textures the function asks for, the varyings (with a
`flat` mark) and the vertex inputs of a vertex descriptor.

`half` becomes `mediump`. The vertex shader turns the depth of Metal's clip space, 0 to w, into ES's, minus w to w (`gl_Position.z = gl_Position.z * 2.0 - gl_Position.w`), so the depth buffer holds what Metal's would, and ends with `gl_Position.y *= revenant_flip`, which the runtime sets to -1 for
a render target that is a texture, since Metal's window has its origin at the top and ES's framebuffer object at the
bottom.

## Control flow

A function of several basic blocks is written as one straight run of guarded blocks: each block has a flag that says it was reached, the
edges set the flags and assign the phi values of the block they lead to, and a block's code runs under its flag. A loop becomes
a `for` of 64 rounds with a `break` when the loop's exit is taken; ES 1.00 wants a constant bound, so a loop that would run more than
64 rounds stops at 64, and nothing marks the shader when it does. A loop inside a loop is refused. `discard` is carried.

## Depth textures

A depth texture is read as a `sampler2D`, taking the depth from its first channel (`OES_depth_texture`), and a comparing read (`sample_compare`) is a `sampler2DShadow` read with `shadow2DEXT`
(`GL_EXT_shadow_samplers`, which the SGX 543 has); the comparison is the one of the sampler the function is given. `PREFIX.json` marks such a texture `depth` and `compare`.

## Several render targets

ES 2.0 has one colour output, so a function that writes several targets (up to four) gets a uniform, `revenant_output`, that says which of its colours to write, and the runtime draws
once for each target, into the target's own framebuffer, with the target's own blending. `PREFIX.json` says how many outputs there are.

## The colour attachment

A fragment function that takes the colour it draws over as an argument (`[[color(n)]]`) reads it in one of two ways. When the function writes that target and no other, it reads
`gl_LastFragData[0]`, with `GL_EXT_shader_framebuffer_fetch`, which the SGX 543 has: the framebuffer is read where the tile is, and there is no copy of it to a texture. When it does not write that
target, it reads the attachment as a texture (`revenant_attachmentN`) at the position of the fragment, and `PREFIX.json` lists the attachment; the runtime binds it, since it is not the one drawn to. A function may write
any of the four targets, alone or with others.

## Function constants

A function constant is a global the library fills in when a function is made, and a predicate a static initialiser computes from the constants. The
shader carries them as the names `revenant_fcN` (the value) and `revenant_fcN_defined` (whether it was given), for the port to define at the head of the source
when it makes the function, and the initialiser is translated ahead of the function. `PREFIX.json` lists the constants with their index, name and type
(`bool`, `int` or `float`), and marks a vertex input that a constant switches as optional.

## What it refuses

A function it cannot translate is refused with the reason, and no file is written: a loop inside a loop,
a texture read in a vertex function (the SGX 543 has no vertex texture units), integer bit operations, reading a texture of integers, `min`, `max`, `clamp` and the like on integers,
a fragment output of an integer type, more than four render targets, reading a colour attachment that the function writes together with other targets, texture arrays, cubes,
textures of integers, reading a depth texture at a level, in pixel coordinates or with gradients, comparing with a sampler that is constant in the library, sampling with gradients or an explicit level, with a minimum level clamp, with an offset or in pixel coordinates,
reading a texture at a level or with an offset, `half` reads from a vertex buffer, dynamic indices into a buffer element, local arrays, a function
constant of a vector type, argument buffers, tessellation, compute kernels, and any AIR intrinsic without an ES 1.00 form.

A `flat` varying is interpolated, since ES 2.0 has no flat qualifier; the result is exact where the value is the
same at the three vertices of every triangle, and the JSON marks the varying so a port can tell.
