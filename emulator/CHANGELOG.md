# Changelog

All notable changes to this project are recorded here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- The iPhone 4S's Voice audio device with its input and output streams, formats,
  buffer, latencies and controls as a real device publishes them.
- `glReadPixels` reads RGBA bytes back from a framebuffer, a renderbuffer or the
  drawable, with the pack alignment and the rectangle clipped to the frame.
- A program made of GLSL ES 1.00 shaders that are not the compositor's is compiled, linked and
  run: the vertex shader per vertex, the fragment shader per pixel (uniforms, attributes, varyings,
  textures, `discard`, blending), for triangles. A varying the two shaders declare with another type
  or array size, or that only the fragment shader declares, fails the link; a draw with a program
  that did not link is an error. Core Image's OpenGL ES path draws with it.
  The variables of a shader function take at most 1024 values (an array counts its length); a
  shader that declares more does not compile, and the info log names the function.
  A shader whose macros expand to more than 65536 tokens or 4 MiB of text, or whose source is longer
  than 256 KiB, does not compile either (the info log says which).
  Statements and expressions nest at most 32 deep and an expression tree is at most 128 tall, so a
  shader of a few thousand parentheses, braces or terms is refused instead of overrunning the host
  thread's stack; a run nests at most 256 evaluations and statements, calls included.
  The globals of a shader (uniforms, varyings, plain globals) take at most 4096 values.
  All the invocations of one draw's shaders may take 200 million steps (loop iterations and calls)
  together; a draw that outruns that fails with GL_INVALID_OPERATION and draws nothing.

### Changed
- Shade builds with xmake as a member of hades (`xmake build shade`, `xmake test` at the top of hades):
  one xmake target per former CMake library, the same include roots, tests and options
  (`--shade_vulkan`, `--shade_sdl`, `--shade_ffmpeg`, `--shade_lto`,
  `--shade_dynarmic_test_emit_failure`, the guest probe's `--shade_guest_rootfs` and
  `--shade_armv6_ld`). The CMake files are gone. Every library is an xmake package: Dynarmic and Boost
  from hades' `third_party` repository, OpenSSL and libplist from charon's, the rest from xmake's. The
  vendored Vulkan Memory Allocator is the `vulkan-memory-allocator` 3.4.0 package now (the same header).
  The IR artifact key takes the Dynarmic package's identity (its commit and patch checksums,
  `DYNARMIC_BUILD_FINGERPRINT`), so artifacts saved before this are made again once.
- The JIT core is Dynarmic again, under its own name: upstream (MC-XiaoXiao/dynarmic) at a
  pinned commit with our patches (the arm64 backend for A32 guests, the A32 test swap callbacks,
  the fault-injection hooks named for the core), kept in hades' `third_party/dynarmic`; Boost is
  the 1.81.0 release pinned in `third_party/boost`. The Umbra and ext-boost submodules are gone.
  IR artifacts saved before this are made again, since the core's revision is in their key.
- The project is named Shade, and its JIT core Umbra: the namespace, build files,
  binary, file names and preference keys.
- The core is a separate submodule, `external/umbra`, and the Boost headers come
  from an independent repository.
- The device's class keys are derived under a new label; a device state saved
  before this is made again.

### Fixed
- A boot finds its Vulkan driver without `VK_ICD_FILENAMES`: the build takes charon's `swiftshader`
  package and puts `libvk_swiftshader.dylib` beside the program, and Shade hands it to the Vulkan
  loader by path (`VK_LUNARG_direct_driver_loading`), next to the system's drivers. When no Vulkan
  driver is usable the boot draws with the reference renderer and logs one
  `[gles-renderer] Vulkan unavailable (...)` line, where it used to stop at once.
- OpenGL ES contexts are made on iOS 6.1.3's GLEngine, whose dispatch table is
  larger than the earlier ones: EAGLContext no longer answers nil.
- A memory object's purgeable state takes the whole state word (volatile with an
  ordering bit, a group), as the kernel does.
- `vm_remap` places memory into another task: Core Image's compiler daemon loads
  its kernels, so Core Image draws a source with alpha.
- The guest answers hw.activecpu, hw.physicalcpu, hw.logicalcpu, hw.cpufrequency,
  hw.busfrequency and their `_max` forms from the device profile, and hw.ncpu with
  the processor count the kernel has: OpenCL sized its CPU device from stack
  garbage, so Core Image's Gaussian blur (a one-dimensional kernel) drew nothing.
- The host's memory is read on macOS: the JIT sized its code cache from zeros.
- iOS 6.1.3 boots on the iPhone 4S with mediaserverd running: it needs the Voice
  device's input stream.
- The Vulkan Memory Allocator's README carries its own name, and NOTICE lists the
  allocator.

### Removed
- The configure-time test patch the JIT core already contained.
