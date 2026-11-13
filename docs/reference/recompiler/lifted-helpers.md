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

## What is not covered

SHA-512 and SHA-3 (`SHA512H`, `SHA512H2`, `SHA512SU0`, `SHA512SU1`, `EOR3`, `BCAX`, `RAX1`, `XAR`) are not decoded and
not lifted. The iOS 6 target has no `hw.optional.arm.FEAT_SHA512` sysctl, so BoringSSL does not take its paths for
them there.

## How it is checked

The `crypto` check of the corpus ([corpus.md](corpus.md)) compares every helper with the hardware instruction on
random inputs, runs the FIPS 197 and FIPS 180-4 vectors through them, checks the lifter's declarations against the
prototypes of `crypto.c`, and proves that the lifted code links against them for armv7.
