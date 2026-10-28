# Metal on iOS 6

Status: decided by the owner, 2026-10-28. This is the one document for Metal on iOS 6. It consolidates five research
notes (compute, the re-landscape, the open-code sweep, the driver teardown and the device probe) and the probe code
they produced. Once it is on main, those notes and their branches retire.

## Source key

Each fact is tagged with the note it came from, so a reader can trace it.

| Tag | Note | Branch |
| --- | --- | --- |
| [compute] | `metal-compute.md` | `metal-compute` |
| [landscape] | `metal-compute-re-landscape.md` | `metal-re-landscape` |
| [sweep] | `metal-open-code-sweep.md` | `metal-re-landscape` |
| [teardown] | `metal-compute-driver-teardown.md` | `metal-driver-teardown` |
| [probe] | `metal-compute-device-probe.md` | `metal-device-probe`, commit 15f69b10d |
| [air2es] | `frameworks/Backports/src/air2es/NOTES.md` | `air2es`, commit 46561c85d |

Evidence labels: **device** = measured on the iPhone 4S (iPhone4,1, iOS 6.1.3, build 10B329). **disassembled** = read
from a shipped image. **static** = a string or plist check on a local image. **fetched** = a source read in full.
**snippet** = a search excerpt only. **inferred** = reasoned from the evidence above it. **unverified** = not settled.

## 1. Verdict

- **v1, now: Metal renders through air2es.** air2es translates Metal render shaders from AIR to GLSL ES 1.00, and the
  loader runs them through the closed iOS GL ES 2.0 driver. 11 of the 14 render functions in Telegram's metallib
  already translate, pass the Appendix A checker and pass glslangValidator in ES mode [air2es]. v1 is ordinary backport
  work: finish the three refused shaders and prove the render path on a device. **Compute is not in v1.**
- **v2, later, after the whole backport works: all Metal compute.** The cheapest start is fragment-GPGPU: compute
  written as ES 2.0 fragment shaders through the same GL driver. It needs no driver and no reverse engineering
  (section 4.1).
- **Parked, not pursued now:** cracking the GL user client's selectors, reverse-engineering the kernel GPU service's
  method table, and writing a custom SGX driver. These are v2-or-never. Section 4 records each one so that nobody has
  to rediscover it.
- **Compute is closed at the kernel on the device we have.** On an iPhone 4S running 6.1.3, the kernel GPU service
  refuses the compute user-client type that the shipped CL path uses. Mercury's `gldCreateQueue` returns no queue. The
  GL user clients open, and GL work runs [probe, device].
- **Two decisions for the owner before v2 starts** (section 5): whether the device trace the probe ran, and the
  disassembly of Apple's images, are covered by the iOS licence; and which leaked-material rule governs, since
  AGENTS.md and the owner's instruction differ.

## 2. What was established

### 2.1 Hardware

| Device | GPU | Basis |
| --- | --- | --- |
| iPhone 3GS, iPhone 4, iPod touch 3rd and 4th generation, iPad (1st generation) | SGX535 | Apple's archived OpenGL ES Hardware Platform Guide [compute]. The A4 SoC; the iPod touch 4 row is unverified here [landscape] |
| iPhone 4S (A5, iPhone4,1) | SGX543, MP2 by secondary sources | Guide [compute]. Device GL_RENDERER "PowerVR SGX 543" and GL_VERSION "OpenGL ES 2.0 IMGSGX543-73.16.1" [probe, device]. The probe did not read the core count from the phone |
| iPad 2 (iPad2,1 Wi-Fi; iPad2,2 attached in the probe session, unused), iPad 3 | SGX543, MP2 for iPad 2, MP4 for iPad 3 (secondary) | Guide [compute]. The iPad2,1 6.1.3 image and the iPad2,3 9.3.6 image were analysed [teardown] |
| iPad mini (1st generation), iPod touch 5th generation, iPhone 5 | SGX543 (MP3 for iPhone 5, secondary) | Guide [compute] |
| iPad 4 (A6X) | SGX554, MP4 (AnandTech table, snippet) | Guide [compute]; release history on iOS 6 unverified [compute] |
| Apple TV 3 (A5) | SGX543MP2 | Wikipedia, fetched; apple-history, snippet [landscape] |
| PS Vita | SGX543MP4+ (Sony customised) | Wikipedia, fetched [landscape] |
| Exynos 5410 (Galaxy S4 Exynos, ODROID-XU) | SGX544MP3 | Wikipedia and Imagination forum, fetched [landscape] |

The guide does not tie its rows or extension lists to an iOS version. Per-device values are the guide's, except where
marked device.

### 2.2 The iOS 6.1.3 driver stack

- **GL userspace.** The SGX543 driver is `IMGSGX543GLDriver`. Its Extensions bundle on the iPad2,1 extract holds only
  `Info.plist` (version 73.16.1). The driver code is in the iPad2,1 dyld cache [teardown, static]. The repo's
  `.cache/dyld/6.1.3` is the SGX535 build and holds `IMGSGX535GLDriver` [compute, landscape]. The device's own driver is
  IMGSGX543-73.16.1 [probe, device].
