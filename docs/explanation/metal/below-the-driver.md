# Below the driver: the SGX543 GL path on the iPhone 4S

Status: research, 2026-10-29, pass 2 for the coordinator. Pass 1 answered questions 1 and 3 of the brief from the
firmware, statically. Pass 2 takes the 4S kernelcache (section 2.1), reads the kernel extensions' names and strings,
and answers question 2 in part. Nothing ran on a device, in CI, or in any build. No disassembly listing was read.
Dossier items 37 and 38 are decided (section 2); the rest of this note is not a decision. It sits beside
[Metal on iOS 6](../backports/metal-on-ios6.md) and
[the GPU-driver landscape](../backports/metal-v2-driver-re-landscape.md), which it extends.

## 1. The answer in brief

- **The stack is ten layers, not four.** The brief's chain (OpenGLES, GLEngine, the driver plugin, IOKit, kernel)
  is right in order but leaves out the plugin loader, the GLSL front end, Mercury (the device and submission layer),
  and the IOAccelerator user-client library. The kernel extension is in the 4S kernelcache, which pass 2 obtained and
  decompressed: `com.apple.driver.IMGSGX543` (73.16.1), beside `IOAcceleratorFamily` (20.0.9).
- **Apple's shader compiler is in-process.** Its GLSL ES front end is `libGLProgrammability`. Its SGX543 USSE back
  end is inside `IMGSGX543GLDriver`. No image on the GL path imports Mach IPC.
- **No binary path is offered to apps.** No ES program-binary entry point and no binary format name exist in any of the
  4S images. The dossier's negative (4.9) holds on the 4S, which the old cache could not show.
- **The driver caches the linearized PP stream, not USSE code.** `_PrepareVendpipeprog` looks the stream up by a SHA-256
  key in `fscache` and stores it there on a miss. A writer and loader for compiled compute programs exist too. Whether
  a GL program lands on disk is inferred, not observed.
- **Reuse of Apple's compiler offline is not shown.** The driver's compile entries do no compiling in this build. The
  compile chain is in `libGLProgrammability`, and the USSE back end runs at draw time, inside the driver, with device
  state behind it (section 5.3).
- **The kernel checks the command stream.** The kext's assert strings name validation routines for vendor payloads and
  render commands (`copyAndValidateVendorPayload`, `validateRenderCommand`, `validateBind`), and the kext looks up the
  AMFI service. The routines were not read; the names are [static, strings only]. A command stream written from user
  space would meet these checks.
- **Provisional verdict:** (a) first, then (b) only if the measurement in section 6 says GLEngine and the plugin loader
  carry the cost. (c), a full driver, is not justified now (section 7). Pass 2 does not change this. It adds the kernel
  check above, which weighs against (c).

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
- **Licence gate.** The brief directs static reading of the shipped images. Dossier items 37 (the device trace) and 38
  (disassembly of Apple's images) are decided: the coordinator relayed the owner's instruction of 2026-10-29 to pursue the
  below-the-driver path and recorded both as decided by it. The iOS licence question (dossier item 36) is not analysed
  and stays with the owner. Pass 2 reads symbol tables, strings and load commands; it reads no code listing.
- **Excluded by rule.** The `GPUSupport.framework` folder in the firmware copy holds a source-tree folder and build
  and export resources. They are excluded under the leaked-source rule. One directory listing showed their names; none
  was opened, and nothing from them is used here. The `.exp` lists in `OpenGLES.framework` were not read either. Their
  symbols come from the binaries' own tables.

### 2.1 The 4S kernelcache (pass 2)

- **Source.** `kernelcache.release.n94` for iPhone4,1, iOS 6.1.3 (10B329), 7,754,020 bytes, an IMG3 container. It was
  fetched by byte range from Apple's IPSW with the firmware tool's new `kernelcache` action
  (`xmake firmware --device=iPhone4,1 kernelcache 6.1.3`). The file is in the shared cache, not the repository.
- **Decryption.** `ipsw img3 info` reads the tags: a `krnl` DATA payload of 7,751,607 bytes and two KBAG entries. The
  payload was decrypted with openssl (AES-256-CBC), using the published key and IV for this build. The first block
  decrypts to the `complzss` magic, which checks the key.
- **Decompression.** The `complzss` container has a 24-byte header: magic, an Adler-32 field, big-endian sizes
  (14,053,376 uncompressed, 7,751,223 compressed) and version 1. The decrypted blob was wrapped in a DER IM4P in scratch,
  and `ipsw kernel dec` (v3.1.739) decompressed it. The result is an ARMv7 `MH_EXECUTABLE` Mach-O of 14,053,376 bytes,
  SHA-256 `f4013bc0d9483418f57114c12e70763203d1b2726f749663458a322079f96ec9`. A hand-written LZSS decoder in scratch
  did not reach a valid Mach-O and was dropped; the tool's output is the one used.
- **Extraction.** `ipsw kernel extract` takes only MH_FILESET kernelcaches, and this one is prelinked, so the kexts were
  carved by address. A kext's file offset is 3,485,696 plus its load address minus `0x80394000` (the start of
  `__PRELINK_TEXT`); its size is the gap to the next kext's load address. Two kexts were carved, and both have Mach-O
  kext-bundle headers: `com.apple.driver.IMGSGX543` (73.16.1) at `0x809b4000`, 180,224 bytes, and
  `com.apple.iokit.IOAcceleratorFamily` (20.0.9) at `0x80997000`, 118,784 bytes. The kernel's own symbol table has 4,072
  exports and none from the kexts. The IMGSGX543 kext has 1,490 local relocations, and their targets are already
  resolved in the file.
