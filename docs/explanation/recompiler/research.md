# Recompiling arm64 iOS apps to armv7 for iOS 6: research and prototype

Date: 2026-09-17. Everything marked "verified" was run. Everything marked "estimate" is reasoning or extrapolation.
The legal boundary was kept:
- the arm64 inputs are only our own builds, from our own sources;
- the Swift runtime comes from the official swift.org 6.4 toolchain (Apache-2.0);
- system libraries from the firmware caches were used only for a local coverage measurement, and then deleted.


## General translation fixes (the core of the direction)
Not tied to a particular app: any arm64-to-armv7 ObjC/ARC app needs them.
1. The ARC token for a returned value: `objc_autoreleaseReturnValue` and `objc_retainAutoreleasedReturnValue` were moved to the "slow" path (plain retain and autorelease), because the TLS handshake of the fast path was corrupted by host ObjC inside the bridges, so returned objects became nil.
2. The ivar layout of guest subclasses of framework classes: offsets, `instanceStart` and `instanceSize` are recomputed for the size of the host superclass (variant A), and the 8-byte slots are kept. The key: the original offset of each ivar is taken from the arm64 offset variable (`ivar.offset_value`, read by the analyser from the image), NOT 0. Otherwise `offset = 0 + shift` collapses all the class's ivars into one. For a subclass of NSObject, shift is -4, so the read goes to self-4, `isa` lands in the high half of `id`, and `objc_release` catches a narrowing fault. Build check: no `xl_ivar_fixup` may have a zero `guest_offset` for a non-zero ivar.
3. One `__objc_classlist`: the guest and the host-object class lists are merged into one section. This avoids a crash in ld64's `fixClassAliases`, and it lets the runtime register the app's classes.
4. `Protocol *` arguments are translated by name, through `objc_getProperty` and `objc_getProtocol` (`conformsToProtocol:` and similar).
5. Nil-terminated variadic collection constructors (`dictionaryWithObjectsAndKeys:`, `arrayWithObjects:`, `initWithObjects:`, `setWithObjects:`) are intercepted in `objc_msgSend`, using the arm64 stack.
6. `@synchronized` and the rest of the ObjC runtime: the full set of headers in the bridges (`objc_sync_enter` and others).
7. Classes that are missing on the device (for example `UIAlertController`, behind a version check) are weak-imported: dyld binds them to 0, as in the original.
8. Host-to-guest blocks: a host block wraps the guest block; `_Block_copy`, `_Block_release`, `_Block_use_RR`.
9. Counted arrays of objects (objects and count), out-parameters, structs by value, callbacks: marshalling from the SDK headers.
10. Jump tables: recovery of their targets, and a patch to the `farmdec` decoder (`ubfx`, `uxtw`). Every form clang emits is covered: byte (`ldrb`), half-word (`ldrh`, step 2), and signed word (`ldrsw`, step 4, offsets relative to the table's base, including NEGATIVE ones). Three system fixes in JumpTables (`xlate.cpp`): (a) `FindIndex` accepts a GEP of any element size (InstCombine canonicalises scaled accesses into `getelementptr [2 x i8]` or `[4 x i8]`), and `Evaluate` computes the address with the element's real step through DataLayout, not as a byte offset; (b) the index is taken from the GEP operand itself (after `sub w8,w0,#min`), not from the raw value before the subtraction. Otherwise LVI does not bound it, and extra "targets" past the end of the table truncate the main function; (c) the table's domain is bounded by the block's actual guard condition (Guards walks the conditional predecessor branches, and Evaluate is extended with ICmp and Select), because InstCombine hides the range check in `xor(icmp eq, icmp ugt)`, which is opaque to LVI. Verified: OneBusAway has 195 targets and 0 failures; a branch of the MessagePack packer (a collection, at offset -0x544) that had been lost is recovered.
11. ARC copies of guest blocks (`objc_retainBlock`) are routed to the GUEST `_Block_copy`, not the host's. A guest block carries the arm64 `Block_layout` (8-byte isa, invoke and descriptor, an 8-byte size in the descriptor). The host Block runtime would read the size at the armv7 offset, so `_Block_copy` would memmove a garbage length, and SIGSEGV in the system's memmove. Likewise, any ARC or Block operation on guest blocks stays on the guest side.
12. The guest stack: 1 MB per thread (it was 8 MB). On a 512 MB 4S, about 9 threads at 8 MB is roughly 70 MB of guest stacks per process, which means a memory shortage and a device freeze. 1 MB matches the main thread's stack on arm64 iOS.
13. Diagnostics on the device without ReportCrash: the SIGSEGV, SIGBUS, SIGILL, SIGABRT and SIGTRAP handler in the runtime writes the native context (pc and registers) and the guest fp chain to `/private/var/revenant/xlate-crash.log`, and then re-raises. ReportCrash does not run on the device, and the iLEmu slide makes symbolication hard, so this dump gives the guest frames directly.
16. The size of a protocol in the overrides: `ObjCOverrides` rewrote the guest `protocol_t` in place and always took 96 bytes. A real guest `protocol_t` is shorter when it has no optional tail fields. Its size is in the `size` field at offset 64; for example, `OBAProgressIndicatorSource` is 0x50 = 80. By taking 96 instead of 80, the override overwrote the data that followed the protocol in `__data`. In OBA that was the constant pointers to the NSString keys of a dictionary, so the app loaded a garbage key (0x28), and it crashed in `xl_object_in`. This is systematic for any protocol under 96 bytes that has live data after it. The fix: read the guest size (`objc.cpp`, `protocol.size = U32(addr+64)`), and the override takes exactly that size (the host's protocol structure is padded up to it). Also, `xl_object_in` no longer fails silently on a sub-`__PAGEZERO` integer in an object slot; it prints a guest backtrace (diagnostics). This brought OneBusAway to a VISIBLE WORKING SCREEN in the emulator (the main screen with a navigation bar, a tab bar and a UIAlertView, without crashes).
15. Anonymous structs from the ObjC type encodings (`CLLocationCoordinate2D` and `MKCoordinateRegion` become `{?={?=dd}{?=dd}}` and similar). Before, `EncodedType` required a struct name from the SDK, and it failed on `?`. The method then got an IMP stub, `xl_unsupported_imp`, and the dispatch reported "no bridge". This is a systematic class: any accessor or method with a struct property by value (`setCoordinate:`, `coordinate`, `setMostRecentRegion:`, `resultsInRegion:`: 58 methods in OBA). The fix: xlgen synthesises the RecordDecl straight from the encoding (`SynthesizeRecord`, fields f0 to fN, cached by encoding in both ASTContexts), emits C struct definitions into `guest.m` and `host.m`, and the standard byte-wise struct bridge (Mirror and Leaves) converts the layout between arm64 and armv7. The result: unsupported went from 263 to 205, and the struct-property accessors come up and dispatch. Verified by a run in the emulator: the crash in `-[… setMostRecentRegion:]` is gone, and 27 more functions come up.
14. Methods with an explicit `va_list` (`initWithFormat:arguments:` and similar): the guest arm64 `va_list` cannot be passed directly to a host armv7 method. On arm64, Apple puts ALL variadic arguments on the stack, and a `va_list` is a plain pointer to contiguous 8-byte slots (unlike AAPCS64, which has a register save area). The host armv7 `va_list` is also a pointer, but to 4-byte slots. The generic bridge used to pass the raw guest pointer, so the method read garbage (for example the bytes of a string taken as a pointer), and crashed. Now `initWithFormat:arguments:` goes through a manual bridge (xlgen's manual map, `xl_manual_init_with_format_arguments`), which re-parses the format from the guest `va_list` as a flat array of 8-byte slots (`xl_format_marshal_valist`), and builds the string on the host. Diagnosing such a crash: the iLEmu guest backtrace (`[control] thread … frames=…`). Frames 0x0000xxxx to 0x005cxxxx are host code (the runtime, the bridges and the code that was brought up); 0x3xxxxxxx is the shared cache (slide=0); 0x10xxxxxx is guest data. Symbolicate with `modules/apple/dyld.lua`.

## The guest-host block bridge (variant A+, implemented)
The problem: a guest block has the arm64 layout (isa at 0 and 8, flags at 8, invoke at 16, descriptor at 24), and a host block has the armv7 layout (isa at 0 and 4, flags at 4, invoke at 12, descriptor at 16). Neither retention (a counter inline in `flags`, at different offsets) nor a call (invoke at a fixed offset, without a message) carries over to one flat object. Solution A+ (agreed with the architect session): TWO representations with a canonical two-way identity and one linked counter.
- Identity: a table from guest_block to host_wrapper (a `CFDictionary`). The same guest block always gives the same wrapper (pointer comparison, with the block as the key, for repeated crossings). Host to guest unwraps the wrapper to the same guest block.
- One counter: the wrapper holds exactly one guest reference for its whole life. `retain`, `release`, `autorelease`, `retainBlock` and the ARC return-value optimisation of a guest block are routed through the wrapper's host counter. When it reaches zero, dispose makes the guest `_Block_release`.
- The call: the host calls the wrapper's invoke, which goes through a trampoline for the block's signature (the type encoding comes from the descriptor; `t0` to `t4` for integer and pointer arguments; an unsupported signature gives an explicit fault). The guest calls its own block directly.
- The boundary: `xlgen` marks object pointers (`Value.is_object`). `ScalarToHost` goes to `xl_object_in` (which wraps guest blocks), and `ScalarToGuest` goes to `xl_object_out` (which unwraps the wrappers). This covers arguments, the elements of counted arrays, returns and struct fields. It is safe: the behaviour differs only for blocks and wrappers. Plus the block-receiver path in `xl_h_objc_msgSend`.
Verified on a real 4S: the app got past the block crashes (retaining a block in an NSArray, and the ARC return-value optimisation of a block) and went deep into initialisation. Open tail: (1) a host call of a boxed block from a container (`enumerateObjectsUsingBlock:`), an edge of completeness in the corpus test `tests/blockid.m`; (2) the current frontier of OneBusAway: a nil element `objects[1]` in the counted array of the path of `-[TFLogManager log:]` (TestFlight), captured in `/private/var/revenant/xlate-exception.log`.

## 1. Verdict

| Level | Outcome | Basis |
|---|---|---|
| A. Simple ObjC and C utilities | **Feasible, proven** | `bench` (C) and `fnd` (Foundation) were translated from arm64 and run on the emulated iOS 6.0. Exit code 0, and stdout matched the reference byte for byte. |
| B. UIKit apps in ObjC | **Feasible, proven on our own app** | UIDemo works on iOS 6.0: navigation, a table, a push, `drawRect:` with CoreGraphics, NSTimer, a block animation with a completion, a weak delegate, protocols, touches. No crashes, and the frames are correct. |
| C. Swift apps | **Blocked in this architecture** | The problem is the object model, not the instructions (section 7). |
| D. The broad App Store class | **No** | Swift (C) plus minimum iOS versions of 13 to 16, that is, APIs absent from iOS 6. Plus exceptions through translated frames, extensions and JIT. |

The architecture that works is variant (c) of the statement of the problem:
1. The app's code is lifted from arm64 into LLVM IR, with full 64-bit register and memory semantics.
2. The guest code lives in the host's 32-bit address space, and **guest address = host address**. Address translation is free: `inttoptr` from i64 to a 32-bit pointer, and LLVM's address arithmetic narrows itself to 32 bits.
3. The system frameworks stay native 32-bit ones.
4. The boundary runs through bridges **generated from the SDK headers**. One SDK is parsed by clang twice, as arm64 and as armv7.
5. The app's ObjC metadata is rewritten in place into the 32-bit objc4 format.

A bitcode route does not exist. Narrowing pointers during the lift (variant a) without types is incorrect.

## 2. What was verified by running (iPhone3,1, iOS 6.0 10A403, the iLEmu emulator)

| Test | Result | Details |
|---|---|---|
| bench (C: crc32, qsort with a callback, a linked list, a double matrix, snprintf and printf) | **PASS** | Exit code 0, stdout equal to the reference. |
| fnd (a class with properties and ivars, a category, blocks, for-in, NSMutableDictionary, dispatch_sync, NSLog, a CGRect by value) | **PASS** | Run `xlate-fnd-171501`: stdout equal to the reference, and the NSLog line is correct. |
| blockid (the A+ block bridge: a block in an NSArray, read and call from the guest, identity, a block as a dictionary key, surviving the release of the array, a host call of `enumerateObjectsUsingBlock:`) | **PASS** | `recompiler/tests/blockid/blockid.m`; run `blkid8`: stderr `blockid: PASS (failures=0)`. |
| UIDemo (UIKit) | **PASS** | All the marks: `launched`, `selected 7`, `detail-appeared Row 7`, `animation-finished 1`, `ticks 10 Row 7`; 1346 redraws in about 2 minutes. The touches `tap 160 16` and `tap 100 86` were delivered to the guest `touchesEnded:` and came back through the weak delegate (a CGPoint by value). The `groupTableViewBackgroundColor` background is black on the frame; the cause was not investigated. |

The imports of all three binaries were checked with the toolchain's `dyld.missing_imports` against `~/.revenant/dyld/6.0`: 0 missing out of 155,738 exports.
The test selectors were checked against `selectors_armv7.txt` for iOS 6.0: all are present. So the tests check the translation, not the backports.

## 3. Lifters: state and measurement

Summary from public sources (details and links are in the reply to the owner):
- **remill** (active, v6.0.1): its AArch64 semantics are incomplete, and it does not recover the CFG. It did not build on LLVM 23 without the patch `remill-llvm23-fp16.patch`. xlate does not use remill, so when the dependencies move to xmake packages there is neither a package nor a patch for it: the patch remains in the git history, in `deps/patches/`.
- **McSema**: archived. **anvill**: abandoned.
- **rev.ng**: supports AArch64 and Mach-O, but linking the recompiled code is hard-wired to x86-64 Linux, and AArch64 does not run in its QA.
- **RetDec**: its IR cannot be recompiled.
- **mctoll**: does not support AArch64.
- **Lasagne**: works in the opposite direction (x86-64 to Arm64), 1.51× native.
- **Rellume** and **Instrew** (active, LLVM 21 to 23): lifters aimed at the quality of the recompiled code.
- **No ready LP64-to-ILP32 translator exists anywhere.** QEMU 10.0 dropped 64-bit guests on 32-bit hosts.

Instruction coverage on real code (verified, `coverage/`):

| Corpus | remill (native semantics) | Rellume |
|---|---|---|
| bench (374 instructions) | 30 not lifted (NEON `ushr`, `umull`, `xtn`, `fmla`; `stp d9,d8` pre-index; `scvtf`) | 0 |
| fnd (494) | 6 | 0 |
| libsqlite3 from the iOS 10 arm64 cache (about 270 thousand) | 227 real | 5 (`brk`, `clrex`) |
| libswiftCore arm64, swift.org 6.4 (964 thousand) | not measured | about 430 real (`clrex` 155, half-float `fcvt` about 270) |

- remill's decoder describes 1,160 forms, operand extraction 443, and semantics 680 ISEL.
- The remill variant on SLEIGH (Ghidra) fails the IR verification.
- **Rellume was chosen.**
- In old arm64 binaries (iOS 10), the jump tables sit directly in `__text`. For Rellume they are data, not code, but the prototype does not yet support indirect jumps inside a function (section 8).

## 4. The data model: the variants

**(a) Narrow the pointers during the lift.** In machine code, field offsets, `malloc` sizes, array strides, alignments and `sizeof` constants are already computed. There are no types.
- Narrowing is correct only with a full type reconstruction, and in practice that cannot be solved: pointers in data, `memcpy` of sizes, pointer hashes, unions.
- Even bitcode contains LP64 facts. In the experiment `bitcode/util-arm64.ll`:
  - `class_ro_t {instanceStart 8, instanceSize 24}`;
  - `method_list entsize 24`, `ivar entsize 32`, `prop entsize 16`;
  - `%struct.Entry = {ptr, i64, double}` with `malloc(i64 72)`;
  - `CGFloat = double`, `NSInteger = i64`, and the CGRect return ABI is already lowered.

**(b) A 64-bit guest address space with software address translation.** Not needed. The guest images are placed at 32-bit addresses (at `0x10000000`), and all the other addresses (malloc, stacks) come from the host and are also under 4 GB. Address translation is then dropping the zero high half: 0 instructions.

**(c) A hybrid, implemented.** The price is in section 6. At the boundary with the system, the guest's 64-bit slots and the host's 32-bit values are reconciled by converters. The rules in the prototype:
- **Scalars.** Extension and narrowing with an overflow check. Sentinel values carry over: `NSNotFound`, `LONG_MAX` and similar map to their guest and host equivalents. On a real overflow, an explicit fault with diagnostics.
- **Structs by value.** Mirrors of the guest layout, and a field-by-field conversion: CGRect from double to float and back.
- **Pointers to a scalar or an object (out-parameters).** Copied into a host temporary slot and back.
- **Pointers to structs.** Copied there and, unless const, back.
- **Arrays with a count parameter** (`objects` and `count`, `argv` and `argc`). Element by element, with a NULL terminator.
- **Callback functions.** Pools of static trampolines by signature. The table of targets is filled in at run time, so W^X is not violated.
- **Blocks.** A host block wraps the guest block. The holder calls the guest `_Block_copy` and `_Block_release` from the translated BlocksRuntime (compiler-rt). Guest blocks retain the objects they capture through `_Block_use_RR`.
- **printf, NSLog and `stringWithFormat:`.** The format is parsed and rewritten (`%ld` becomes `%lld`), and the `va_list` is rebuilt for the iOS armv7 layout.
- **Weak references.** The guest slot's address is passed directly, because the runtime records the address. This is correct: little-endian, and the high half is always 0.
- **Fast enumeration.** A hand-written marshaller: the host state lives inside the guest's `extra[]`, and the elements are copied into an 8-byte buffer.

The size of the bridges for the whole API (verified, `xlgen --survey-out`, SDK 16.4, with UIKit, Foundation, CoreGraphics and QuartzCore, and their inclusion):

| | Total | Direct | Automatic with conversion | Format | Other variadic | Need manual rules |
|---|---|---|---|---|---|---|
| C functions | 2,746 | 1,874 (68%) | 515 (19%) | 6 | 15 | 332 (12%) |
| ObjC methods | 12,271 | 10,547 (86%) | 1,562 (13%) | 13 | 24 | 125 (1%) |

- Conversions in ObjC methods: 960 structs by value, 402 blocks, 228 out-pointers.
- Manual rules in ObjC: 70 return a block, and 47 point at data of another layout.
- Manual rules in C are mostly pointers to structs (`usr/include` 177, CoreGraphics 61, CoreFoundation 57).
- A separate risk: 20 of the 186 inline functions in the headers read struct fields of another layout. The classic example is the `putc` and `getc` macros on `FILE`.
- The header heuristic does not guarantee the semantics. An example found in practice: `char **argv` in `UIApplicationMain` was first classified as a single out-slot. Rules by parameter name, and manual exceptions, are always needed.

## 5. Bitcode (verified, `bitcode/`)

1. Apple clang 21 with `-fembed-bitcode` still puts `__LLVM,__bitcode` into the `.o`.
2. Apple ld-27037 prints "-bitcode_bundle is no longer supported and will be ignored". The executable has no bitcode. The IPA from the App Store does not have it either: Xcode 14 declared bitcode deprecated, and the store strips it (external source).
3. Our own arm64 bitcode, retargeted to armv7:
   - it compiles only after the `apple-a7` attributes are removed;
   - ld64 956.6 fails with an assert in `CFStringSection::targetContent`, because the LP64 layout of `__cfstring` is 24 bytes instead of 16.
4. Apple translated armv7k to arm64_32 through bitcode on watchOS precisely because arm64_32 is ILP32 with a consistent ABI. Apple did not take the LP64-to-ILP32 path (external source: the LLVM RFC of 2019).

## 6. Performance

**The bench** (verified, `tests/perf/`). The same workloads, native armv7 against arm64 through xlate to armv7. The number of instructions executed in Unicorn (a Cortex-A9 model), and the results are byte-for-byte equal.

| Kernel | Native | Native with a 64-bit `long` | Translated | Translated / native |
|---|---|---|---|---|
| crc32 | 591,385 | 1.00× | 723,718 | **1.22×** |
| sha256 | 3.78 M | 1.00× | 5.30 M | **1.40×** |
| fnv64 (u64) | 589,846 | 1.00× | 786,547 | **1.33×** |
| sort (recursion, `long`) | 3.30 M | 2.38× | 11.2 M | **3.39×** |
| list (pointers, `long`) | 2.94 M | 1.26× | 10.0 M | **3.41×** |
| geometry (double, structs) | 1.48 M | 1.01× | 5.31 M | **3.59×** |
| matrix (double) | 1.63 M | 1.00× | 3.28 M | **2.01×** |
| text (string parsing) | 1.48 M | 1.00× | 2.98 M | **2.02×** |

- **Estimate:** on the A4 and A5, guest code will be 1.2 to 3.6 times slower than a native armv7 recompilation of the same source. Part of this is the cost of the LP64 model itself, which cannot be removed without narrowing: on the sort, 2.38× of the 3.39×.
- CPU cycles were not measured. There was no real device, and the emulator's speed is not representative.
- In a UI app, most of the time is spent in the native 32-bit frameworks (drawing, UIKit). For UI code the **estimate** is tolerable; for compute code it is noticeable.
- **Code size** grows by 8 to 9 times: bench, 4.9 KB of guest code (with the shims) becomes 44 KB; UIDemo, 13.5 KB becomes 108 KB. The causes: saving and reloading State around calls, a `PC == return address` check after every call, and 64-bit arithmetic in `adds`/`adc` pairs.
- **Reserves (estimate):**
  - do not reload the callee-saved registers after calls, while keeping the ABI;
  - recover the function prototypes, and move from State to SSA;
  - map the NEON semantics onto the NEON of the Cortex-A8 and A9;
  - remove the PC check for trusted functions;
  - for callbacks, direct calls instead of `xl_invoke`.

## 7. Swift (level C)

**Verified on our own `swift/demo.swift`**, built with the swift.org 6.4 toolchain for arm64-apple-ios12.
- A class method is called through the vtable directly in the app's code: `ldr x8,[x20]` (isa, 8 bytes), then `ldr x8,[x8,#0x60]` (a 64-bit offset in the metadata), then `blr x8`.
- The class `Shape` is in `__objc_classlist` at the same time, with the superclass `_TtCs12_SwiftObject`.
- The host's 32-bit objc4 needs a `class_t` at the isa address: `isa` (4), `superclass` (4), `cache` (4), `vtable` (4), `data` (4). The guest Swift code needs 8-byte isa, superclass and so on at the same address.
- Bytes 4 to 7 must be at once the host superclass and the high half of the guest isa. That cannot be satisfied.
- For Swift subclasses of UIKit (UIViewController, UIView), the object must be a host object. A separate guest ObjC runtime implies a guest UIKit, that is, full emulation of the system, which is the variant rejected for speed.
- A possible workaround is object/proxy pairs between two runtimes, in the style of PyObjC. **Estimate:** years of work, and unfixable losses of semantics: identity, KVO, the superclass's ivars.
- The instructions are not the obstacle: libswiftCore comes up at 99.96%. Pure Swift with no ObjC objects at the boundary is technically translatable, but it carries almost no value for iOS apps.

## 8. The "IPA to 32 bit" architecture for the toolchain

The stages. What is implemented in the prototype is marked; A means automatic, and P means manual work is needed.

1. **Unpacking the IPA**, and finding the executable and the embedded frameworks. The frameworks become additional guest images of one process. Implemented: `tools/ipa.lua`. A.
2. **Parsing Mach-O.** Segments, `LC_FUNCTION_STARTS`, `__stubs` and `__objc_stubs`, bind, rebase and chained fixups, exports, `__mod_init_func`. Implemented (LLVM Object). A.
3. **Parsing the ObjC metadata.** Classes, metaclasses, categories, protocols, ivars, properties, CFString, selrefs, into a manifest. Implemented. A.
4. **Lifting the code** (Rellume), devirtualising the direct calls and the stubs. Implemented. A.
   - Indirect jumps inside a function (jump tables): recovery of the tables is implemented for every clang form (byte, half-word, signed word, including negative offsets), with the domain bounded by the guard condition. A.
   - Not done: C++ and ObjC exceptions through guest frames, `setjmp` and `longjmp`, atomicity of the exclusive instructions (`LDXR` and `STXR` are currently not atomic), and the FPSR flags.
   - A known limit (a separate frontier, not now): a pathologically large single function (about 288 KB) makes rellume or LLVM assert `isa<> used on a null pointer` (`Casting.h`) during the lift. It predates this work and has nothing to do with the jump-table recovery: it reproduces on a function of the same size without a switch. Real apps have no functions of that size.
5. **Data.** Guest segments at fixed addresses through `-segaddr` (non-PIE), rebase to constants, and bind to host symbols or guest copies. The `class_t`, `protocol_t` and CFString are rewritten in place, as separate atoms, and the addresses are checked after linking. Implemented. A.
6. **API bridges.** `xlgen`: 68 to 86% direct, 13 to 19% automatic with conversion. Rules by parameter name. Manual marshallers for fast enumeration, weak references, and the format methods and functions. A table of the new ObjC entry points (`objc_alloc` and similar). P, for 12% of C and 1% of ObjC, plus the semantic exceptions.
7. **APIs that are missing in iOS 6.** A separate axis, the work of the backports session. Translation does not replace the backports. P.
8. **The build:** clang 23 to armv7, ld64 956.6 (`-no_pie -no_objc_category_merging`), the toolchain's import check, `ldid`, Info.plist (`MinimumOSVersion 6.0`, `armv7`), and IPA packaging. Implemented. A.

Effort (estimate):

| Level | Now | To confident work |
|---|---|---|
| A | Works on its own tests | 2 to 4 weeks: exceptions, jump tables, atomicity, a run on a dozen open utilities |
| B | Works on our own UIKit app | 2 to 4 months: a full pass of `xlgen` over UIKit, Foundation, CG and QuartzCore with manual rules for about 460 declarations; blocks from host to guest (completion handlers in guest methods); exception handling; NSInvocation and forwarding; KVO on guest classes; performance; real open apps |
| C | Blocked by the object model | Years, with no guarantee; recompiling the source is more practical for Swift |
| D | No | Not realistic: Swift and the iOS 13+ APIs are missing |

## 9. A plan for the first steps

1. **Real open ObjC apps** (UIKit without a storyboard, or built with `ibtool`), through `tools/ipa.lua`, on the emulator and on an iPhone 4. The goal is to find the next classes of problem.
2. **Cycles on the device.** Measure the `tests/perf/` kernels and UIDemo on an iPhone 4 or 4S, and calibrate the model of section 6.
3. **Exceptions** through guest frames (a guest unwinder driven by `__unwind_info`, plus `longjmp` over host frames), and **jump tables**.
4. **Run `xlgen` over all of UIKit and Foundation**, and turn the 332 plus 125 manual cases into a table of rules (annotations in the style of FEX thunkgen). For host to guest, the blocks and callbacks in guest methods.
5. **Optimisations:** callee-saved registers without reloading, removing the PC check, NEON.
6. **Integration into the toolchain:** an xmake rule `iphoneos.recompile` on top of `xlate` and `xlgen`, the rellume and BlocksRuntime packages, the import and selector checks, and integration with the backports packages.
7. **For Swift**: only recompilation from source (the Swift session). Do not continue binary translation of Swift.

## 10. The first real target: OneBusAway 2.3.2 (update of 2026-09-17, evening)

The input is the authors' official arm64 IPA (Apache-2.0, minimum iOS 6, no Swift), through `tools/ipa.lua`. Verified by a run on the emulated iOS 6.0 (iPhone3,1).

State: it translates (4685 functions), links, dyld loads it, SpringBoard spawns it, the ObjC runtime registers the app's classes, the delegate `OBAApplicationDelegate` is created, the app initialises, sets up timers and network kevents, and then SIGSEGVs about 2.4 s after the start, inside the system's UIApplication initialisation (reading a string through a bad pointer: a marshalling error in one of the bridges).

Done on the way (all in `recompile`; there are no commits in the toolchain):
- recovery of the jump tables (symbolic evaluation plus LazyValueInfo, a fixed point);
- a patch to the `farmdec` decoder: the 64-bit `ubfx`, and the missing `uxtw`;
- guest copies of data constants: scalars, structs (`CGRectZero`), and the CF structs of callbacks (the pointers narrow, and the host calls them from the host);
- host-to-guest block bridges (the host wrapper of a guest block; `_Block_copy`, `_Block_release`, `_Block_use_RR`);
- running the guest's `__mod_init_func` at start-up;
- weak import of classes that are not on the device (`UIAlertController` behind a version check): dyld binds them to 0, as in the original;
- a workaround for a crash of ld64 956.6 in the ObjC pass `fixClassAliases`: all ObjC lists (the guest ones and those from host objects) are merged into the section `__xlcls`, `__xlcat` or `__xlproto` before linking. ld does not optimise them, and after linking the section names return to `__objc_*` (one `__objc_classlist`; otherwise the runtime registers only one section, and the app's classes are not found);
- data symbols and imported functions are emitted with an asm alias, so that they do not conflict with the declarations and inlines of the SDK (`_dispatch_once`, `NSPOSIXErrorDomain` and similar);
- the full set of ObjC runtime headers in the bridges (`objc_sync_enter` for `@synchronized` and similar).

Next steps for OneBusAway: (1) debug the correctness of the bridges on the path of the UIApplication initialisation (symbolicate the failing call, check the return types of the selectors and structs); (2) unwinding exceptions through translated frames (needed by other apps; it does not block here yet, but it will be). The 4S device is available (claim and release, `sblaunch` in `/usr/bin`). A screenshot on the hardware goes through self-drawing with `renderInContext` into a PNG (advice from the backports session).

### Update (later on 2026-09-17): OneBusAway reaches about 150 s of initialisation
Bridges were added: translation of `Protocol *` arguments by name (`objc_getProtocol`), which fixes `conformsToProtocol:`; nil-terminated variadic collection constructors (`dictionaryWithObjectsAndKeys:`, `arrayWithObjects:`, `initWithObjects:`, `setWithObjects:`), intercepted directly in `xl_h_objc_msgSend`, where the caller's stack is intact (Apple arm64: varargs are on the stack). A diagnostic mode, `XL_COLLECT` (a missing bridge does not kill the process; it is logged and returns nil), collects every gap in one run.
State: the app initialises in 90 to 150 s (hundreds of bridged calls, class registration, networking). What remains runs into the app's Google Analytics subsystem (`GAIUsageTracker trackTarget:action:` with a dictionary receiver, and `GAIDataStore performBlockAndWait:withError:`). That is a symptom of a deeper value-marshalling error in GA, and a separate node. In the `XL_COLLECT` mode, the SpringBoard watchdog then fires (SIGKILL). The next attempt is focused debugging of this path (class references and the return of `+sharedInstance`) and unwinding exceptions.

### Update: a real 4S, and a systemic ARC fix
- WebKit: on the device, a translated app is an ordinary native armv7 app, with JIT only in the emulator, so the watchdog cannot fire there from speed. The path to the screen goes through the hardware.
- The target's rules were moved out of the code into a file next to the binary (`targets/OneBusAway.rules`, copied into the bundle as `xlate.rules`): `neutralize-class` and `neutralize-selector` (a crutch for this target, which turns off Google Analytics, whose marshalling is not yet understood; the guest network is isolated anyway), and `screenshot <sec> <path>` (self-drawing with `UIGetScreenImage` into a PNG, because the device has no standard screenshot without injection). Fact: the environment variables from SpringBoard do NOT reach the app, so the target's settings go through a file only.
- The first run on the 4S (claim, release, `sblaunch`): the app started and threw `NSInvalidArgumentException -[__NSPlaceholderArray initWithObjects:count:]: nil from objects[1]`. The root is general and systemic: OneBusAway uses ARC, and the ARC optimisation of a returned value (`objc_autoreleaseReturnValue` and `objc_retainAutoreleasedReturnValue`) uses a TLS handshake, which breaks when host ObjC runs in the bridges between the pair of calls. Returned objects then became nil further down the code (the dictionary in GA, and the nil in the NSArray, are symptoms of this). Fixed: these functions were moved to the "slow" path (plain retain and autorelease), and the handshake is no longer corrupted. This is a fix for practically every modern ARC app.
- After the fix (in the emulator): the exceptions with nil are gone, and the app goes further (about 99 s) and then crashes elsewhere: a SIGSEGV in a system framework (the next node). Confirmation on the 4S is pending the device being free.

### Variant A: reconciling the ivar layout of guest subclasses (implemented)
A guest subclass of a framework class carries the arm64 layout of its ivars (8-byte slots, `instanceStart` for the arm64 superclass). The host ObjC runtime on armv7 shifts the subclass's ivars for its own superclass size. When the `instanceStart` values disagree, the offsets go to garbage (a crash in `objc_getProperty`). The fix: xlate emits a table of layouts, and the runtime repairs it before implementation, idempotently, from the ORIGINAL guest values. shift = `class_getInstanceSize` of the host superclass minus the arm64 `instanceStart`. For each of the class's own ivars: offset = original + shift. `class_ro.instanceStart` = the size of the host superclass, and `instanceSize += shift`. A guest-to-guest-to-host chain goes by dependency, with no double application. The guest's 8-byte slots are kept (there is no NSInteger or int64 ambiguity). There is no gap in the object: the subclass's own ivars are placed right after the host superclass. The overhead is 4 bytes for every pointer or NSInteger ivar of the subclass (for example `OBABookmarksViewController` has 3 such ivars, about 12 bytes per object beyond the host packing). Verified: the crash in `objc_getProperty` on OneBusAway is gone, and the app goes further.
The next node (common to all): `objc_release` gets a 64-bit value with the pointer in the HIGH half (0x10111fb8<<32). The `id` pointer landed in the wrong half of an 8-byte slot. Under investigation.
