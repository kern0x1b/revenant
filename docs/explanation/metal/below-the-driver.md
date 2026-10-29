# Below the driver: the SGX543 GL path on the iPhone 4S

Status: research, 2026-10-29, pass 1 for the coordinator. It answers questions 1 and 3 of the brief from the
firmware, statically, and sketches 2, 4 and 5. Nothing ran on a device, in CI, or in any build. No disassembly was
run. Nothing in it is a decision. It sits beside [Metal on iOS 6](../backports/metal-on-ios6.md) and
[the GPU-driver landscape](../backports/metal-v2-driver-re-landscape.md), which it extends.

## 1. The answer in brief

- **The stack is ten layers, not four.** The brief's chain (OpenGLES, GLEngine, the driver plugin, IOKit, kernel)
  is right in order but leaves out the plugin loader, the GLSL front end, Mercury (the device and submission layer),
  and the IOAccelerator user-client library. The kernel extension is named by the probe and is not in the firmware
  copy we hold.
- **Apple's shader compiler is in-process.** Its GLSL ES front end is `libGLProgrammability`. Its SGX543 USSE back
  end is inside `IMGSGX543GLDriver`. No image on the GL path imports Mach IPC.
- **No binary path is offered to apps.** No ES program-binary entry point and no binary format name exist in any of the
  4S images. The dossier's negative (4.9) holds on the 4S, which the old cache could not show.
- **The driver keeps compiled programs.** It has a program cache keyed by SHA-256, stored through `fscache`, and a
  writer and loader for compiled compute programs. Whether a GL program lands on disk is inferred, not observed.
- **Reuse of Apple's compiler offline is plausible, not shown.** The compile path has no IPC and the kernel is not on
  it, but the call graph that would prove it needs disassembly, which is gated (section 9).
- **Provisional verdict:** (a) first, then (b) only if the measurement in section 6 says GLEngine and the plugin loader
  carry the cost. (c), a full driver, is not justified now (section 7).

## 2. Method, evidence labels and limits

- **Source image.** The repository's `.cache/dyld/6.1.3` is an `iPhone2,1` cache (the iPhone 3GS, SGX535), so it cannot
  answer for the 4S. Every static result here comes from the 4S's own image: `iPhone4,1` 6.1.3 build 10B329, held in
  `.cache/firmware/rootfs/iPhone4,1/6.1.3_10B329`. Its dyld cache has 524 armv7 images.
- **How the tables were read.** The repository's dyld reader (`toolchain/modules/apple/dyld.lua`, `open_cache` and
  `extract`) pulled 18 images out of that cache by install name. Each was read with `otool -L` (linkage), `nm -gU` and
  `nm -u` (exports and imports), and `strings -a -n 6`. Every import was bound to the image that exports it. The
  scripts and the extracted files live in `.cache/scratch/gpu-lowlevel`, not in the repository.
- **Labels.** [static] means read from those tables or strings. [rootfs] means a file in the firmware copy. [probe] is the
  dossier's device result, not re-measured here. [inference] means reasoned from names or import patterns, with no code
  read. [device] means measured on the phone; none in this pass.