- **Where it lives.** `.cache/firmware/kernelcache/iPhone4,1/6.1.3_10B329/`: `kernel.macho` and `kexts/`. Not in the
  repository.

### 2.2 What the kernel extensions say (pass 2, [static], from names and strings)

- **Classes.** IMGSGX543 names `SGXDriver543` (`initSGX`, `deinitSGX`, `setProperties`) and these C++ classes:
  `IMGSGXSharedUserClient`, `IMGSGXGLContext`, `IMGSGXChannel` with the 3D, TA and TQ variants, `IMGSGXResource`,
  `IMGSGXEventMachine`, `IMGSGXParameterBuffer`, `IMGSGXRenderTarget`, `IMGSGXStatistics` and `IMGSGXShared`.
  IOAcceleratorFamily names `IOAccelSharedUserClient`, `IOAccelContext`, `IOAccelResource`, `IOAccelEventMachine` and
  `IOAccelDevice`. The kernel exports the `IOUserClient` methods that dispatch external calls, at these addresses:
  `getExternalMethodForIndex` `0x80269e68`, `getTargetAndMethodForIndex` `0x80269e70`, `externalMethod` `0x8026d4e8`.
- **Property keys.** `setProperties` checks keys for `DisableChannelOverlap`, `EnableAutoClockGating`,
  `EnableDriverClockGating`, `ResetAveragePower`, `SetGPUPower` (with `PowerTarget`) and `SetPIControllerOverride`
  (checked against `MaxPower`). The kext's statistics use the names `AvgPower`, `AvgComputeClocks`,
  `CommandBufferSubmitCount` and others. `SGXDutyValues` and the `SGXParamBufferMin/MaxSize*` names are tuning values.
- **Validation and faults.** `IMGSGXGLContext` has `copyAndValidateVendorPayload`, `validateRenderCommand`,
  `processHardwareCommand` and `validateBind`, and the kext logs "too many TA Kicks". Fault messages name the
  microkernel lockup, the hang poll and the power-off register access.
- **Policy.** The driver logs "failed to look up AMFI service" and "failed to cast AMFI service". So it reads a service
  of the code-signing and entitlement subsystem. What it checks is not read.
