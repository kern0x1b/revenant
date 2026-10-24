# Optimisation beyond flags: what the A5 needs from the toolchain

[Decision 0014](../decisions/0014-performance-is-a-requirement.md) makes speed and memory on the iPhone 4S and the iPad 2 part of correctness. The build settings are one half of that: the CPU tuning, the optimisation level, LTO and dead-stripping are measured elsewhere. This document is the other half. The app's source is never touched, so what can make Telegram 13 run well on a dual Cortex-A9 with 512 MB is the code of our backports and runtimes, and the toolchain that compiles and links the app. The measured numbers are in the [optimisation reference](../../reference/toolchain/optimisation.md); this page says what was tried, what is expected, and what would be built next.

## What was measured, and how

- **Guest instructions** (`cpu-ticks` of the emulator's `--perf-summary`, with `--ticks` for a deterministic clock). They compare two versions of the same code on the same workload. They are not times: an A9 stalls on branches and on cache misses that an instruction count does not show, so a higher count can still be faster on the device, and a lower one can be slower.
- **Page misses** (`page-misses`), the guest's file-backed page faults. They stand in for page-ins from NAND, which the emulator does not time.
- **Text size** from the Mach-O segments.

Nothing here is a time on an A5. The device check is still to be done, with the device skill, on a build that has the change.

The workloads are real libraries at the versions our packages pin: zlib 1.3.2 (`packages/z/zlib`, a round trip of 512 KB of compressible data through `compress2` and `uncompress`) and opus 1.5.1 (`packages/o/opus`, a VOIP-mode encode and decode of 150 frames). Telegram 13 is not built here: it is a set of about 265 modules that the telegram-build project compiles in CI, and no binary of it exists on this machine, so no number is for Telegram.

## Ranked candidates

The expected gains are reasoned unless the reference says otherwise. The rank is by what the A5 is likely to feel, weighed by the cost of getting it.

| Rank | Technique | Expected gain on the A5 | Cost | Reuse |
| --- | --- | --- | --- | --- |
| 1 | Instrumented PGO for our libraries and the app's objects, trained under the emulator | Smaller hot-path code and smaller text; instruction count can rise, so the speed claim needs a device run. Measured on zlib: text −15.8%, instructions +6.3% | Medium: the iOS profile runtime is not in the llvm package (`COMPILER_RT_BUILD_PROFILE` is off for iOS), so the llvm recipe needs a patch; a training harness; a merge with a matching `llvm-profdata` | LLVM's instrumentation PGO and compiler-rt's profile runtime (in tree); Chromium's and Firefox's PGO pipelines; AutoFDO's `llvm-profgen`, which needs branch or trace hardware the A9 lacks |
| 2 | Order file (`ld64 -order_file`) from a startup trace | Fewer page-ins while the app starts on NAND. Size depends on how scattered the hot code is; measured on opus below | Low to medium: the emulator's `--perf-block-profile` gives the executed blocks, a Lua tool maps them to symbols, the link takes the list | Chromium's order-file tooling; Android's NDK orderfile guide; Emerge's iOS launch tooling (page-fault maps over many builds); LLVM's 2019 RFC on order-file instrumentation |
| 3 | LLVM codegen for the A9: missed UMAAL and missed NEON vectorisation | 20–90% fewer instructions in the kernels it touches (bignum carry chains, 16-byte byte loops); nothing elsewhere | Medium: a DAG combine in `ARMISelLowering.cpp` and tests; upstreamable | LLVM upstream; the reproducers are in `toolchain/tests/data/optimisation/` |
| 4 | Launch-time work of our libraries: fewer images to bind, static linking or prelinking of the Backports, no `+load` in our code, lazy binding | Less dyld work per launch: binding, rebasing and the Objective-C image registration scale with the image count. Not measured | Medium: a packaging change in the Backports; the emulator's `perf-begin`/`perf-end` can count the launch in instructions | No direct reuse; dyld's shared-cache closures are not on iOS 6 |
| 5 | Swift metadata and conformance cost at launch (reflection metadata, metadata caches) | Smaller launch image and fewer metadata instantiations; not measured | Medium, and partly a Swift compiler decision | Swift's own `-disable-reflection-metadata` and the runtime's caches (flags are in the other worker's audit) |
| 6 | `objc_direct` for the Backports' own methods | Small: an `objc_msgSend` on iOS 6 is a cached lookup, and NSHipster measured little difference on newer runtimes. Not measured here | Low, but only in our code | Clang's `objc_direct` (in tree since 2019) |
| 7 | Dependencies on the generic C path on armv7 although NEON or assembly exists (boringssl with `OPENSSL_NO_ASM`, openh264 generic) | Large for the code that calls them (WebRTC and TLS paths), nothing for MTProto, which uses CommonCrypto | High: boringssl no longer generates 32-bit iOS assembly, so the Linux arm assembly would need an Apple flavour through the package's own perl | BoringSSL's Linux arm assembly; the perlasm tools |
| 8 | Post-link optimisation (BOLT, Propeller) | None found: upstream BOLT documents ELF targets only, and no Mach-O or ARM32 support appeared in search | High | Not viable as things stand; the order file is the Mach-O equivalent |

Two things were looked at and set aside. Memory counts as speed (decision 0014), but the malloc and purgeable-cache behaviour of iOS 6 was not measured, so it is not ranked. Outlining against inlining for the A9's small instruction cache is a PGO question: the profile decides which code is cold, so it is part of rank 1.

## PGO

The profile runtime for iOS is missing, so instrumented PGO cannot be used by the fleet today. The prototype builds it from compiler-rt's sources with the packaged clang, which is what the llvm recipe would do with `COMPILER_RT_BUILD_PROFILE=ON` for iOS. The training binary runs under the emulator and writes its profile into the rootfs clone; the profile is merged with the release's `llvm-profdata` (the Command Line Tools one reads only the raw format it was built with, and refused the 23.1.3 profile), and the evaluation build uses a different input seed, so the profile is not measured on the data it was trained on.

The result is in the reference. The short reading: the profile shrinks the text by 16%, and it raises the executed instructions by 6% on this workload.

Decision: PGO does not land, and no llvm recipe change for it is made. The instruction count rose, and a rise in instructions is not a speed claim, so the change is not taken on the strength of the text size alone. It returns only when a device measurement of the A5 shows the profiled build faster, and then with the explanation of the instruction rise that the block profile of both builds would give (the emulator's block profile of the zlib benchmark did not finish, so that explanation is still open).

## Order files

The emulator writes the blocks it executed with `--perf-block-profile`, which is the trace an order file needs. The prototype maps those blocks to symbols of the binary and writes the list the linker takes. The order file orders whole functions, and it does not need `-ffunction-sections` for Mach-O, because ld64 reorders the atoms of `__text`.

Its gain depends on the layout the default link gives. A function that is hot and sits between cold ones costs a page it does not need; a hot set that is already contiguous gains nothing. The prototype over libopus shows both cases. A full encode and decode touches 60 of the library's 61 text pages, so the order file has nothing to gather. A one-frame run, which is closer to a launch path, touched 59 pages in the default layout and 51 with the order file, at the same instruction count. The gain is real and small here, and it grows with the size of the image the launch path leaves cold, which is the case for an app of Telegram's size. That is reasoned, not measured: no Telegram binary exists to measure.

## Codegen

Three reproducers are committed as tests, in `toolchain/tests/data/optimisation/codegen.c`, and checked by `toolchain/tests/addon/optimisation_test.lua`. Each missed case is pinned: the test fails as soon as the miss goes away, so the pin moves to the controls when a fix is taken. Two candidate fixes were built into llvm and measured, and both are dropped; the numbers are in [the reference](../../reference/toolchain/optimisation.md#the-two-arm-patches-measured-and-dropped).

- **UMAAL with a 64-bit carry.** `mul_add_words_carry64` computes `a * w + r + c` with `c` a `uint64_t` that is `t >> 32`. The loop has `adds`, `adc` and `umlal`, where `mul_add_words_carry32` has one `umaal`. The high half of the carry is zero by the source's meaning, but across the loop's back edge the DAG cannot see that, so a known-zero check in `PerformUMLALCombine` (`lib/Target/ARM/ARMISelLowering.cpp`) never fires. The check did not flip the reproducer, and it left the bignum library byte-identical. Dropped.
- **NEON for a 16-byte byte loop with pointers that may alias.** `xor16_alias` is 64 scalar byte operations; `xor16_restrict`, the same code with `restrict`, is three NEON instructions. The cause is established by the remarks and the IR: a constant trip count of 16 is completely unrolled before the loop vectoriser runs, and the straight-line code that remains has stores that may alias the loads after them, which the SLP vectoriser refuses. Capping that unroll for single-block NEON loops of at least eight iterations flips the reproducer to `vld1.8` and `veor`, but costs the opus codec 0.39% more guest instructions and the bignum driver's 64-iteration loops 4.8%. Dropped: it is not a win as it stands. A refined cap, for example one that takes only trip counts that are a multiple of the NEON width, is the candidate to measure next.
- **The extra moves of a 32-bit carry loop.** `bn_mul_words`-style loops spend two `mov` per word on the carry register. This is register coalescing in the A9 schedule, measured only by instruction count; it is listed, not yet a fix.

The reproducers are compiled for the toolchain's default Thumb-2 mode, where they show the same results as in ARM mode.

## What would be built next

1. PGO does not land, so the llvm recipe gets no profile runtime. It returns only with a device measurement that shows the profiled build faster on the A5.
2. The order-file tool in Lua under `toolchain/tools/`, run on an emulated launch of a port, with the list checked in next to the port. It reads `llvm-nm` and `llvm-objdump` from the packaged llvm, which the libraries config now installs.
3. A refined unroll cap for NEON loops, measured on the codec and the bignum driver before it is built, and a fact that carries the high half of a loop-carried 64-bit carry to the DAG, for the UMAAL combine.
4. A device measurement of the ordered build on an iPhone 4S, before the order file is taken as a speed claim.