- **Licence gate.** The brief directs static reading of the shipped images. Dossier section 5.2 still lists two owner
  decisions as open: items 37 (the device trace) and 38 (disassembly of Apple's images). This pass reads symbol tables
  and strings only. Anything that needs code reading waits for the owner (section 9).
- **Excluded by rule.** The `GPUSupport.framework` folder in the firmware copy holds a source-tree folder and build
  and export resources. They are excluded under the leaked-source rule. One directory listing showed their names; none
  was opened, and nothing from them is used here. The `.exp` lists in `OpenGLES.framework` were not read either. Their
  symbols come from the binaries' own tables.

## 3. Question 1: the stack, from an app's `glDrawElements` to the GPU

### 3.1 The layers

| Layer | Image (install name in the 4S cache) | What its tables say | Calls down to |
| --- | --- | --- | --- |
| 0. App | none | calls `glDrawElements` and `glDrawArrays` | OpenGLES |
| 1. GL ES API | `/System/Library/Frameworks/OpenGLES.framework/OpenGLES` | 368 exports. Imports `dlopen`, and carries the path string `/GLEngine.bundle/GLEngine`. Links libGFXShared, IOAccelerator, IOSurface, IOMobileFramebuffer and AggregateDictionary [static] | GLEngine (by `dlopen`), libGFXShared |
| 2. GL state machine | `.../OpenGLES.framework/GLEngine.bundle/GLEngine` | 20 `gli*` exports: context, drawable, present, swap, pixel formats, renderer info. Also exports `glShaderBinary`. Of its 230 undefined symbols, 85 resolve to libGLProgrammability, 41 to libGFXShared, 15 to IOSurface, 10 to libGLImage and 8 to libCVMSPluginSupport. It names no driver symbol [static] | libGLProgrammability, libGFXShared |
| 3. Plugin loader | `.../OpenGLES.framework/libGFXShared.dylib` | 72 `gfx*` exports: shared state, a plugin registry (`gfxGetPlugins`, `gfxGetPluginWithDriverID`), plugin textures and buffers. Imports `dlopen`, `dlsym` and CFBundle lookups. Its strings give the bundle path `/System/Library/Extensions/<name>.bundle/<name>` [static] | the driver bundle (by `dlopen`), its entry names by `dlsym` |
| 4. GLSL ES front end | `.../OpenGLES.framework/libGLProgrammability.dylib` | 176 exports: the `Sh*` compile and link API, `PPParser*` and `PPStream*` (the parsed program stream), and `glpPPShaderLinearize*`, which the driver imports. Its strings name `GLSLBuiltins.ES2.glpa`, a 17 KB file in OpenGLES.framework whose magic is `glpA` [static, rootfs] | libGLImage (7), libCVMSPluginSupport (6), IOSurface (5), resolved imports |
| 5. CVM hash helpers | `.../OpenGLES.framework/libCVMSPluginSupport.dylib` | a cvm hash set and hash machine. Three imports and no IPC. The GL images import only its hash calls, not its build or JIT calls [static] | none |
| 6. SGX543 driver | `/System/Library/Extensions/IMGSGX543GLDriver.bundle/IMGSGX543GLDriver` | 74 exports: `gldCreateDevice`, `gldCreatePipelineProgram`, `gldCompileComputeModule`, `gldPopulateContextDispatch`, `gldWriteComputeProgramBinary`, and the `glrComp*` compute set. The USSE back end: the strings "Error generating main USSE code", "...subroutine USSE code" and "...SA-update USSE code". PDS constant limits. SGX feature and erratum flags. `SGX_MAX_SHADER_CACHE_SIZE` and `SGX_MAX_STREAM_CACHE_SIZE`. 135 undefined symbols [static] | resolved imports: Mercury (33), IOSurface (12), IOAccelerator (10), libCoreFSCache (7), IOKit (6), libGLProgrammability (3), libGLImage (3) |
| 7. Mercury, the device and submission layer | `/System/Library/PrivateFrameworks/GPUSupport.framework/libGPUSupportMercury.dylib` | 138 exports. `gpum*` covers the device, pixel formats, queries, the program cache (`gpumGetCachedProgram`, `gpumDeleteCachedProgram`) and IO data. `gpus*` covers submission (`gpusSubmitDataBuffers`, `gpusGetKernelBufferResource`). 62 undefined symbols, 40 of them resolving to IOAccelerator [static] | IOAccelerator, IOSurface, libGLImage |
| 8. User-client library | `/System/Library/PrivateFrameworks/IOAccelerator.framework/IOAccelerator` | 100 exports: `IOAccelGLContextCreate`, `IOAccelContextSubmitDataBuffers`, `IOAccelResourceCreate`, `IOAccelSharedCreate`, and CL and video variants. Imports `IOServiceOpen`, `IOConnectCallMethod`, `IOConnectCallScalarMethod`, `IOConnectCallStructMethod`, `IOConnectMapMemory`, `IOConnectAddClient`, `IOConnectRelease` [static] | IOKit |
| 9. IOKit | `/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit` | the `IOConnect*` and `IOService*` calls | the kernel |
| 10. Kernel extension | the service `IOAcceleratorES` (and `IOAcceleratorESLegacy`), literal in OpenGLES [static]; class `SGXDriver543` [probe] | the kext is not in the firmware copy: the 4S rootfs kernelcache directory is empty, and the iPad 2 rootfs has none [rootfs] | not read |

Side paths that sit under the same layers:

- **libCoreFSCache** exports `fscache_*` (open, insert and retain, find, element data, remove, sync). It is a
  persistent element store with a "maps file" and hashed elements [static]. Only the driver imports it.
- **libGLImage** exports the `glg*` pixel conversions (`glgConvertType`, `glgGetPixelSize`,
  `glgProcessPixelsWithProcessor`). The GL front end, the driver and Mercury all use it [static].
- **OpenCL** is not on the GL path. It links libGFXShared, libCoreVMClient, IOSurface and `libcl2module`, and
  `libcl2module` links `libLLVMContainer`, an 11,611-export LLVM container [static]. The one symbol the GL images take from it, `_abort`, is re-exported by the container, so it is no GL dependency.

### 3.2 The seams

- **A (GLEngine to the front end):** direct symbol calls, 85 of them, in-process. Nothing to cross.
- **B (GLEngine to the driver):** dynamic. libGFXShared `dlopen`s the driver bundle and `dlsym`s its names. GLEngine
  imports no driver symbol by name, and the driver exports `gldPopulateContextDispatch`, which fits a dispatch table
  that the driver fills at context creation [inference from names and import patterns]. The GL images' string tables hold
  124 distinct `gld*` and `glr*` strings [static]. Among them are `gldWriteComputeProgramBinary` and `glrCompLoadBinary`,
  which libGFXShared carries.
- **C (driver to kernel):** the driver calls Mercury, which calls IOAccelerator, which calls IOKit. The driver also calls
  `IOConnectCallScalarMethod` and `IOConnectCallStructMethod` itself [static].

### 3.3 Where the shader compiler lives

- **Front end, in-process:** libGLProgrammability. It parses and links GLSL ES 1.00 and builds the PP stream. The
  `Sh*` names follow the public ANGLE and TI translator API [inference from names only].
- **Back end, in-process:** IMGSGX543GLDriver. It generates the main, subroutine and SA-update USSE code and the PDS
  constants, and it takes the front end's shader through `glpPPShaderLinearize` [static].
- **No daemon on the GL path.** No GL image imports Mach IPC. libCoreVMClient, the image that talks to
  `com.apple.cvmsServ` through `bootstrap_look_up2` and `mach_msg`, is linked only by OpenCL [static]. The daemon `CVMServer`
  (IOKit-linked) and the armv7 agent `CVMCompiler` (which links `libLLVMContainer`) are real binaries in OpenGLES.framework
  [rootfs]. They serve the CL side [inference from who links the client].
- **Where the output goes.** The driver keeps compiled programs through Mercury (`gpumGetCachedProgram`,
  `gpumDeleteCachedProgram`) on `fscache`. It imports the `CC_SHA256_*` calls, which fits hashed keys, and
  carries the limit constant `SGX_MAX_SHADER_CACHE_SIZE` [static, use inferred]. It finds a directory with `NSSearchPathForDirectoriesInDomains` [static]. That
  the directory is the app's Caches folder, and that a GL program's compiled code lands in it, is [inference].

## 4. Question 2: the user-client boundary (partly answered)

- **As the tables show it.** IOAccelerator is the one user-client library. Its call sites are `IOServiceOpen`,
  `IOConnectAddClient`, `IOConnectMapMemory`, `IOConnectCallMethod`, the scalar and struct variants, and
  `IOConnectRelease` [static]. Shared memory is handled through IOAccelerator's resource API (`IOAccelResourceCreate`,
  `IOAccelResourceGetDataBytes`) and IOSurface [static].