- **Mercury** (`libGPUSupportMercury`). `gldCreateContext` calls `IOAccelGLContextCreate` with user-client type 0
  (`movs r1,#0`). `gldCreateQueue` calls `IOAccelCLContextCreate` with type 3 (`movs r1,#3`). Both were disassembled, and
  the type 3 open was seen on the device [teardown, probe]. No shipped binary imports `gldCreateQueue`, so the GL path
  reaches Mercury through a name lookup (inferred) [teardown].
- **Compute entries in the GL driver are stubs.** `gldCreateComputeContext` returns -1. `gldCompileComputeModule`,
  `gldExecuteKernel` and `gldFinishQueue` return 0, and `gldFlushQueue` returns nothing. The same holds for the SGX535
  build and for 9.3.6's SGX543 driver [teardown, disassembled]. The SGX535 `glrComp*` family is also stubs [teardown].
- **OpenCL.** `cvmsConfig.plist` lists `OpenCLCPU`, `OpenCLPTX` and `OpenCLAMDil`. The cache has only the CPU plugin
  name, and the GPU compiler runtime is `runtime.armv7.bc` alone. The SGX535 build's OpenCL is CPU-only. The SGX543
  build's device list was not checked [compute, teardown, static].
- **Kernel GPU service.** `IOServiceMatching("IOAcceleratorES")` matches one service, of kernel class **`SGXDriver543`**
  [probe, device]. Teardown never found this name, and its search list did not include it, so its negative result is
  weak [teardown].
- **No binary-shader path.** `GL_IMG_shader_binary`, `IMG_shader_binary`, `SGX_BINARY_IMG`, `GL_IMG_program_binary`,
  `OES_get_program_binary` and `GL_NUM_SHADER_BINARY_FORMATS` are absent from the cache. `glShaderBinary` appears twice,
  and its context was not inspected [landscape, static]. The cache names `GL_IMG_texture_compression_pvrtc`,
  `GL_IMG_texture_format_BGRA8888` and `GL_IMG_read_format` [landscape, static].
- **Kernelcache.** Teardown reports a decrypted iPad2,1 6.1.3 kernelcache with no GPU class string. Re-landscape and
  compute say the extract has no kernelcache. This conflict is unreconciled (section 6, R1). The iPhone 4S kernelcache is
  7.7 MB, compressed or IMG3-wrapped, and was not decrypted [probe].

### 2.3 The live device result (iPhone 4S, iOS 6.1.3)

Measured on the phone, six runs with the same results, unsigned, as root, over ssh [probe, device].

- **GL baseline works.** GL_VENDOR "Imagination Technologies", GL_RENDERER "PowerVR SGX 543", GL_VERSION "OpenGL ES 2.0
  IMGSGX543-73.16.1", GL_MAX_TEXTURE_SIZE 4096, glError 0. The baseline did **not** print GL_EXTENSIONS,
  GL_NUM_SHADER_BINARY_FORMATS or GL_FRAGMENT_PRECISION_HIGH. Those checks are still to run.
- **Kernel user clients.** `SGXDriver543` opens GL user-client types 0, 1 and 2 (`IOServiceOpen` returns 0x0).
- **Compute user client refused.** Types 3 to 8 return `0xe00002c7` (`kIOReturnUnsupported`) with no connection. Root
  would get `kIOReturnNotPrivileged` (`0xe00002c1`) if the refusal were about privilege, so this is a type refusal.
- **Queue fails.** `gldCreateQueue(device, &out, 0, 0)` returns Mercury's own code `0x271f`, and `out` stays 0. An
  earlier run passed the context instead of the device and crashed the probe. That was a probe bug, not a kernel event.
  No kernel panic occurred in any run.
- **Selectors seen.** Type 0: selector 2 (104 B in, 336 B out), selector 0. Type 1: selector 0 (5 scalars out) and
  selector 2 (returns the ASCII string `IOAccelDeviceTestEventBasic`). Type 2: selector 1 (96 B in, 24 B out) and
  selector 7. Each call appears twice in the log, as `IOConnectCallMethod` and as a Scalar or Struct variant. The cause
  is not established.
- **Not run.** The iPad 2 (iPad2,2) was attached and free and was not used. iPad 3 and iPad 4 were not run.

### 2.4 ES 2.0 extension reality on SGX5

Apple's guide is the only per-GPU source. The "cache" column shows what the iOS 6.1.3 driver can name. It does not show
which GPU exposes what [landscape].

