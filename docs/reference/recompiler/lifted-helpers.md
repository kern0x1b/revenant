# Runtime helpers of the lifted code

An armv7 target has no machine instruction for the AES, SHA-1, SHA-256 and polynomial multiply instructions of the
ARMv8 Crypto extension, nor for the conversions between half and single or double precision, so rellume does not lower
them to an LLVM intrinsic. It lifts each one to a call of a C function that the embedding provides, and
`recompiler/src/runtime/crypto.c` and `half.c` are that embedding for the recompiler. Every lift path that meets one of
these instructions calls the same symbols with the contract below, so that no two paths disagree about it.

## The contract

- A helper is named `rellume_aarch64_<name>` and returns `void`.
- The first argument is the destination register `vd`, a pointer to 16 bytes that hold its value before the
  instruction and receive its value after. Where the instruction does not read its destination (`AESMC`, `AESIMC`,
  `PMULL`), the 16 bytes are not initialised.
- The other vector operands follow as pointers to 16 bytes (`vn`, `vm`) that the helper only reads. The buffers are
  8-byte aligned and never overlap.
- A scalar operand follows by value: the `S` register of `SHA1C`, `SHA1P` and `SHA1M` as a `uint32_t`, and the two
  64-bit halves of `PMULL` as `uint64_t`.
- The half-precision conversions are the exception: rellume holds a half as an `i16`, so a conversion helper takes the
  scalar by value, returns the result, and has no `vd` (`uint32_t` for a half, `float` and `double` for the others).
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
| `FCVT Hd, Sn` | `rellume_aarch64_fcvt_h_s` | `uint32_t (float value)` |
| `FCVT Hd, Dn` | `rellume_aarch64_fcvt_h_d` | `uint32_t (double value)` |
| `FCVT Sd, Hn` | `rellume_aarch64_fcvt_s_h` | `float (uint32_t half)` |
| `FCVT Dd, Hn` | `rellume_aarch64_fcvt_d_h` | `double (uint32_t half)` |

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
- `FCVT` between a half and a single or a double rounds to nearest even, keeps the sign of a zero and of an infinity,
  turns a NaN into a quiet NaN with the payload bits that fit, and handles subnormals in both directions. A double
  becomes a half in one rounding, not through a single. Without these helpers the conversion would be a call of
  `__truncsfhf2`, `__truncdfhf2` or `__extendhfsf2`, which the iOS 6 shared cache does not have.

## Lifted without a helper

Some instructions BoringSSL uses on arm64 have an LLVM equivalent, so rellume lifts them to plain IR.

- `SLI` and `SRI` shift each lane of `vn` and insert it into `vd`, keeping the bits of `vd` that the shift does not
  fill: a shift, a mask and an OR on the lane vector. BoringSSL's ChaCha20 (`ChaCha20_512_neon`,
  `chacha20_poly1305_seal` and `_open`) rotates with `USHR` and `SLI`. `SRI` by the element size leaves `vd` unchanged.
- `SADDLV` and `UADDLV` extend every lane to double width and add them into one scalar (`llvm.vector.reduce.add`).
- `TRN1` and `TRN2` interleave the even or the odd lanes of two vectors.
- `ADC`, `ADCS`, `SBC`, `SBCS` and `NGC` compute `Rn + Rm + carry`, with `NOT(Rm)` for the subtracting forms. The flags
  come from that sum: the carry from a comparison of the sum with `Rn` that depends on the carry in, the overflow from
  the signs of the operands and of the sum. The lifter used to add the carry to `Rm` first, which wraps when `Rm` is
  all ones, and set the carry flag from the wrapped value. BoringSSL's Poly1305 reduces its accumulator with an `ADDS`
  and two `SBCS` against all ones, so the tag of a 1000-byte ChaCha20-Poly1305 message was wrong on the phone whenever
  the top limb of the accumulator was 3.

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

`pmull8` is one `vmull.p8`. `pmull64` builds the 128-bit product from eight of them, in registers only. With the
operands as bytes `a_i` and `b_j`, the product is the sum of the 15-bit products `a_i * b_j` at byte offset `i + j`.
`vmull.p8` of the operands gives the pairs with `i = j`. Rotating one operand by `r` bytes (`vext`) pairs `a_i` with
`b_(i+r mod 8)`, which gives every pair with `j - i = r` or `j - i = r - 8`; rotating the other operand gives the pairs
with `i - j = r` or `i - j = r - 8`. For `r` = 1, 2 and 3 both products are needed, for `r` = 4 they are the same
pairs and one is enough: 1 + 2 * 3 + 1 = 8 multiplies. The lanes whose pair wrapped around are shifted by `r - 8`
bytes instead of `r`, which a mask and two `vext` do. No operand selects an address or a branch, and the same source
compiles for armv7 and arm64, so the corpus check runs it on this Mac's hardware against `PMULL` itself.

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
| `PMULL` on 64-bit lanes (`pmull64`, shift and xor, replaced) | 771 ns |
| `PMULL` on 8-bit lanes (`pmull8`, bit loop, replaced) | 202 ns |