- **As observed on the 4S** (dossier 2.3, six unsigned runs as root, [probe], not re-measured): user-client types 0, 1 and
  2 open. Types 3 to 8 are refused with `0xe00002c7`. Selectors seen: type 0 uses 2 and 0; type 1 uses 0 and 2; type 2
  uses 1 and 7. Each call appears twice in the log, and the cause is not known.
- **Can an unsandboxed process open it directly?** On a jailbroken device the probe opened types 0 to 2 as root, unsigned.
  Whether the kernel checks entitlements for those types is not known, because the kernel side was not read. Open.
- **What is the minimum to submit work without GLEngine?** The path the tables show is IOAccelerator's context, then
  resource create, then submit data buffers, which ends in `IOConnectCallStructMethod`. The payload layouts and the
  selector table live in the kext, which is not in the firmware copy, so the minimum is not known yet (section 9).

## 5. Question 3: are Apple's compiled shader binaries reachable?

### 5.1 The public path is closed

- No ES program-binary entry point appears in any of the 4S images' export tables. There is no
  `glGetProgramBinary`, `glProgramBinary` or `glGetProgramBinaryOES` [static]. The only program-binary exports are the
  driver's `gldWriteComputeProgramBinary` and OpenCL's `gclBuildProgramBinaryAPPLE` [static].