| Feature | SGX535 | SGX543 / 554 | Basis |
| --- | --- | --- | --- |
| OpenGL ES versions | 1.1, 2.0 | 1.1, 2.0 | guide [compute] |
| Max texture and renderbuffer size | 2048 | 4096 | guide; device `GL_MAX_TEXTURE_SIZE` 4096 on the SGX543 [probe] |
| Texture image units, vertex and fragment combined | 8 | 8 | guide |
| Vertex texture fetch (`MAX_VERTEX_TEXTURE_IMAGE_UNITS`) | 0 | 0 | guide; runtime value unverified |
| `MAX_FRAGMENT_UNIFORM_VECTORS` / `MAX_VARYING_VECTORS` | 64 / 8 | 64 / 8 | guide |
| `OES_texture_half_float` | yes | yes | guide |
| `EXT_color_buffer_half_float` (renderable RGBA16F) | no | yes | guide (543/554 only); extension text makes RGBA16F renderable |
| `EXT_color_buffer_float` (renderable float32) | no | no | guide; absent from cache |
| `OES_texture_float` | yes | yes | guide; textures only, not renderable |
| `EXT_shader_framebuffer_fetch` | yes | yes | guide; present in cache |
| `EXT_blend_minmax` | yes | yes | guide |
| `EXT_draw_buffers` (several outputs) | no | no | guide; cache has `EXT_draw_buffers2` only |
| `EXT_shader_pixel_local_storage` | no | no | needs ES 3.0 (extension text); absent |
| `EXT_occlusion_query_boolean` | no | yes | guide (543/554 only); a boolean, not a count |
| `EXT_instanced_arrays`, `EXT_draw_instanced` | no | no | guide; cache has ARB names only |
| `highp` in the fragment stage | unverified | unverified | optional in ES 2.0 (GLSL ES 1.00, section 4.5.4); the device query settles it |
| `OES_get_program_binary` | no | no | absent from cache [landscape] |

PLS needs ES 3.0, so ES 2.0 has none. Its analogue is framebuffer fetch [landscape].

### 2.5 GLSL ES 1.00 limits

- The language is not float-only. `int` is a type with arithmetic. The spec says integers may be converted to floats and
  that they need not map to hardware integers (section 4.1.3, p.19) [compute, local PDF].
- Bitwise operators, `%`, shifts and their assignment forms are reserved (section 5.1, p.40). `half`, `fixed`,
  `unsigned`, `long` and `short` are reserved keywords (section 3.7, p.17). So the bitwise operations are blocked by the
  language, not by hardware [compute].
- Loops and indexing follow Appendix A, sections 4 and 5. air2es's checker implements them [air2es].

### 2.6 Compute on SGX5: vendor claims against evidence

- 2009, Khronos on SGX543MP: the cores "support Khronos APIs including ... OpenCL". This is a claim, not a conformance
  result [landscape, snippet].
- 2011, Khronos: Imagination "has submitted POWERVR SGX drivers for OpenCL 1.0 Embedded Profile conformance". No core is
  named and Apple is not mentioned [compute, fetched].
- 2013, Imagination blog: OpenCL on Series5XT. Its demos name the SGX544SC, and no SGX543 device is named [landscape,
  fetched].
- 2014, Imagination forum: staff say the SGX544MP "hardware is capable of supporting the API", and that exposing it is the
  customer's decision [landscape, fetched].
- 2014, ODROID-XU (Exynos 5410, SGX544MP3), a device dump: OpenCL 1.1 Embedded Profile, one compute unit, maximum
  work-group size 1, 1 kB local memory, 64 MB maximum allocation, no double. Staff: "From OpenCL's point of view,
  Series5XT GPUs only have one logical core" [landscape, fetched]. This is third-party device output, not our hardware.
- No OpenCL device was found for SGX543 (iPad 2, iPhone 4S) or for the Vita. The iOS 6.1.3 OpenCL is CPU-only
  [compute, teardown]. The Khronos conformant-products list read so far has ten PowerVR entries, all OpenCL 3.0, with no
  SGX entry in the part read [landscape].
- Imagination staff (2018): SGX543 and SGX544 share an instruction set "for debugging and profiling purposes" [sweep,
  fetched]. This does not say the encodings match.

**Verdict:** SGX5 did run GPU compute, but only in vendor Android stacks, and the device evidence is for SGX544. SGX543 is
unverified, not disproved. Its OpenCL is inferred from the product family, and nothing was found.

### 2.7 Telegram's metal library, measured

Measured on the oracle file, Telegram's `default.metallib` (air64, 15 modules) [air2es]:

- **11 of 14 render functions translate**, pass the Appendix A checker and pass glslangValidator in ES mode: basic_vertex,
  edgeTestVertex, matrixVertex, post_vertex_main, twoInputVertex, vertexPassthrough, edgeTestFragment, fragmentPlain,
  basic_fragment, scaleAndBlur and transformAndBlend.
- **3 are refused by name** for the constexpr sampler: fragmentColorConversion, matrixFragment and post_fragment_main.
  Their sampler constants differ only in the low 16 bits. Two values cannot establish the layout, and no published
  layout was found.
- **post_fragment_main** also has a nested loop whose back edge the structurer refuses. This comes from reading the CFG,
  not from a run.
