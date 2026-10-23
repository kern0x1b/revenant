# Optimisation measurements

The numbers behind [the optimisation explanation](../../explanation/toolchain/optimisation.md). Every figure here is a
measurement on this machine, and each row says what it measures. None is a time on an A5.

## How the numbers were taken

- **Emulator**: `build/macosx/arm64/release/emulator` of the main checkout, built 2026-10-21; its sources under `emulator/`,
  `toolchain/` and `packages/` are unchanged between that checkout's main and this branch. A run is
  `emulator boot --rootfs CLONE --device iPhone4,1 --display headless --gles-backend software --binary /usr/local/bin/bench --ticks 20000000000 --perf-summary`
  on a clone of `~/.revenant/firmware/rootfs/iPhone4,1/6.1.3_10B329`. The guest runs the program as pid 1, so no launchd
  or SpringBoard work is in the count.
- **cpu-ticks** is the guest instruction count of the whole run, with `--ticks` as a deterministic clock. Two runs of the
  same binary gave the same count (zlib baseline, 675,040,888 both times).
- **page-misses** is the emulator's guest page-miss counter. It did not move with the binary's text: a `hello` that
  prints one line, the zlib benchmark and the opus benchmark all show 330 to 333. It is not a page-in count for an image's
  own text, and the layout rows below therefore use the block profile instead.
- **Distinct text pages** are counted from `perf/block-profile.tsv` (written by `--perf-block-profile`): the 4 KB pages of
  the benchmark image that hold an executed block, with the image's `__TEXT` at `0x4000`.
- **Text size** is the `__text` section of the binary, from `size -m`.
- **Toolchain**: the packaged clang 23.1.3 (`packages/l/llvm`, digest `206f38c2`) and the iPhoneOS 16.4 SDK, both
  from the local store. The profile runtime is built from compiler-rt 23.1.3 sources (`llvmorg-23.1.3`, sparse clone), not
  from a patched llvm. Merging used the official `LLVM-23.1.3-macOS-ARM64` release tools (`llvm-profdata`); the Command
  Line Tools' `llvm-profdata` (Apple LLVM 21) refused the raw profile of version 11.

## PGO on zlib 1.3.2

zlib at the pin of `packages/z/zlib` (`da607da7`), built for armv7 ios 6.0 with `-O2 -mcpu=cortex-a9 -mfpu=neon`, with a
benchmark of `compress2` at level 6 and `uncompress` over 512 KB of compressible data, six rounds. The training profile
used seed 2026 and the evaluation seed 7, so the profile was not measured on its own data.

The profile is `llvm-profdata` of one run of the instrumented build: 111 functions, 1477 blocks, total count 166,013,307.
The hottest functions are `longest_match` (31,512,882 in its hottest block), `slide_hash`, `deflate_slow`, `inflate_fast`
and `adler32_z`.

| build | cpu-ticks | text | checksum | page-misses |
| --- | ---: | ---: | --- | ---: |
| `-O2` | 675,040,888 | 53,756 bytes | 49cb132d | 330 |
| `-O2 -fprofile-instr-use` | 717,878,512 (+6.3%) | 45,264 bytes (−15.8%) | 49cb132d | 330 |

The baseline ran twice to the same count. The PGO build executes 6.3% more guest instructions on this workload and is
15.8% smaller in text. The instruction count is not a time: the change may or may not be faster on the A9, and the
explanation's PGO section says what is needed to decide it. No block profile of either zlib build was obtained: the PGO
run with `--perf-block-profile` was still running after five and a half minutes and was stopped by pid, and the baseline's
run stopped at its 400-second limit.

The instrumented training run itself, with the profile runtime writing `/private/var/root/zlib.profraw`, gave the same
checksum (`cd9315c0` with seed 2026, the same as the uninstrumented build with that seed).

## Order file on libopus 1.5.1

libopus at the pin of `packages/o/opus` (1.5.1, the store's armv7 build of `libopus.a`, which carries the NEON
silk and celt paths). Two programs use it, both linked with `clang -O2 -mcpu=cortex-a9 -mfpu=neon -lm`, and both through
the host linker.