- **The selector tables (pass 3, section 4).** Radare2's auto-analysis found no code references to the class-name
  strings, and `ipsw kernel cpp` finds no classes in the prelinked kernel. So the user-client vtables were found by
  scanning the kext's data for vtable runs, matching them against the kernel's `IOUserClient` slot layout, and then
  following the name-string references. The IMG table is recovered in full. The IOAccelerator tables are partly read.

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
| 10. Kernel extension | the service `IOAcceleratorES` (and `IOAcceleratorESLegacy`), literal in OpenGLES [static]; class `SGXDriver543` [probe, and in the kext's method names] | `com.apple.driver.IMGSGX543` 73.16.1 and `com.apple.iokit.IOAcceleratorFamily` 20.0.9 from the 4S kernelcache (section 2.1). The rootfs kernelcache directory is still empty [rootfs] | class, property and validation names, not the code (section 2.2) |

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
  constants, and it takes the front end's shader through `glpPPShaderLinearize` [static]. In this build the generation
  runs on the draw path, not in the driver's compile entries (section 5.3).
- **No daemon on the GL path.** No GL image imports Mach IPC. libCoreVMClient, the image that talks to
  `com.apple.cvmsServ` through `bootstrap_look_up2` and `mach_msg`, is linked only by OpenCL [static]. The daemon `CVMServer`
  (IOKit-linked) and the armv7 agent `CVMCompiler` (which links `libLLVMContainer`) are real binaries in OpenGLES.framework
  [rootfs]. They serve the CL side [inference from who links the client].
- **Where the output goes.** The driver caches the linearized PP stream in `fscache`, keyed by SHA-256 (section 5.3).
  It also imports Mercury's `gpumGetCachedProgram` and `gpumDeleteCachedProgram`, and
  carries the limit constant `SGX_MAX_SHADER_CACHE_SIZE` [static, use inferred]. It finds a directory with `NSSearchPathForDirectoriesInDomains` [static]. That
  the directory is the app's Caches folder, and that a GL program's compiled code lands in it, is [inference].

## 4. Question 2: the user-client boundary (selectors recovered, payloads partly)

- **As the tables show it.** IOAccelerator is the one user-client library. Its call sites are `IOServiceOpen`,
  `IOConnectAddClient`, `IOConnectMapMemory`, `IOConnectCallMethod`, the scalar and struct variants, and
  `IOConnectRelease` [static]. Shared memory is handled through IOAccelerator's resource API (`IOAccelResourceCreate`,
  `IOAccelResourceGetDataBytes`) and IOSurface [static].
- **As observed on the 4S** (dossier 2.3, six unsigned runs as root, [probe], not re-measured): user-client types 0, 1 and
  2 open. Types 3 to 8 are refused with `0xe00002c7`. Selectors seen: type 0 uses 2 and 0; type 1 uses 0 and 2; type 2
  uses 1 and 7. Each call appears twice in the log, and the cause is not known.
- **Can an unsandboxed process open it directly?** On a jailbroken device the probe opened types 0 to 2 as root, unsigned.
  Whether the kernel checks entitlements for those types is not known. The kext logs AMFI lookups (section 2.2), so a
  code-signing or entitlement check is likely, but the check was not read. Open.