- **compute_main is a kernel that belongs to air2cpu.** Nothing in the five notes reads its contents [air2es].
- Telegram's compute use beyond `compute_main` is unverified. The Telegram checkout in the workspace has no `.metal`
  files, and GitHub code search gave no evidence [compute].

## 3. v1 scope

**In v1:** Metal render through air2es, as normal backport work.

What remains to finish render, from air2es's NOTES [air2es]:

1. **Constexpr sampler.** Derive the table. That needs a Mac with Xcode, to compile known constexpr samplers with
   `xcrun metal` and map each configuration to its constant. The Mac used has only the Command Line Tools, which have no
   Metal compiler. The loader also has no sampler field yet.
2. **Limits of the target.** GLES 2 has no mirrored repeat, and repeat wrapping needs power-of-two textures. Some decoded
   configurations will still be refused by name.
3. **post_fragment_main's nested loop.** Once the sampler is resolved, the structurer's refusal of the back edge needs a
   fix. This is from the CFG, not a run.
4. **Device checks owed.** The `fmod` lowering runs its quotient at mediump, so large quotients can lose integer
   precision. The blur accumulators (vec4 sums of 61 samples at mediump) need checking against Metal's output. The
   `[[position]]` flip is derived from the encoder and unverified. None of these has run on a device.
5. **Device proof for the 11 shaders.** No note records a device run of them.
6. **The harness and CI.** `air2es_check.lua` checks a folder, and its 15 cases run as the `air2es` backports suite.
   The harness runs on Telegram's external oracle file, so it is not in CI. Whether it may run in CI is an owner decision.
7. **Design constraints already in place.** Fragment shaders use `precision mediump float;`, as the loader requires.
   Half-precision vertex attributes are refused. Internal helpers are inlined. Constant tables read at variable indices
   become select chains.

**Not sourced:** "telegram-build wiring" is not in air2es's NOTES or in any of the five notes. It is needed before v1
ships, but its steps must come from the owner or the coordinator. This document does not invent them.

**Out of v1:** all compute, including `compute_main`, which air2es's notes place with air2cpu.

## 4. v2 backlog

Each entry gives what it is, its cost, its odds, what it needs to start, and where it stands.

### 4.1 Fragment-GPGPU compute subset (recommended v2 start, no driver)

- **What.** A kernel is one ES 2.0 fragment shader. Inputs are textures, at most 8 units. The output is one attachment,
  because there is no MRT. Loops have constant bounds, checked the way air2es's checker checks them. The output format is
  RGBA16F where `EXT_color_buffer_half_float` gives a complete framebuffer, and RGBA8 packing elsewhere [compute].
- **Maps.** Map. Convolution and blur, where a separable blur splits into two passes (whether Telegram's 61-sample blur
  is separable is unverified). Reduction trees and scans in log passes. Sorting networks through gather. Histograms
  through points and blending, with accuracy measured first. Per-pixel read-modify-write through framebuffer fetch, for
  one attachment [compute, landscape].
- **Does not map.** Atomics that return a value. Shared memory, barriers and workgroups; multi-pass draws stand in for
  barriers between passes. Scatter to GPU-computed addresses; points at CPU-supplied positions work, and addresses can be
  precomputed on the CPU. Bitwise and integer-heavy kernels, which are emulated in float and are exact only inside the
  mantissa, and slow. 64-bit integers and doubles. Float32 render targets. Several outputs in one pass. Counting passing
  fragments, since occlusion query gives only a boolean, and only on 543/554 [compute, landscape].
- **Cost.** Low to medium: a library, plus a before-and-after measurement per kernel, which ADR 0014 requires. No driver
  work.
- **Odds.** High for map, gather and reduction. Medium for kernels bound by exactness. Low for scatter-heavy kernels.
  Performance is unmeasured on SGX5.
- **Needs to start.** (a) Device probes: GL_EXTENSIONS, GL_FRAGMENT_PRECISION_HIGH, GL_NUM_SHADER_BINARY_FORMATS, and an
  RGBA16F completeness and blend test. (b) A target kernel. `compute_main` is unread, so the first target must be chosen
  from the owner's list. (c) The packing scheme measured on the device. (d) Trompouki and Kosmidis (DATE 2017) and Brook
  GLES Pi (HPG 2018) as read-only method references; their numbers were not checked [landscape].

### 4.2 Oracle chain: validators, SGX profiler, device truth

- **What.** Three steps. (1) Validate the GLSL that air2es and the fragment-GPGPU library emit, with glslang and with ANGLE's
  translator, both as independent checks of GLSL ES 1.00. (2) Estimate cost with the vendor's offline profiler, which
  gives per-line cycle counts for Series5 and Series5XT parts (PVRShaderEditor and PVRUniSCo). (3) Measure on the device,
  as ADR 0014 requires [landscape, compute, sweep].