Through xlate, the lifted loops of `tests/cryptodevice` take 360 ns for an `AESE` followed by an `AESMC`, 452 ns for an
`AESD` followed by an `AESIMC`, 114 ns for a `PMULL` on 64-bit lanes and 53 ns on 8-bit lanes. Before the `vmull.p8`
versions the same loops took 781 ns and 225 ns, so `pmull64` is 6.8 times and `pmull8` 4.2 times faster (the bit-sliced
`AESE` took 2965 ns for the first pair). A 10-round AES-128 block is about 3.6 us.

BoringSSL, translated whole from `libswiftCryptoKit.dylib` (`tests/cryptoboringssl`, 256 KiB in 16 KiB pieces), runs
SHA-256 at 10.6 MB/s, AES-256-GCM sealing at 3.0 MB/s and ChaCha20-Poly1305 sealing at 13.0 MB/s on the same phone.
AES-256-GCM sealed at 2.1 MB/s with the shift-and-xor `pmull64`. It is now bounded by AES: 14 rounds of `AESE` and
`AESMC` at 360 ns are 5 us for each 16-byte block, which is 3.0 MB/s, and the `pmull64` of the GHASH are under a tenth of that.

`crypto.c` uses NEON on the host, which every armv7 iOS device has (the 3GS and later).

## What is not covered

`recompiler/tools/coverage.lua` lists what xlate leaves unlifted in the real images: `./xmakew l -P . recompiler/tools/coverage.lua <out>
<arm64 image>...` runs `xlate --coverage` on each image, disassembles it with `llvm-objdump`, and writes
`<out>/coverage-report.txt` with the unlifted words grouped by mnemonic, with their count per image and the functions that
own most of them. Over the Recaptcha SDK and the twelve images of the libswift and C++ runtime set (2,082,346
instructions) it found 9489 unlifted words before the SLI, SRI, UADDLV and FCVT lifts and finds 9014 now:

| Words | What | Why it is left |
|---|---|---|
| 8757 | `BRK` | the trap that compilers emit (`brk #1` after a Swift precondition); rellume leaves it unlifted on purpose, so reaching one faults, as the instruction does |
| 52 | `UDF` | the same, `udf #imm` |
| 47 | zero words | alignment padding between functions of `libswiftCryptoKit`, which `llvm-objdump` does not list as instructions |
| 14 | ASCII text | the banners `Montgomery Multiplication for ARMv8, CRYPTOGAMS by <appro@openssl.org>` and `GHASH for ARMv8, CRYPTOGAMS by <appro@openssl.org>` that BoringSSL's perlasm leaves after the `ret` of `__bn_mul4x_mont` and `gcm_ghash_v8_4x`; the 14 of their words that read as an unlifted instruction (`STNP`, `LDAPURH`, `FNMLS`, `UQSHL` and eight that objdump leaves as `<unknown>`) are text, and no code reaches them |
| 144 | `SHA512H`, `SHA512H2`, `SHA512SU0`, `SHA512SU1` | not reachable on iOS 6, below |

SHA-512's hardware routine, `sha512_block_data_order_hw` of `libswiftCryptoKit`, has one caller. `sha512_block_data_order`
calls `OPENSSL_get_armcap()` and branches to it only on `tbnz w0, #6`, the SHA-512 bit, which BoringSSL sets from the
sysctl `hw.optional.armv8_2_sha512`. The iOS 6 kernel has no such sysctl: the capability word the program prints on the
iPhone 4S is `0000003d` (NEON, AES, PMULL, SHA-1, SHA-256), and bit 6 is clear. The routine therefore never runs and is
left unlifted, so that if it did run it would fault as an unsupported instruction instead of computing something else.
`EOR3`, `BCAX`, `RAX1` and `XAR` (SHA-3) are in none of the images.

## How it is checked

The `crypto` check of the corpus ([corpus.md](corpus.md)) compares every helper with the hardware instruction on
random inputs (`AESE` and `AESD` also on every byte value in every position; the half-precision widening on all 65536
halves and the narrowing around every half value), runs the FIPS 197 and FIPS 180-4 vectors through them, checks the
lifter's declarations against the prototypes of `crypto.c` and `half.c`, runs the lifted functions natively against the
hardware (this is also where the instructions lifted without a helper are proved), and proves that the lifted code links
against them for armv7. `pmull8` is compared with a bit-by-bit product, which is not the instruction it is built from.