- **The IMG user client's selector table (static, pass 3).** `IMGSGXSharedUserClient` has a candidate vtable at VM
  `0x809dbcb8`, and its name string is referenced from three code addresses in the kext. Its init (`0x809bc464`)
  stores a six-record table (VM `0x809dc090`) in the object when a global-object check passes. The table is a legacy
  `IOExternalMethod` array of 24-byte records: function at +0x04, flags at +0x0c, counts at +0x10 and +0x14. Its
  external-method override serves selectors 5 to 10 from it, and forwards 0 to 4 to the global object. The records:

  | Selector | Function | Type (flags) | Input | Output |
  | --- | --- | --- | --- | --- |
  | 5 | `0x809bc49c` | 3, struct in and struct out | struct 124 bytes | struct 4 bytes |
  | 6 | `0x809bc5a8` | 0, scalar in and scalar out | 1 scalar | 0 |
  | 7 | `0x809bc694` | 3, struct in and struct out | struct 0 bytes | struct 4 bytes |
  | 8 | `0x809bc70c` | 3, struct in and struct out | struct 48 bytes | struct 28 bytes |
  | 9 | `0x809bc774` | 0, scalar in and scalar out | 1 scalar | 0 |
  | 10 | `0x809bc7e0` | 0, scalar in and scalar out | 0 | 1 scalar |

  For struct types the counts are byte sizes, so those rows are settled. The probe's type 2 uses selector 7, which
  matches the row with struct out 4. [static, from the kext's data; the probe cross-check is consistent, not conclusive]

- **The IOAccelerator user clients (partly read).** `IOAccelSharedUserClient` is the probable owner of a table at VM
  `0x809ac450` with three live records: selector 0 (scalar in 0, scalar out 5), selector 1 (flags 2, count1 64) and
  selector 2 (flags 2, count1 352). An init at `0x809a4bf4` stores this table in the object, and an override serves
  indices up to 4 from it. The class identity is inferred from a candidate vtable at `0x809ac078`, not confirmed. What
  the flags-2 counts mean is not settled, since their meaning for that type was not checked against the kernel's
  handler. A second table at `0x809ac980` has two records and no owner. The probe's type 0 uses selectors 2 and 0, and
  type 1 uses 0 and 2, which fits this table. [static; partly settled]

- **What is the minimum to submit work without GLEngine?** Still open. The struct sizes above fix the IMG payload
  sizes for selectors 5 to 10. The payload fields, the IOAccelerator tables past their sizes, and the kernel's checks
  (section 2.2) are not read, so the minimum set is not known (section 9).

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
- **The program cache.** `_sgxCachePPStream` and `_sgxLoadPPStream` store and read the linearized PP stream in `fscache`,
  keyed by SHA-256 (section 5.3). The Mercury calls `gpumGetCachedProgram` and `gpumDeleteCachedProgram` are imported
  too. The config names (`SGX_MAX_SHADER_CACHE_SIZE`, `SGX_MAX_STREAM_CACHE_SIZE`) fit a persistent, hashed store [static].
- **OpenCL's binary builder.** `gclBuildProgramBinaryAPPLE` is the CL path. It is not usable on the SGX543: the compute
  user-client type is refused [probe].

### 5.3 Reachability, and the test that settles it

- **Capture from the cache (inference, cheapest to test).** After a GL draw with a new program, the app's Caches
  folder should gain a file in the `fscache` format. The test uses only files our own app causes. It needs no hook into
  Apple's code and no disassembly, so it does not touch gate 37. It runs only on the phone, when the owner sequences
  it.
- **Offline reuse of Apple's compiler (pass 3, static): not shown.**
  - *The driver's compile entries do no compiling in this build.* `gldCompileComputeModule` and `gldLinkComputeModules`
    return 0. `glrCompGetImageFormats`, `glrCompCreateProgram`, `glrCompBuildProgram`, `glrCompLoadBinary` and
    `glrCompDeleteKernel` return -1. `gldCreatePipelineProgram` calls only `malloc_zone_calloc` and a pthread mutex.
  - *The compiler is in libGLProgrammability, and the PP stream is its output.* `ShCompile` builds the AST
    (`glpMakeCompiler`, `glpCompileShader`, `glpSerializeAST`). `ShGetCompilerPPStream` is a separate export. It calls
    `glpShGetLinkerPPStreamCore`, which calls `glpPPShaderLinearize` and `glpPPShaderLinearizeEx` and builds the stream
    with `PPStreamCreate` and `PPStreamAttachStream`. The five entries `ShCompile`, `ShConstructCompiler`,
    `ShConstructLinker`, `PPStreamCreate` and `PPParserParse` reach 1,033 of the library's 3,606 text symbols by direct calls.
  - *The driver consumes the PP stream on the draw path.* `gldUpdateDispatch` reaches `_PrepareVendpipeprog`, which
    builds a SHA-256 key for the stream (`_sgxGeneratePPStreamCacheKey`), looks it up in `fscache` (`_sgxLoadPPStream`),
    and on a miss calls `glpPPShaderLinearize` or `glpPPShaderLinearizeEx` and stores the result (`_sgxCachePPStream`,
    which calls `msync`). The disk cache therefore holds linearized PP streams, not USSE code.
  - *The USSE encoder is reached indirectly.* `_AppendInstruction` is called directly only from the callback group
    `_CompileInstrsCB`, `_AlignToEvenHwCB`, `_NoSchedAlignToEvenCB` and `_SetNoSchedFlagForBasicBlock`. Those are named
    callbacks, so a function-pointer table probably reaches them, and the direct-call walk does not follow it. Finding
    that table is the next step for the main pixel shader. The `_Instruction*` and `_Register*` helpers of
    libGLProgrammability are reached only from `ShGetCompilerPPStream`, not from `ShCompile`.
  - *Device state.* `_ProcessUfConstLoads`, reached from `gldUpdateDispatch`, calls Mercury's `gpusPPParameterOffset`,
    so the parameter layout comes from the device layer. The driver also imports the IOAccelerator, IOSurface,
    IORegistry, `sysctl` and `mach_absolute_time` calls. Whether `ShGetCompilerPPStream`'s reach includes
    libGLProgrammability's five `IOSurface` imports was not checked.
  - *Verdict.* The front end is plausibly offline: `ShGetCompilerPPStream` yields the PP stream, and no device call is
    known on that chain (not fully checked). The USSE step is not shown to be standalone. It runs at draw time through
    driver callbacks, and it takes Mercury's parameter offsets, so offline emission of USSE binaries is not shown. The
    reach counts follow direct `BL`, `BLX` and `B.W` edges only. Calls through function pointers are not followed, so
    "not reached" means "not reached by direct calls".
- **The command stream, as far as the writer goes (pass 3).** `_WritePixelEventPrograms`, called from
  `gldBlitFramebufferData`, calls `_InternalGetDataBuffer`, which binds an IOAccelerator resource
  (`IOAccelResourceGetClientSharedPrivate`, `gpusGetDataBuffer`). Then `_PDSGeneratePixelEventProgram` copies a PDS
  program into the buffer with `memcpy`, and `_SetUSEExecutionAddress` sets the USSE execution address. So the PDS
  words and the USSE address go into IOAccelerator shared buffers. The draw-state writer `_sgxEmitDrawState` calls
  `_PDSGeneratePixelShaderProgram` [static]. The command words that the kernel parses are not yet read.
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
   table's layout can be recovered and called from our process. Both need code reading, which is now allowed (item 38)
   and not yet done. The compile reuse of section 5.3 belongs here. It removes the front end's cost only if the
   measurement shows the compile is hot.
3. **(c) A full own driver.** Effort XL. The kext's method table, the command stream and the USSE encodings are all
   unread. The command stream is not documented anywhere the research found. Pays off only if (a) and (b) are capped
   below the target, the kernel interface proves simple, and the command stream can be read from shared memory. Not
   justified now.

Pass 2 adds one fact to this ranking. The kernel validates vendor payloads and render commands (section 2.2). So (c)
would have to write a command stream that the kernel accepts, and (b) would reach the kernel through the same checks.
Neither changes the ranking.

Recommendation: do (a) now. Run the section 6 probe when the owner sequences it. Scope (b) only if its bar is met.

## 8. What this changes in the existing notes

- **The 4S binaries are now reachable.** The `.cache/dyld/6.1.3` used by the import check is the 3GS build. The 4S's
  own cache is in `.cache/firmware/rootfs/iPhone4,1/6.1.3_10B329`.
- **Dossier 4.9 holds on the 4S.** The binary-format absence was measured on the 3GS, and it is confirmed here on the 4S.
- **Dossier R5 is resolved on the 4S.** The kernel service literal `IOAcceleratorES` is in OpenGLES. The class
  `SGXDriver543` is also in the kext's method names (section 2.2). Its device-side use stays [probe].
- **Dossier R1 (the kernelcache) is resolved for the 4S.** The kernelcache was fetched and decompressed (section 2.1).
  The 4S rootfs's kernelcache directory is still empty, and the iPad 2 rootfs has none.
- **The "cheapest observable step" in dossier 4.7 is cheaper for shaders.** The cache-folder test answers the shader
  question without the payload trace. The dump test in the landscape note still matters for the command stream.

## 9. Open items, and what the coordinator must decide

1. **The kernel extension.** Done in pass 2 (section 2.1). Items 37 and 38 are recorded as decided by the coordinator's
   relayed owner instruction of 2026-10-29. The iOS licence question (dossier item 36) is not analysed and stays open for
   the owner.
2. **The compile-path call graph.** Done in pass 3 for the driver's compile entries and for the front end (section 5.3).
   Open: the function-pointer table that reaches the USSE encoder callbacks (`_CompileInstrsCB`, which calls
   `_AppendInstruction`), since the direct-call walk does not follow it, and whether an offline run is possible at all.
3. **The device run.** The Caches-folder test and the section 6 probe need the phone. The coordinator sequences it.
4. **Where the document lives.** The brief gives `docs/explanation/metal/`. The sibling dossiers sit under
   `docs/explanation/backports/`. Metal is a part of the Backports component, so the coordinator may prefer the
   backports folder. This pass keeps the brief's path.
5. **The GPUSupport folder in the firmware copy.** Decided by the coordinator on 2026-10-29: it is not opened, read,
   searched, hashed, copied or deleted (dossier item 39). Nothing in this study uses it.
6. **An unresolved role.** `libGPUSupport.dylib` exports the same `gpum*` and `gld*` names as Mercury, but no GL image
   links it. Its role is not established.
7. **The selector tables.** The IMG table is recovered (section 4). Open: the owner of the IOAccelerator table at
   `0x809ac980`, what the flags-2 counts mean, and the payload fields behind the struct sizes.