- **Cost.** Low for the validators. Medium for the profiler, which must first be obtained.
- **Odds.** Medium. Open: whether a Series5XT-capable build is still downloadable and runs on macOS. The Imagination
  replies say the SDK compiler writes no device binaries, so the profiler gives estimates only [sweep].
- **Needs to start.** Confirm the profiler's availability. Read glslang's per-file licences (BSD-3 for most, with GPL-3
  and MIT exceptions) and ANGLE's LICENSE. Keep the profiler's use within the PowerVR Tools EULA: "developing, profiling,
  or assisting", with no disassembly [sweep].

### 4.3 SwiftShader as a Mac-side Vulkan compute reference

- **What.** The vendored SwiftShader (Apache-2.0) builds `libvk_swiftshader.dylib` for `macosx|arm64`, for the emulator's
  host path. Use it to check a SPIR-V compute kernel's output on the Mac [landscape].
- **Not a device path.** There is no iOS or armv7 build. It takes SPIR-V, and we produce none. The only AIR-to-SPIR-V
  candidate found, Iridium in darlinghq/indium, has an unverified licence. Its JIT needs executable memory on the device,
  which is unverified. One anecdote reports compute several times slower than single-core C [landscape].
- **Cost.** Low, since it is vendored. **Odds.** Good as an oracle, poor as a device path.
- **Needs to start.** Nothing for Mac use. For a device path: an armv7 build, a SPIR-V producer, and a JIT check.

### 4.4 CPU compute on NEON or Accelerate

- **What.** Kernels that do not fit the fragment shape run on the A5 CPU. `Accelerate.framework` is in the 6.1.3 extract,
  and the dyld cache has `vDSP_vadd` (6 string hits) and `vImage` (24 string hits) [landscape, static]. Kernels that map
  to vDSP or vImage need no JIT.
- **Cost.** Per kernel. **Odds.** Feasible. The best next CPU route, by the compute note [compute].
- **Peak estimates (unverified).** The GPU's 12.8 GFLOPS assumes a 200 MHz clock that is itself unknown. The CPU's about
  8 GFLOPS at 1 GHz is an estimate, not a measurement. Both are upper bounds only [landscape].
- **Needs to start.** Measure both paths on an iPad 2 before choosing per kernel.

### 4.5 GL user client (type 0) compute, through the kernel service's external methods

- **What.** The one kernel route the phone already runs. Test whether the GL user client's selectors accept a program
  and a buffer. The selectors are known only by number [probe].
- **Cost.** Medium to high: reverse engineering of the kernel service, and it is gated by the iOS licence (section 5.2).
- **Odds.** Low. The selectors are named by number only, and no selector is known to take a program.
- **Needs to start.** The owner's licence decision. Then the kernelcache, decrypted with the teardown's method, and
  `SGXDriver543`'s `newUserClient` switch and external-method table [probe, teardown].
- **Status.** v2-or-never.

### 4.6 Unrun device probes (no reverse engineering needed)

- **What.** The GL queries the probe did not run: GL_EXTENSIONS, GL_NUM_SHADER_BINARY_FORMATS, GL_FRAGMENT_PRECISION_HIGH,
  and the RGBA16F render and blend test. Run them on an iPad 2 (iPad2,2 is free) and an iPad 4, and repeat the type 3
  refusal on the iPad 2. The iPad 3 has not been run. The iPad 4 runs iOS 10.3.4, and that image was not fetched, since
  firmware-tools decrypts iOS 2 to 9 only [teardown, probe].
- **Cost.** Low, through the device-session skill. **Odds.** The binary-format count is expected to be zero, since the
  cache names no binary path. The highp answer is open. Neither has been measured.
- **Needs to start.** The device session. These queries need no disassembly, so they do not touch the licence question.

### 4.7 Custom SGX driver (multi-year research)

- **What.** Replace the closed GL and compute userspace with our own driver.
- **Gates.** (1) The command stream (TA, ISP, PDS, USSE state, textures) is not documented anywhere found. (2) The kernel
  and firmware interface is closed in every source, and `SGXDriver543`'s method table has not been read. (3) GPU memory
  and the MMU are closed; under sceGxm the Vita hides them completely. (4) The USSE ISA is partly public: Vita3K covers
  SGX543MP4+ (GPL, partial, loops do not translate) and linux-sunxi covers SGX544MP (snippet). (5) A shader compiler from
  GLSL or AIR to USSE. (6) Device validation on a jailbroken iPad 2, where GPU hangs may need a reboot (unverified)
  [teardown, landscape].
- **Cost.** Multi-year. **Odds.** Very low, in any timeframe this project can justify.
- **Needs to start.** The cheapest observable step is a trace of the closed IMGSGX driver's IOKit external-method
  payloads into the 543 kext, to see whether command words travel in them. The premise is unverified. The trace is gated
  by the licence (section 5.2). The probe's trace already logged payloads on GL types 0 to 2 (section 2.3). It did not
  read command words from them, so the question stays open.
- **Status.** v2-or-never.

### 4.8 A third-party plugin into iOS 6's OpenCL.framework

