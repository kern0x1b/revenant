# Runtime helpers of the lifted code

An armv7 target has no machine instruction for the AES, SHA-1, SHA-256 and polynomial multiply instructions of the
ARMv8 Crypto extension, so rellume does not lower them to an LLVM intrinsic. It lifts each one to a call of a C
function that the embedding provides, and `recompiler/src/runtime/crypto.c` is that embedding for the recompiler.
Every lift path that meets one of these instructions calls the same symbols with the contract below, so that no two
paths disagree about it.

## The contract

- A helper is named `rellume_aarch64_<name>` and returns `void`.
- The first argument is the destination register `vd`, a pointer to 16 bytes that hold its value before the
  instruction and receive its value after. Where the instruction does not read its destination (`AESMC`, `AESIMC`,
  `PMULL`), the 16 bytes are not initialised.
- The other vector operands follow as pointers to 16 bytes (`vn`, `vm`) that the helper only reads. The buffers are
  8-byte aligned and never overlap.
- A scalar operand follows by value: the `S` register of `SHA1C`, `SHA1P` and `SHA1M` as a `uint32_t`, and the two
  64-bit halves of `PMULL` as `uint64_t`.
- Lane `i` of a vector is at byte offset `i * size`, little-endian, which is the memory layout of the LLVM vector
  types the lifter uses (`<16 x i8>`, `<4 x i32>`, `<8 x i16>` and `<2 x i64>`).
- The lifter declares each helper `nounwind willreturn nosync nofree` and `memory(argmem: readwrite)`: a helper reads and
  writes only what its arguments point to, never throws and never blocks.
- The buffers are `alloca`s of the entry block of the lifted function, three at most, shared by all the calls of that
  function, so that a loop does not grow the stack and a function with many calls keeps a small frame.

## The helpers

| Instruction | Symbol | C prototype |
|---|---|---|
| `AESE` | `rellume_aarch64_aese` | `void (void *vd, const void *vn)` |
| `AESD` | `rellume_aarch64_aesd` | `void (void *vd, const void *vn)` |
| `AESMC` | `rellume_aarch64_aesmc` | `void (void *vd, const void *vn)` |
| `AESIMC` | `rellume_aarch64_aesimc` | `void (void *vd, const void *vn)` |
| `SHA1C` | `rellume_aarch64_sha1c` | `void (void *vd, uint32_t sn, const void *vm)` |
| `SHA1P` | `rellume_aarch64_sha1p` | `void (void *vd, uint32_t sn, const void *vm)` |
| `SHA1M` | `rellume_aarch64_sha1m` | `void (void *vd, uint32_t sn, const void *vm)` |
| `SHA1SU0` | `rellume_aarch64_sha1su0` | `void (void *vd, const void *vn, const void *vm)` |
| `SHA1SU1` | `rellume_aarch64_sha1su1` | `void (void *vd, const void *vn)` |
| `SHA256H` | `rellume_aarch64_sha256h` | `void (void *vd, const void *vn, const void *vm)` |
| `SHA256H2` | `rellume_aarch64_sha256h2` | `void (void *vd, const void *vn, const void *vm)` |
| `SHA256SU0` | `rellume_aarch64_sha256su0` | `void (void *vd, const void *vn)` |
| `SHA256SU1` | `rellume_aarch64_sha256su1` | `void (void *vd, const void *vn, const void *vm)` |
| `PMULL`, `PMULL2` on 8-bit lanes | `rellume_aarch64_pmull8` | `void (void *vd, uint64_t n, uint64_t m)` |
| `PMULL`, `PMULL2` on 64-bit lanes | `rellume_aarch64_pmull64` | `void (void *vd, uint64_t n, uint64_t m)` |

`SHA1H` has no helper: it is a rotate of the `S` register by 30, which the lifter emits as a funnel shift.

The semantics are those of the Arm Architecture Reference Manual's pseudocode, which the names below are taken from.

- `AESE` is `AESSubBytes(AESShiftRows(vd EOR vn))`, and `AESD` is `AESInvSubBytes(AESInvShiftRows(vd EOR vn))`. `AESMC`
  and `AESIMC` write `AESMixColumns(vn)` and `AESInvMixColumns(vn)`, the columns being the four 32-bit lanes.
- `SHA1C`, `SHA1P` and `SHA1M` run four SHA-1 rounds on `vd` (the words a to d) and `sn` (the word e), with the
  `SHAchoose`, `SHAparity` and `SHAmajority` functions, and the four words of `vm` as the schedule plus constant.
  `SHA1SU0` and `SHA1SU1` are the two halves of the message schedule step.