- No binary-format token appears in any of the 18 images: no `GL_OES_get_program_binary`, `GL_IMG_shader_binary`,
  `SGX_BINARY_IMG`, `GL_NUM_SHADER_BINARY_FORMATS` or `SHADER_BINARY_FORMATS` [static]. The IMG extension names in the
  4S images are `GL_IMG_read_format`, `GL_IMG_texture_compression_pvrtc` and `GL_IMG_texture_format_BGRA8888` [static].
- `glShaderBinary` is exported by GLEngine [static]. With no format named anywhere, its accepted list is presumably empty
  [inference]. Its code was not read.

### 5.2 A binary exists inside the driver

- **Compute binaries.** The driver exports a writer and loader for compiled compute programs,
  `gldWriteComputeProgramBinary` and `glrCompLoadBinary` [static]. The GL side's string table names them. Whether a
  GL program ever reaches the writer is not established, and the call graph would show it (section 9).
- **The program cache.** The imports (`gpumGetCachedProgram`, `gpumDeleteCachedProgram`, the `fscache` set, `CC_SHA256_*`)
  and the config names (`SGX_MAX_SHADER_CACHE_SIZE`, `SGX_MAX_STREAM_CACHE_SIZE`) fit compiled programs being kept
  in a persistent, hashed store [static, inference on what it holds].
- **OpenCL's binary builder.** `gclBuildProgramBinaryAPPLE` is the CL path. It is not usable on the SGX543: the compute
  user-client type is refused [probe].

### 5.3 Reachability, and the test that settles it

- **Capture from the cache (inference, cheapest to test).** After a GL draw with a new program, the app's Caches
  folder should gain a file in the `fscache` format. The test uses only files our own app causes. It needs no hook into
  Apple's code and no disassembly, so it does not touch gate 37. It runs only on the phone, when the owner sequences
  it.
- **Offline reuse of Apple's compiler (inference).** The front end and the USSE back end are in-process libraries, with
  no IPC on the GL compile path. So a process that loads the two from the dyld cache could compile without the kernel
  or Mercury's submission. What the compile path still needs is unknown and must be read: (i) its call graph from the
  compile entry points (`gldCreatePipelineProgram`, `gldCompileComputeModule`); (ii) the device description. The driver
  reads it through `IORegistryEntryCreateCFProperty`, `IOServiceGetMatchingService` and `sysctl` [static]; (iii) the PP
  stream's layout, which is private.
- **Hybrid.** Skipping submission means writing our own command stream. That is the dossier's gate 1, and reusing the
  compiler does not remove it. So the shader half may be reusable, and the command half is not yet.

## 6. Question 4: the measurement design (not run)

The brief asks where the A5's CPU time goes per draw. The design keeps every step black-box, so it stays outside the
trace gate.

- **Probe.** One ARMv7 app, built with our toolchain, that calls only its own GL calls. No hook or patch goes into an Apple
  image. Run it on the owner's phone when the owner sequences it, under the device-session skill, with the claim
  mandatory. The phone is currently claimed by the paseo-ios6 worker.
- **Timing.** `mach_absolute_time` around each call, over 20,000 draws per configuration, five repeats, median and
  spread. Also `thread_info` CPU time, so that time blocked in IOKit is separated from CPU time.
- **Configurations.** C0 is a baseline draw with unchanged state. C1 switches between two programs per draw. C2 writes a
  uniform per draw. C3 alternates two textures on unit 0. C4 changes a vertex attribute pointer per draw. C5 toggles
  blend, depth and cull per draw. C6 is a draw with count 0, the call-overhead floor. C7 calls `glGetError` after each
  call. C8 switches between two framebuffers. All use one indexed triangle strip and a 256 by 256 target, with
  `glFinish` every 256 draws to bound the queue.