- **What.** The `cvmsConfig` plugin mechanism. `libCLVMCPUPlugin.dylib` is the CPU plugin. A GPU plugin would be a route
  only if the loader accepted one [landscape, static].
- **Cost.** Unknown. It needs a read of the loader, which is a private interface. **Odds.** Unknown; unexplored.
- **Needs to start.** The owner's licence decision, because reading the loader is reverse engineering of iOS software.

### 4.9 Dead or closed leads: recorded so they are not run again

- **Program binaries through the GL driver.** The driver advertises no binary path (static strings). The SDK's offline
  compiler writes no device binaries, per vendor staff in 2010, 2016 and 2018, and Imagination's own iPhone header bars
  binary shaders. Only the device's driver writes binaries, in an undocumented format. The device check in 4.6 settles
  this on the device [landscape, sweep].
- **Lifting 9.3.6's IOAccel compute to 6.1.3.** 9.3.6's CL wrapper uses type 4. The 6.1.3 kernel refuses type 4 as well,
  so a lifted userland has no kernel path [teardown, probe].
- **Vita: sceGxm and vitaGL.** vitaGL is an open GL subset that runs above closed sceGxm. It has no compute. It is not a
  path on iOS [landscape].
- **openpvrsgx.** A GPL Linux kernel module over closed userspace. Not for iOS [sweep].
- **Mesa `pvr`.** Rogue only. The docs say Series 5 and SGX parts cannot be supported by it [sweep].
- **Leaked material.** Not a lead. See section 5.1.

### 4.10 Not in this backlog

The coordinator's brief listed an "AsyncDisplayKit 4th-member a11y note". None of the five notes mentions AsyncDisplayKit
or accessibility, so there is no entry. The owner should say whether it belongs here.

## 5. Legal and licence

### 5.1 Forbidden: leaked material

- Leaked PowerVR DDK and driver code, and leaked Apple source, are **never opened**. The notes name them only: the leaked
  Cedarview DDK 1.8, and a Phoronix item on a leaked PowerVR SGX driver. Neither was opened [sweep, landscape].
- **Conflict to resolve.** AGENTS.md says "leaked source is read for behaviour and never copied". The owner's rule, which
  this document follows, says leaked material is never opened. The owner should confirm which governs.

### 5.2 Device work on the owner's hardware

- **The iOS licence.** Section 2(c) of the iOS 6 Software License Agreement prohibits copying, decompiling, reverse
  engineering, disassembling, or deriving the source of the iOS Software, except where applicable law or open-source
  terms allow it [landscape, fetched]. Whether the exception applies is for the owner to decide. This is not legal advice.
- **The device trace.** The probe hooked IOKit calls on the iPhone 4S with Substrate, six times, on 2026-10-28 [probe].
  The re-landscape note says no device-side trace should run until the owner decides [landscape]. No owner decision is
  recorded in any note. This is an open decision.
- **Disassembly.** Teardown disassembled Apple's images, and the probe disassembled Mercury's bytes from the phone with
  `rasm2`. Under section 2(c) that disassembly looks like the same category as the trace. The notes gate only the trace.
  The owner should decide about the disassembly too.
- **Probe artifacts.** The gpu_probe code (section 7) is a reverse-engineering tool against iOS software. It stays
  disabled. Building or running it waits for the owner's decision in this section.
- **Scratch.** The probe says it wrote its files to `/tmp` on the phone and removed them afterwards [probe]. AGENTS.md says
  `/tmp` is not used. This is recorded here, not fixed.

### 5.3 Licence triage of the resources (from the open-code sweep)

Classes: **(a)** usable, within the licence's stated limits. **(b)** read for method only; never copied. **(c)**
forbidden, never opened.

