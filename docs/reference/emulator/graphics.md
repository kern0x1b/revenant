# Graphics

The guest's OpenGL ES and Vulkan paths, as the emulator runs them. Values are what the code enforces today.

## Shaders

A program made of GLSL ES 1.00 shaders that are not the compositor's is compiled, linked and run: the vertex
shader per vertex, the fragment shader per pixel, with uniforms, attributes, varyings, textures, `discard` and
blending, for triangles. Core Image's OpenGL ES path draws with it.

- A varying that the two shaders declare with another type or array size, or that only the fragment shader
  declares, fails the link. A draw with a program that did not link is an error.
- The variables of one shader function take at most 1024 values; an array counts its length. A shader that
  declares more does not compile, and the info log names the function.
- A shader whose macros expand to more than 65536 tokens or 4 MiB of text, or whose source is longer than
  256 KiB, does not compile. The info log says which.
- Statements and expressions nest at most 32 deep, and an expression tree is at most 128 tall. A run nests at
  most 256 evaluations and statements, calls included. A shader beyond these is refused rather than overrunning
  the host thread's stack.
- The globals of a shader (uniforms, varyings, plain globals) take at most 4096 values.
- All invocations of one draw's shaders may take 200 million steps (loop iterations and calls) together. A draw
  that outruns that fails with `GL_INVALID_OPERATION` and draws nothing.

## Vulkan and the renderer

- A boot finds its Vulkan driver without `VK_ICD_FILENAMES`. The build takes Revenant's `swiftshader` package and
  puts `libvk_swiftshader.dylib` beside the program; the emulator hands it to the Vulkan loader by path
  (`VK_LUNARG_direct_driver_loading`), next to the system's drivers.
- When no Vulkan driver is usable, the boot draws with the reference renderer and logs one
  `[gles-renderer] Vulkan unavailable (...)` line.

## Contexts

- OpenGL ES contexts are made on iOS 6.1.3's GLEngine, whose dispatch table is larger than the earlier ones.
  `EAGLContext` answers a context, not nil.

## Core Image

- `vm_remap` places memory into another task. Core Image's compiler daemon loads its kernels through it, so Core
  Image draws a source with alpha.