- **Attribution.** A sampler thread suspends the main thread about every millisecond, reads its program counter, and
  resumes it. The program counters are mapped to the symbol tables from section 2, so each sample lands in a layer:
  OpenGLES, GLEngine, libGFXShared, libGLProgrammability, the driver, Mercury, IOAccelerator or IOKit. The mapping is
  static, so no code is disassembled. Our own Metal frames, from `frameworks/Backports/src/Metal`, form their own bucket.
- **Output.** For each configuration: ns per call on the CPU, and the share of samples per layer. The cost of a state
  change is the difference from C0, split by layer. The layer whose share grows with the state change is the candidate
  for option (b).
- **Caveats.** The dossier's probe ran unsigned and as root. A signed app may get different answers (dossier 6.1,
  item 7). The A5 has two cores, and the samples cover only the main thread. Thermals can move the numbers, so repeats
  and spreads are part of the result.

## 7. Question 5: the verdict, provisional and ranked

The thresholds below are proposals to test, not measurements. Effort scale: S is days, M is weeks, L is months, XL is
years.

1. **(a) Stay on GLES2 and optimise our Metal layer.** Effort M. Pays off if the probe shows that our own bucket, plus the
   state-translation work in our layer, is a large share of the per-draw cost. It needs nothing from the licence gate.
   It is the default, because it is the only option whose cost is ours to cut.
2. **(b) Bypass one expensive layer, keeping Apple's compiler and kernel interface.** Effort L. The candidate is the
   GLEngine and libGFXShared dispatch and validation layer, reached through the driver's dispatch table. Pays off if
   those two layers carry most of the state-change overhead in C1 to C5 (a proposed bar: over 30 percent), and if the
   table's layout can be recovered and called from our process. Both need code reading, which is gated. The compile
   reuse of section 5.3 belongs here. It removes the front end's cost only if the measurement shows the compile is hot.
3. **(c) A full own driver.** Effort XL. The kext's method table, the command stream and the USSE encodings are all
   unread. The command stream is not documented anywhere the research found. Pays off only if (a) and (b) are capped
   below the target, the kernel interface proves simple, and the command stream can be read from shared memory. Not
   justified now.

Recommendation: do (a) now. Run the section 6 probe when the owner sequences it. Scope (b) only if its bar is met.

## 8. What this changes in the existing notes

- **The 4S binaries are now reachable.** The `.cache/dyld/6.1.3` used by the import check is the 3GS build. The 4S's
  own cache is in `.cache/firmware/rootfs/iPhone4,1/6.1.3_10B329`.
- **Dossier 4.9 holds on the 4S.** The binary-format absence was measured on the 3GS, and it is confirmed here on the 4S.
- **Dossier R5 is resolved on the 4S.** The kernel service literal `IOAcceleratorES` is in OpenGLES. The class
  `SGXDriver543` remains [probe].
- **Dossier R1 (the kernelcache) stays open.** The 4S rootfs has an empty kernelcache directory, and the iPad 2 rootfs has none.
- **The "cheapest observable step" in dossier 4.7 is cheaper for shaders.** The cache-folder test answers the shader
  question without the payload trace. The dump test in the landscape note still matters for the command stream.

## 9. Open items, and what the coordinator must decide

1. **The kernel extension.** The kernelcache is not in the rootfs, and `xmake firmware` does not fetch it. The IPSW
   would supply it, by byte range as the firmware tool does for the system image. Reading it is reverse engineering,
   so this needs the owner's decision (dossier 5.2, items 37 and 38) before anyone fetches or decodes it.
2. **The compile-path call graph.** Settling section 5.3 needs disassembly of the driver and the front end. That is
   item 38 again, and it waits for the owner.
3. **The device run.** The Caches-folder test and the section 6 probe need the phone. The coordinator sequences it.
4. **Where the document lives.** The brief gives `docs/explanation/metal/`. The sibling dossiers sit under
   `docs/explanation/backports/`. Metal is a part of the Backports component, so the coordinator may prefer the
   backports folder. This pass keeps the brief's path.
5. **The GPUSupport folder in the firmware copy.** It holds a source-tree folder. The coordinator should decide how
   that is to be handled, since the owner's rule is that leaked material is never opened (dossier 5.1).
6. **An unresolved role.** `libGPUSupport.dylib` exports the same `gpum*` and `gld*` names as Mercury, but no GL image
   links it. Its role is not established.