| Resource | Licence | Class | Use |
| --- | --- | --- | --- |
| PowerVR Native SDK | MIT, per Imagination's EULA page | (a) | framework and examples; the program-binary example was not opened |
| PowerVR SDK offline compilers (PVRShaderEditor, PVRUniSCo) and PowerVR Tools EULA | EULA: developing and profiling only; no disassembly or RE; redistribution only inside an application | (a), with limits | the profiler in 4.2 |
| PVRTexTool, PVRTexLib | PowerVR Tools EULA | (a), with limits | PVRTC textures only; shipped products carry an acknowledgement |
| SwiftShader | Apache-2.0 | (a) | already vendored (macOS arm64 host build) |
| glslang | BSD-3-Clause for most files; GPL-3 and MIT exceptions | (a) for BSD files | a tool; check each file's licence before any vendoring |
| ANGLE shader translator | BSD | (a), subject to its LICENSE file | a second GLSL ES validator. Its LICENSE file was not read |
| Mesa core | MIT | (a) | Mesa `pvr` is Rogue only |
| Lima (Mesa, Mali) | code (a); method (b) | (a) code, (b) method | method only |
| rnndb and freedreno register database | MIT-style header (snippet) | (a) for freedreno; envytools licence unverified | the technique of describing registers in XML |
| Vita3K | GPL-2.0 | (b) | read for the USSE disassembler's method |
| vitaGL | LGPL-3.0 and GPL-3.0 | (b) | read only |
| psvgxp | no licence; all rights reserved | (b) | method only |
| openpvrsgx kernel | GPL | (b) | read only |
| linux-sunxi wiki | CC-BY, per a snippet of a New Device page; `sunxi:Copyrights` not read | (b) until the licence page is read; facts can be cited | SGX544 USSE facts |
| FSF and openpvrsgx community list, 2012 | list post | (a) to cite | one fact about USSE opcode names |
| Imagination Series 5 Architecture Guide | Imagination; official copy not fetched | (a) to cite | concepts only, not command words |
| Imagination Rogue ISA reference | Imagination | (a) for Rogue | not applicable to SGX |
| US10579381B2 (Imagination, variable-length encoding) | patent | (b) | public text, but a patent is not a licence to implement the method. No PowerVR or USSE mention in the text read |
| US8134566, US8154554 (NVIDIA) | patent | (b) | not PowerVR |
| Brook (BSD upstream with GPL parts, snippet); the lkosmid fork | unverified | (b) until read | fragment-GPGPU method reference |
| Iridium (darlinghq/indium) | unverified | (b) until read | AIR-to-SPIR-V candidate |
| Leaked PowerVR SGX driver item; leaked Cedarview DDK 1.8 | leaked | **(c)** | never opened |

The PVRTgles3Ext.h header vendored in SwiftShader is an SDK header with no licence header. It was read for one fact (the
iPhone binary-shader rule) and not copied. The sweep did not classify it.

## 6. Consolidated open questions

Deduplicated across the five notes. Each is unverified unless it says otherwise.

### 6.1 Settled on a device by a run that would be cheap

1. GL_EXTENSIONS, GL_NUM_SHADER_BINARY_FORMATS and GL_FRAGMENT_PRECISION_HIGH on an iPhone 4S, an iPad 2 and an iPad 4.
   The probe printed none of them.
2. RGBA16F as a complete, blendable render target on the SGX543 (the guide says yes; untested).
3. Vertex texture fetch at run time on iOS 6 (the guide says 0).
4. Whether the GL user client (type 0) accepts compute-style external methods.
5. The meaning of `gldCreateQueue`'s `r3`, and of `gldCreateContext`'s `a2` and `*a3` (0x20). Only `r3 = 0` was tried.
6. Why each external method appears twice in the trace.
7. Whether a signed, entitled app gets a different answer from `SGXDriver543` for type 3. The probe was unsigned and ran as root.
8. Whether the stub at `0x49a8` in Mercury is `IOAccelCLContextCreate`. It is inferred from the trace window and the NULL
   branch, not verified.
9. The type 3 refusal and the GL queries on the iPad 2 and the iPad 3.
10. The SGX543 core count, read on a device. MP2 is secondary.
11. The air2es precision, blur and flip checks, on a device.
12. Whether a jailbroken iOS 6 device allows executable memory (for the SwiftShader JIT).

### 6.2 Settled by a source, not a run

13. Whether SGX543 silicon has integer ALUs, atomics or hardware shared memory. The 1 kB local memory on SGX544 is not proof.
14. Whether SGX543, SGX554 and SGX544 share instruction encodings. The staff statement covers the ISA for debugging only.
    Whether USSE2 (a Series5XT extension, per a press snippet) changes the encodings is unchecked.
15. Whether any SGX543 OpenCL existed in a vendor stack. Nothing was found.
16. The stock Samsung OpenCL on the Exynos 5410 Galaxy S4. Only third-party and ODROID-XU evidence exists.
17. How `gldCreateContext` resolves by name (the lookup handle and its search scope). The callers of Mercury's
    `gldCreateQueue`, which the teardown did not find in the extracted set and did not search through the full dyld link
    graph. The caller of `libGPUSupport.dylib`'s raw-IOKit `gldCreateQueue`, and its SGX543 build.
18. The 6.1.3 SGX543 OpenCL device list (only the `IOAcceleratorES` literal was checked). The branch in 9.3.6's OpenCL
    that is gated on that literal, and where it leads.
19. A full body diff of `IMGSGX543` between 6.1.3 and 9.3.6 (not done; export overlap only).
20. The kernel symbols. The kernelcaches were checked for strings and Mach-O validity, not symbolicated.
21. The contents of Telegram's `compute_main` (air2cpu), and whether Telegram's 61-sample blur is separable.
22. The iPad 4's release history on iOS 6 (general knowledge only), its iOS 10.3.4 image, and whether SGX554 shares the
    SGX543 instruction set (only "Series5XT family" from a snippet).
23. The Vita: the last 15,600 characters of the sceGxm header (unread); the Vita3K opcode table (`usse_opcodes.inc`, 404
    at the path tried); the Henkaku SGX543 page (not reached); the closedness of `libshacccg`.
