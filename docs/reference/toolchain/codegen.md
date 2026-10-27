# Device codegen: what the toolchain sets, and what was measured

This reference lists every place that sets code generation for the device (the iPhone OS slices, armv7 on the A5), what
each sets now, and whether anything measured it. The decision is [0014](../../explanation/decisions/0014-performance-is-a-requirement.md):
the build settings for the device are chosen by measurement on the A5 and are not inherited. The measurement method is
the `bench/*` group of `./xmakew test -P .` (see [the toolchain's tests](tests.md)); its emulator counts compare versions of the
same code and are never times.

"Measured" says what a run of this repository has shown for the setting, and nothing else: `no` means the setting was
set by a recipe or a rule and never compared with an alternative on a workload.

## Audit

| Setting | Value now | Where it is set | Measured |
| --- | --- | --- | --- |
| CPU tuning, `-mcpu=cortex-a9` | WebKit only. The toolchain sets no `-mcpu`, so every other device target gets clang's default for `armv7-apple-ios6.0`, which is `-target-cpu generic` | `frameworks/WebKit/xmake.lua` (`add_cxflags`), `frameworks/WebKit/src/modules/engine.lua:75` | yes, instructions only: no change, see Measurements |
| `-mfpu=neon` | WebKit only. The default of the target already includes `+neon` and `+vfp3`, so the flag adds nothing | `frameworks/WebKit/xmake.lua`, `frameworks/WebKit/src/modules/engine.lua:75` | yes, the default's features read with `clang -###` |
| `-O` of packages | `-O3` on `work/performance`, added to every package compile by the toolchain when `optimize=packages`. Changing it to `-Os` is held, see Decisions and Held | `toolchain/toolchains/apple-ios/xmake.lua:85`, `toolchain/includes/apple-ios/xmake.lua:41` | yes, on the package-style kernel `compute`, see Measurements |
| `-O` of app and library targets in release | `smallest`: xmake's `mode.release` sets `optimize` to `smallest` on iphoneos, so `-Os` for C and ObjC, and `-Osize` for Swift through `swift.lua`'s `smallest`. The toolchain does not change it | xmake's `share/xmake/rules/mode/xmake.lua:56-60`, `toolchain/modules/apple/swift.lua:150,171` | yes for C and ObjC: `-O2`, `-O3` and `-Oz` against `-Os`, see Measurements. Swift: no |
| `-O` of Swift in the runtime and the stdlib | `-O -wmo`: the swift-runtime's Swift modules, and the stdlib core with `-enforce-exclusivity=unchecked` | `packages/s/swift-runtime/xmake.lua:257,280`, `toolchain/modules/apple/swift.lua:103-113` | no |
| Swift exclusivity, user code | checked (the default); `-enforce-exclusivity=unchecked` is set only for the stdlib build | `toolchain/modules/apple/swift.lua:113` (stdlib only) | no |
| Swift whole-module | `-wmo` on every user Swift compile and on the stdlib | `toolchain/modules/apple/swift.lua` (`compile_flags`, `runtime_flags`, `build_module`) | no |
| Backports | `set_optimize("smallest")`, `-Os -fvisibility=hidden`, ARC on the Objective-C libraries | `frameworks/Backports/xmake.lua:118-157` | no |
| Combine | `set_optimize("fastest")` for C and `-O` for Swift | `frameworks/Combine/xmake.lua:18,29`, `packages/c/combine/xmake.lua:94` | no |
| WebKit | `faster` (`-O2`) and `smallest` per target; WebCore `-Oz` behind `WEBKIT_IOS6_SIZE_OPTIMIZED`; the interpreter `-O3` | `frameworks/WebKit/xmake.lua:34-73`, [WebKit measurements](../webkit/measurements.md) | size only, see that document |
| llvm, the compiler (host build) | `CMAKE_BUILD_TYPE=Release`, targets `ARM;AArch64`, no `LLVM_ENABLE_LTO`, libLTO not in the distribution | `packages/l/llvm/xmake.lua:48-60`, [prebuilt](../../guides/prebuilt.md) | n/a (the compiler's own build) |
| libcxx | `-mllvm -hot-cold-split=false`, `-D_LIBCPP_NO_UTIMENSAT`, CMake Release | `packages/l/libcxx/xmake.lua:54,85` | no |
| ICU | `-O2`, with `-femulated-tls` where the toolchain asks for emulated TLS | `packages/i/icu/xmake.lua:54` | no |
| libvpx | `-O2` | `packages/v/vpx/xmake.lua:17` | no |
| Packages with `-Os` | zlib, xz, lz4, lzfse, ggml, opencv, box2d, monocypher, micro-ecc, quicly, picotls, suitesparse-ordering, swift-crypto, apple-compat (`-Os -fno-builtin`), the swift-runtime's C shims | the `FLAGS` of each `packages/<letter>/<name>/xmake.lua`, `toolchain/src/apple-compat/xmake.lua:11` | no |
| CMake packages | `CMAKE_BUILD_TYPE=Release` (`-O3 -DNDEBUG`) with the toolchain's flags: opus, mozjpeg, TDLib, libcxx, swift-runtime | `toolchain/modules/apple/cmake.lua:107` | no |
| dav1d | Meson, with the recipe's options and no buildtype; xmake's Meson default applies, not checked | `packages/d/dav1d/xmake.lua:14` | no |
| LTO, device code | none in the toolchain or the app rules. Thin LTO only in WebKit's engine | `frameworks/WebKit/src/modules/engine.lua:153,157` (`-flto=thin`) | no; thin LTO cannot be measured with this llvm, see Held |
| LTO, emulator | `--emulator_lto`, host only, release only | `emulator/xmake.lua`, [build and test](../../guides/emulator/build-and-test.md) | n/a (host) |
| Dead stripping | `-Wl,-dead_strip` on release binaries and shared libraries whose `strip` was not set, which the rule then sets to `none` | `toolchain/rules/apple-ios/xmake.lua:63-69`, `frameworks/WebKit/xmake.lua:91` | no |
| Hot-cold splitting | off in libcxx and WebKit. Applied where it takes effect it grew `__TEXT` by 1.0 to 1.6% and was reverted | `packages/l/libcxx/xmake.lua`, [WebKit measurements](../webkit/measurements.md) | size only |
| `-fomit-frame-pointer` | not set anywhere; clang's default for the target applies, not verified | none | no |
| `-mthumb`, `-marm` | not set by the toolchain; the recompiler's tests use `-marm` | `recompiler/tests/perf/build.lua` | no |
| objc_msgSend call sites, ARC | no toolchain flag; ARC is per target (`-fobjc-arc` in the Backports rows) | `frameworks/Backports/xmake.lua:119-362` | no |
| Objective-C `BOOL` | `-D__OBJC_BOOL_IS_BOOL=1` when a target names `apple.objc_bool` | `toolchain/rules/apple-ios/xmake.lua` | n/a (correctness) |

The compiler and linker flags an app gets from the toolchain (`-target armv7-apple-ios6.0`, the SDK, `-ffile-prefix-map`,
the backports overlay) are in `toolchain/toolchains/apple-ios/xmake.lua` and `toolchain/rules/apple-ios/xmake.lua`. The
rows above are the codegen-relevant part of them.

The default for `armv7-apple-ios6.0`, read from `clang -###` of the packaged llvm 23.1.3: `-target-cpu generic`,
`-mfloat-abi soft`, and the features `+neon`, `+vfp2`, `+vfp3` and `-vfp4`.

## Measurements

The workloads are `tests/bench/workloads/` (`msgsend`, `alloc`, `collections`, `strings`, and the C `compute`, a
package-style kernel of CRC-32, FNV-1a and a 64-by-64 integer matrix product). They are built for armv7 iOS 6.0 with the
packaged llvm 23.1.3 and the iPhoneOS 26.2 SDK, and run as the first process of an iPhone 4S boot of iOS 6.1.3 under the
emulator built from this checkout. The numbers are guest instructions (the emulator's CPU ticks for the run), not times.
Each setting was run in report mode (`REVENANT_BENCH_REPORT=1`, `REVENANT_BENCH_FLAGS`). The deltas are against `-Os`, the
default. The runs were repeated on the committed code: the counts and the code sizes reproduced exactly.

Guest instructions, the four Objective-C workloads:

| Setting | collections | alloc | msgsend | strings |
| --- | --- | --- | --- | --- |
| `-Os` (default) | 144,829,051 | 257,944,145 | 45,744,143 | 73,977,966 |
| `-O2` | 144,829,048 (0%) | 257,344,143 (-0.23%) | 45,744,140 (0%) | 73,977,963 (0%) |
| `-O3` | 144,829,048 (0%) | 257,344,143 (-0.23%) | 45,744,140 (0%) | 73,977,963 (0%) |
| `-Oz` | 144,128,943 (-0.48%) | 260,543,822 (+1.01%) | 46,743,814 (+2.19%) | 73,975,354 (0%) |
| `-Os -mcpu=cortex-a9` | 144,829,051 (0%) | 257,944,146 (0%) | 45,744,144 (0%) | 73,977,966 (0%) |
| `-O2 -mcpu=cortex-a9` | 144,829,048 (0%) | 257,344,144 (-0.23%) | 45,744,141 (0%) | 73,977,963 (0%) |

Guest instructions, the package-style kernel `compute`:

| Setting | instructions | delta |
| --- | --- | --- |
| `-Os` (default) | 29,679,959 | |
| `-O2` | 29,664,813 | -0.05% |
| `-O3` | 29,596,331 | -0.28% |
| `-Oz` | 33,239,134 | +12.0% |
| `-Os -mcpu=cortex-a9` | 29,679,959 | 0% |
| `-O2 -mcpu=cortex-a9` | 29,664,813 | -0.05% |

Code size, the `__text` section in bytes, from `size -m` of each linked binary, with the guest-memory helper compiled at
the same setting as the workload. The Mach-O file size is not used: the `__TEXT` segment is aligned to 32 KiB, so the file
size stays the same across settings and cannot show a change.

| Setting | msgsend | alloc | collections | strings | compute |
| --- | --- | --- | --- | --- | --- |
| `-Os` | 458 | 530 | 670 | 578 | 838 |
| `-O2` | 656 (+43%) | 822 (+55%) | 868 (+30%) | 776 (+34%) | 1,040 (+24%) |
| `-O3` | 700 (+53%) | 866 (+63%) | 912 (+36%) | 820 (+42%) | 3,148 (+276%) |
| `-Oz` | 436 (-5%) | 492 (-7%) | 588 (-12%) | 528 (-9%) | 740 (-12%) |

The calls to the workloads' own methods (`Node.value` 1,600,000, `Node.initWithValue` 200,000, `Counter.bump` 1,000,000)
and the resident sizes are the same under every setting.

What the numbers say:

- The counts repeat exactly across runs and under parallel load: `msgsend` gave 45,744,143 each time, and the compute
  baseline reproduces on the committed code.
- On the Objective-C workloads `-O2` and `-O3` save at most 0.23% of the instructions and add 30% to 63% to the code.
- On the compute kernel the instruction counts run `-O3` (-0.28%), `-O2` (-0.05%), `-Os` (0). The code runs `-Os` 838,
  `-O2` 1,040 (+24%), `-O3` 3,148 (+276%). `-O2` buys 0.05% of the instructions for a quarter more code, so it is not
  worth its size over `-Os`.
- `-Oz` cuts the code by 5% to 12% and costs 1% to 12% more instructions on three of the five workloads.
- `-mcpu=cortex-a9` changes the instruction count by at most one tick. The emulator counts instructions, and a CPU model
  changes the schedule and the cycles, not the count, so this run cannot show a gain or a loss from it.

## Decisions

- **Apps and libraries keep `-Os`.** `-O2` and `-O3` buy at most 0.23% of the instructions on the Objective-C workloads
  for 30% to 63% more code, and `-Oz` trades 1% to 12% speed for 5% to 12% less code. Speed is the requirement, so no
  level is adopted that loses speed. These workloads are small, so the code-size figures are for the workloads, not an
  app; a level for a large binary needs a measurement on an app-sized target.
- **Packages should be `-Os`, not `-O3`: held.** On the package-style kernel `-O3` costs 276% more code than `-Os` for
  0.28% of the instructions, and `-O2` costs 24% more code for 0.05%. `-Os` is the smallest code, and it is 0.05% slower than
  `-O2`, the next level up. The change is a local commit that is not pushed, because it changes the toolchain
  file whose digest is part of the prebuilt keys. The keys of every package built with the apple-ios toolchain move, libcxx
  and swift-runtime among them, whether or not the flag reaches them. Caveat: CMake packages (libcxx, swift-runtime, opus,
  mozjpeg, TDLib) take `-O3` from CMake's Release build type, which comes after the toolchain's flags, so the change
  reaches only the packages built by xmake's own rules. That was read from the CMake helper, not built here.
- **`-mcpu=cortex-a9` is not adopted.** The emulator cannot count what a CPU model changes, and whether it helps the A5 is
  a question of cycles, which only a timing on the device answers. Until that timing exists, the default (`generic`, which
  already includes NEON) stays.
- **`-mfpu=neon` is redundant** on this target and is not set anywhere new.

## Held

- The packages `-Os` change above: the commit is local and unpushed until it is batched with the prebuilt keys it moves.
- Thin LTO for the device. It needs libLTO in the llvm package, and the llvm release does not ship it (the distribution
  lists no LTO). Adding it changes the llvm package's prebuilt key, so its push is held for the batch.

## Not measured yet

- Swift `-O` against `-Osize`, and `-enforce-exclusivity=unchecked` in user code: the bench has no Swift workload, and
  the Swift runtime is not in the rootfs the bench boots.
- Dead stripping on and off: the workloads are linked without `-dead_strip`, and nothing varies it.
- The Backports hot paths (NSCalendar date math) and the `*at` shims: not in the group yet.
- Allocation counts: the group reports resident size only.
- Peak resident size: the emulator does not answer `TASK_VM_INFO`, so the peak is unknown there. The
  [guest memory](guest-memory.md) reference says what is missing.
- Calls to `objc_msgSend` and the runtime's retain and release: the block profile does not give the entry of
  `objc_msgSend` a block of its own in these runs, so those calls are not counted or gated.
- Any setting on a device: every number here is an instruction count from the emulator.

## Prior work surveyed

Surveyed before the benchmark group was written. Nothing here is copied; the licence is recorded for when something is.

| Work | What it offers | Licence | Used |
| --- | --- | --- | --- |
| LLVM `ARMScheduleA9.td` (`lib/Target/ARM/`) | the Cortex-A9 itinerary model, from a manual the authors called vague | Apache-2.0 WITH LLVM-exception in current trees; UIUC in older snapshots | no |
| LLVM test-suite | the reference workloads for codegen comparisons | Apache-2.0 WITH LLVM-exception | no |
| google/benchmark | a benchmark harness with repetition and statistics | Apache-2.0 | no |
| apple/swift `benchmark/` | about 75 workloads, a runner and a comparison tool, which mostly ARC and generics | Apache-2.0 with the runtime library exception | no |

A search for a controlled comparison of `-mcpu=cortex-a9` against generic armv7 on Cortex-A9 hardware found none. The
nearest source is an LLVM proposal (2017) that compares the generic tuning with Cortex-A8's, not with Cortex-A9's. Xcode's
default flags for iOS 6 armv7 were not found in a primary source. Both gaps are settled by the measurements below, not by
the literature.