- `bench`: encode and decode of 150 VOIP frames of 20 ms at 24 kbit/s, with a deterministic input.
- `startup`: the same with one frame, as a launch-like path.

The order file was made from the block profile of `bench` by `toolchain/tools/order_file/order_file.lua --image bench`:
217 functions with executed blocks, hottest first.

| run | layout | cpu-ticks | page-misses | distinct text pages executed |
| --- | --- | ---: | ---: | ---: |
| bench | default | 168,297,703 | 333 | 60 of 61 |
| bench | `-order_file` | 168,297,703 | 333 | not measured |
| bench, block profile | default | 168,297,703 | 378 | 60 |

The binary's text is 247,472 bytes in the default layout and 248,042 in the ordered one. The checksum is 443282e1 in every
run. `bench` executes 60 of the binary's 61 text pages, so an order file has nothing to gather on it: this trace covers the
library's text.

The `startup` program is one frame of the same encode and decode, which is what a launch path of a voice call looks like
in miniature. Its trace was not the one that made the order file, so the order is the full run's, applied to a shorter run.

| run | layout | checksum | cpu-ticks | distinct text pages executed |
| --- | --- | --- | ---: | ---: |
| startup | default | 2ce84a64 | 3,616,959 | 59 |
| startup | `-order_file` | 2ce84a64 | 3,616,959 | 51 |

The layout moved 8 pages out of the run's footprint, 14%, and left the instruction count unchanged, as a layout should. The
counter `page-misses` read 334 in both, so it is not the measure of this effect, as the note above says.

The block profile of a run costs time and changes the page-miss count (333 to 378 on the same binary). It is used here only
for the set of pages an execution touches, never for the count in the table of the emulator.

## Code generation on armv7

Four functions, in `toolchain/tests/data/optimisation/codegen.c`, compiled with the packaged clang at `-O2 -mcpu=cortex-a9
-mfpu=neon` for `armv7-apple-ios6.0`, in the default Thumb-2 mode. The results were the same in ARM mode (`-marm`).

| function | role | the loop body |
| --- | --- | --- |
| `xor16_alias` | missed | for each byte, two loads, an `eor` and a store: 64 instructions, no `veor` |
| `xor16_restrict` | control | `vld1.8`, `vld1.8`, `veor`, `vst1.8` |
| `mul_add_words_carry64` | missed | 8 instructions per word: `ldr`, `ldr`, `adds`, `adc`, `subs`, `umlal`, `str`, `bne`, no `umaal` |
| `mul_add_words_carry32` | control | 6 instructions per word: `ldr`, `subs`, `ldr`, `umaal`, `str`, `bne` |

The UMAAL miss is 2 instructions of 8 per word (a quarter of the loop), and the NEON miss is 60 instructions of 64 on a
16-byte operation. Both are the patch plan's first two items in the explanation.

Two further forms were looked at and are not missed. A single 64-bit addend, `(uint64_t)a * w + c`, is `mov` and `umlal`,
which is as short as UMAAL can be with one addend. The 32-bit-carry multiply loop of boringssl's `bn_mul_add_words`
compiles to `umaal` as the control does.

## Emulator observations

- A Thumb `main` given with `--binary` faults at `pc=0x8004`, the third Thumb instruction of `main`, with the CPSR's
  Thumb bit clear (`[cpu] fatal pid=1`): the entry is taken in ARM state, since `LC_MAIN` carries no Thumb bit. The same
  program built with `-marm` runs. Not investigated further; the `emulate` path, which starts `main` through dyld, was not
  tried with this program.
- `--perf-block-profile` on the zlib benchmark, at about 675 million instructions, ran past five and a half minutes for
  the PGO build and past its 400-second limit for the baseline; the opus benchmark at 168 million instructions finished in
  a few minutes. The profile is for pages and shapes, not for timing.

## Not measured

- A time on an A5, for any row. That is a device run with the device skill, on the same build.
- Telegram 13. It is not built on this machine.
- The effect of PGO on the TLS and crypto code of boringssl, the decoders of libwebp and dav1d, or Telegram's own code.
- objc_direct and the launch cost of the Backports: no build here measures either.