24. The linux-sunxi `SGX544MP/USSE_ISA` page: its FRC and RSQ encodings (403, twice) and its licence (`sunxi:Copyrights`).
25. The Series 5 Architecture Guide beyond snippets (the official copy was not fetched).
26. Whether the PowerVR Series5XT offline compiler is still downloadable, runs on macOS, and still reports SGX cycle
    counts.
27. Whether the iOS 6 OpenCL loader accepts a third-party plugin.
28. SwiftShader on ARM32 in 2026, its code-generation path, and its compute speed on the A5.
29. The A5's real NEON throughput. The 8 GFLOPS figure is an estimate.
30. The Apple TV 2013 revision's GPU core count.
31. The performance of every fragment-GPGPU pattern on SGX5. Nothing is measured.
32. Half-float blending into RGBA16F on SGX5. The extension text gives the generic clamp rule only.
33. The Native SDK's program-binary example (not opened).
34. Whether US10579381B2 or any other patent restricts a method we might use. Not analysed. A patent is not a licence.
35. The licences of glslang per file, ANGLE's LICENSE, envytools, Iridium, the Brook fork and the linux-sunxi wiki.
36. Whether the iOS 6 licence's "applicable law" exception applies to the owner. Not analysed.

### 6.3 Decisions that only the owner can make

37. Whether the probe's device trace (section 5.2) is covered by the iOS licence, and whether it stands.
38. The same question for the disassembly already done on Apple's images (teardown, and the probe's Mercury bytes).
39. Whether leaked material is governed by AGENTS.md ("read for behaviour") or by the owner's rule ("never opened").
40. Whether the air2es harness may run in CI (its oracle is external).
41. The "telegram-build wiring" steps, which no note records.

### 6.4 Reconciliation: where the five notes disagree

- **R1. Kernelcache (unresolved).** Teardown reports a decrypted and decompressed iPad2,1 6.1.3 kernelcache. Re-landscape
  and compute say the extract holds none. The teardown does not record the file's path. The disagreement stays open.
- **R2. Which driver the iPad 2 uses (resolved).** Re-landscape called it unresolved, because the repo's cache holds only
  IMGSGX535. Teardown read the iPad2,1 root's own dyld cache and found `IMGSGX543GLDriver`. The repo's `.cache/dyld/6.1.3`
  is the SGX535 build, so the two notes read different images. Resolved in teardown's favour by build identity. Not
  re-checked here.
- **R3. The probe code is "uncommitted" (resolved).** The probe note says so, but commit 15f69b10d on `metal-device-probe`
  holds the probe code and its targets. This document copies them byte-for-byte.
- **R4. The air2es NOTES "not found" (resolved).** Compute and re-landscape could not find the file. It is on the `air2es`
  branch, at commit 46561c85d. Section 2.7 uses it.
- **R5. The kernel service name (resolved).** Teardown could not name the kernel service. The probe names it as
  `SGXDriver543` on the device. Teardown never searched for that name.
- **R6. A device trace against the licence gate (unreconciled; owner).** The probe ran a trace. Re-landscape says no trace
  should run until the owner decides. See section 5.2.
- **R7. `compute_main` in the staged plan (resolved as scope).** Compute's plan said to decode `compute_main` as part of
  the air2es stage. air2es's NOTES place it with air2cpu, so it is out of v1. Its contents are still unread.
- **R8. The probe did not measure the planned queries (a gap, not a contradiction).** Re-landscape asked for
  GL_EXTENSIONS, GL_NUM_SHADER_BINARY_FORMATS and GL_FRAGMENT_PRECISION_HIGH. The probe's measured output has none of
  them. Section 4.6 carries them forward.
- **R9. "Dead end" against "not practical" (resolved).** Compute called the driver route a dead end. Re-landscape softened
  this to "too strong" and "not practical". This document uses the softer verdict, and the device result (the compute
  queue is refused) supports it for the CL path.
- **R10. SGX543 core count (unresolved).** MP2 is secondary, from snippets. The device did not report its core count.

## 7. The probe code and its targets

The probe's three sources are kept byte-for-byte from commit 15f69b10d, as a disabled v2 artifact:

- `frameworks/Backports/tests/gpu_probe/gltrace.c`: the IOKit trace library. It is hooked with Substrate's
  `MSHookFunction`, loaded from `/usr/lib/libsubstrate.dylib`.
- `frameworks/Backports/tests/gpu_probe/probe.m`: the GLES2 baseline.
- `frameworks/Backports/tests/gpu_probe/queue.m`: the symbol dump and the queue probe.

Their targets are `MetalDeviceTrace`, `MetalDeviceProbe` and `MetalQueueProbe` in `frameworks/Backports/xmake.lua`. All three
are `set_default(false)` and sit inside the `iphoneos` branch, so a default or host build does not compile them. Building
or running them waits for the decision in section 5.2. The sources carry no comments, as ADR 0006 requires.