- `SHA256H` writes the new words a to d, and `SHA256H2` the new words e to h, of four SHA-256 rounds. `SHA256H` takes
  `vd` as a to d and `vn` as e to h; `SHA256H2` takes `vd` as e to h and `vn` as a to d. `SHA256SU0` and `SHA256SU1` are
  the two halves of the message schedule step.
- `PMULL` multiplies carry-less. The lifter picks the low halves of `vn` and `vm` for `PMULL` and the high halves for
  `PMULL2`. `pmull8` then multiplies the eight bytes pairwise into eight 16-bit lanes, and `pmull64` multiplies the two
  64-bit values into 128 bits, the low half at `vd[0]`.

## Timing

The instructions take the same time for every operand, and the guest chose them for that reason, so the helpers must
not give an operand any influence on the memory they touch or the branches they take. None indexes memory by data or
branches on data. `AESE` and `AESD` look every byte up in the 256-byte S-box with NEON table lookups: the table is
read in eight windows of 32 bytes, each window answers `vtbl4` for the bytes whose index falls in it and 0 for the
others, and the eight answers are OR-ed. All 256 entries are read at the same addresses for every input, so a
cache-timing observer sees nothing of the key or the data. ShiftRows is a `vtbl2` with a constant permutation. The
same source compiles for armv7 and arm64 (`vtbl4_u8` is in both), so the corpus check runs it on this Mac's hardware
against the instruction itself.

The first version of `AESE` and `AESD` computed the S-box bit-sliced, as the inverse in GF(2^8) of 16 bytes at once,
with no table. It was also constant-time and cost 2851 ns per `AESE` on an iPhone 4S, about 99% of the 2965 ns of an
`AESE` followed by an `AESMC` in lifted code: the call and the buffer traffic around it are 17 ns. The NEON lookup is
11 times faster.

### Cost on an iPhone 4S

Measured on iPhone4,1 (A5) with iOS 6.1.3, by calling each helper in a loop from armv7 code compiled as the
translation compiles it, and by running the arm64 fixture of `tests/cryptodevice` through xlate:

| Helper | Time per call |
|---|---|
| a call that xors 16 bytes (the cost of calling a helper) | 17 ns |
| `AESE`, `AESD` (NEON table lookup) | 252 ns |
| `AESE`, `AESD` (bit-sliced, replaced) | 2851 and 2918 ns |
| `AESMC` | 73 ns |
| `AESIMC` | 163 ns |
| `PMULL` on 64-bit lanes (`pmull64`) | 771 ns |
| `PMULL` on 8-bit lanes (`pmull8`) | 202 ns |

Through xlate, the lifted loops of `tests/cryptodevice` take 358 ns for an `AESE` followed by an `AESMC`, 453 ns for an
`AESD` followed by an `AESIMC`, 781 ns for a `PMULL` on 64-bit lanes and 225 ns on 8-bit lanes (the bit-sliced version
took 2965 ns for the first pair). A 10-round AES-128 block is about 3.6 us.

BoringSSL, translated whole from `libswiftCryptoKit.dylib` (`tests/cryptoboringssl`, 256 KiB in 16 KiB pieces), runs
SHA-256 at 10.9 MB/s and AES-256-GCM sealing at 2.1 MB/s on the same phone. A GHASH block takes
two to four `pmull64`, so AES-GCM is bounded by `pmull64` before it is by `AES`. `pmull64` is the helper to speed up
next: the NEON `vmull.p8` instruction multiplies eight bytes at once, and a 64x64 product from it needs eight of them
and a few shifts, which should be about five times faster than the 64 masked shift-and-xor steps of the portable
version (an estimate, not a measurement). It is not done, because the SDK's AES-GCM load is small.

`crypto.c` uses NEON on the host, which every armv7 iOS device has (the 3GS and later).

## What is not covered

SHA-512 and SHA-3 (`SHA512H`, `SHA512H2`, `SHA512SU0`, `SHA512SU1`, `EOR3`, `BCAX`, `RAX1`, `XAR`) are not decoded and
not lifted. The iOS 6 target has no `hw.optional.arm.FEAT_SHA512` sysctl, so BoringSSL does not take its paths for
them there.

## How it is checked

The `crypto` check of the corpus ([corpus.md](corpus.md)) compares every helper with the hardware instruction on
random inputs (`AESE` and `AESD` also on every byte value in every position), runs the FIPS 197 and FIPS 180-4 vectors through them, checks the lifter's declarations against the
prototypes of `crypto.c`, and proves that the lifted code links against them for armv7.
