# The corpus and the benchmark

`tests/` holds the translator's own regression programs and `tests/perf/` its benchmark. Their sources are C, Objective-C,
assembly and Swift. The steps that build, translate and check them are Lua run by xmake: a `check.lua` or `build.lua`
beside the sources, and the shared parts in `recompiler/tools/` (`env.lua`, `corpus.lua`, `translate.lua`, `macho.lua`).

## Running

From the revenant root, after `./xmakew f -P . -y` and `./xmakew build -P . xlate xlgen`:

```sh
./xmakew test -P . 'recompiler_corpus/*'
./xmakew build -P . recompiler_cxxinit recompiler_refrepro recompiler_blockid recompiler_devtime
```

`recompiler_corpus` runs the host part of every check it declares: jumptable, switchtail, tailcalls, tsdscan, tsdguard,
int128, weakimport, lse, llsc, crypto, library, exceptions, libexceptions, libcxxexceptions, objectsplit, segmentlimit, absolutes, rebasetag, flagflow, hostbridges, checkapi, proxytable, systemclasses and dropkey; `classpair` and `ordinal` are the device group's, which also runs the
device part of `exceptions`, `libexceptions`, `libcxxexceptions` and `hostbridges`. Their output goes to the
target's build folder (`build/.gens/recompiler_corpus/.../tests/<name>`). The four
build targets each leave an `.app` or an executable in their own target folder.

A check that also has a device part is run by hand, with the output folder as its argument:

```sh
./xmakew l -P . recompiler/tests/weakimport/check.lua <out>
./xmakew l -P . recompiler/tests/classpair/check.lua <out>
./xmakew l -P . recompiler/tests/exceptions/check.lua <out>
./xmakew l -P . recompiler/tests/libexceptions/check.lua <out>
./xmakew l -P . recompiler/tests/libcxxexceptions/check.lua <out>
./xmakew l -P . recompiler/tests/hostbridges/check.lua <out>
./xmakew l -P . recompiler/tests/systemclasses/check.lua <out>
./xmakew l -P . recompiler/tests/swiftconformance/check.lua <out>
./xmakew l -P . recompiler/tests/swiftobjc/check.lua <out>
./xmakew l -P . recompiler/tests/libgenerics/check.lua <out>
./xmakew l -P . recompiler/tests/cryptodevice/check.lua <out>
./xmakew l -P . recompiler/tests/cryptoboringssl/check.lua <out>
```

A check translates with the `xlate` and `xlgen` that are in `build/`, and a script run with `./xmakew l -P .` does not build them
(`./xmakew test -P .` does, they are dependencies of the targets). `env.lua` therefore stops a run whose `xlate` or `xlgen` is
older than one of its sources (the files of the target, and for `xlate` the headers of `recompiler/src/xlate`), naming the
command to run: `./xmakew build -P . xlate xlgen`. Before that, a worker that merged a change of the generator and translated
the fixture with the old binary got a library without it: on 2026-11-14 a checkout of main translated libgenerics with an
`xlgen` 16 hours older than `xlgen.cpp` and an `xlate` older than `objc.cpp`, and its report had 257 typed host IMPs where the
rebuilt tools gave 272, so the steps that run on the generic classes' methods did not run the same code.
`toolchain/tests/addon/recompiler_fresh_test.lua` tests the comparison.

These need a claimed device (the skill `device`):xported and the claim held. They reach the device through Revenant's `device` module. Without an argument, output goes
to `build/recompiler/corpus/<name>`.

A check that goes to the phone does not start unless its holder has claimed it: `corpus.device()` refuses with
"does not hold it" when `REVENANT_DEVICE_HOLDER` is empty, when nobody has claimed the phone, and when somebody else has.
The module alone only refuses a second holder, so a check run without a claim used to reach an unclaimed phone. The
string `--host-only` and the table `{host_only = true}` (what `xmake test` passes) mean the same in every check, and so
do `--device-only` and `{device_only = true}`: `corpus.options(...)` reads both.

Every file a check puts on the phone goes into one folder, `/var/root/revenant-scratch/<holder>/`, which
`corpus.device()` returns as `scratch` and creates before the first copy or run. A check deletes its own binaries
right after the run, and `xmake device release` erases the folder, so a finished window leaves nothing on the phone's
internal partition. Nothing in the corpus writes to `/var/tmp` or `/tmp` on the phone.

## What each check proves

### jumptable

A control for `JumpTables::Resolve` in `src/xlate/xlate.cpp`. At build time, xlate finds where a register-indirect
branch can go: it reads the guest's byte table for every index the branch's guards let through.

The demo crashed past `_DictionaryStorage.allocate` with "jump to an address that does not start a translated
function". The cause was a missed target in libswiftCore's demangler (`getUnspecialized`):

- Its table dispatch has two guards, `(kind - 13) unsigned >= 6` and `kind <= 0x10f`, so the indices that reach the
  table read are {0..12} and {19..271}, with a gap between them.
- The old code took the first run, 0..12. It stopped the whole scan at index 13, on the belief that the domain is one
  contiguous range.
- Everything reachable only through 19..271 was never a candidate, and xlate said nothing about it.

`dispatch.s` reproduces that shape with the exact instructions. A C switch is not reliably lowered to them. Kinds 2
and 3 are diverted before the table is read, so the domain is {0, 1} and {4, 5}. There are four distinct case bodies;
the old code found two.

The check builds the libc-free driver `main.c`, feeds it to xlate, and requires the exact reported count of four
targets. Requiring "not zero" would let a partial regression (two or three targets) pass. This is host only: it
checks xlate's build-time discovery, not the guest at run time.

A second binary, `inline.c` with `inline.s`, covers a jump table that sits inside `__text`. ld64 lists such a table's
symbol in `LC_FUNCTION_STARTS` as if it were a function, and the words of a table are data: a `udf`, or an
address, that is not an instruction. xlate used to lift each word as a function and count it as a failure (the
image linked from the 319 objects of Google's reCAPTCHA Enterprise SDK had three: "3 failures", now
"0 failures, 3 jump table data words"). `JumpTables` now keeps the words of every table it resolved, and the lift
loop skips a listed start that lies in one and counts it as `table data` in the summary line. The check requires the
exact line `4 jump table targets, 0 failures, 1 jump table data words`.

A third binary, `hoisted.c` with `hoisted.s`, covers a table whose base register is set before a call and read after
it. Rellume writes every register to the state before a call and reads it back after, so the base after the call is an
opaque load, and the same `getUnspecialized` of the new libswiftCore (x22 set once, a call to `isSpecialized` in a
loop, then `adr`, `ldrb`, `add`, `br`) was not resolved: the guest jumped into the middle of the function and stopped
with "jump to an address that does not start a translated function", for example on `String(describing:)` of a struct.
`JumpTables` now clones only the functions that contain a `br`, and in the clone every call keeps x19 to x29 and sp as
they were before it, which is what the AAPCS64 promises, then runs `GVN` so that the loads after the call take the
values before it. The check requires exactly `4 jump table targets`. On the guest `libswiftCore` the lift finds 44
more targets than before (2413 against 2369).

### switchtail

A control for the lift of the targets of a jump table as entries of the function that holds the table, not as functions
of their own. Rellume lifts every function with the whole control-flow graph that is reachable from its start, so a
function that was lifted once for the function and once for each case of its `switch` carried the code that all the
cases share (the tail after the `switch`) as many times as there were cases. In the reCAPTCHA Enterprise SDK this was a
quarter of the lifted code (libc++'s `num_get` alone, 13 copies of about 260 KB). `xlate` lifts the targets as additional
entries of the function (rellume patch 0012, `ll_func_decode_entry`): the entry block loads `pc` from the state and
switches to one stub per entry, which unpacks the registers from the state and branches to its own block; blocks reached
from several entries exist once. An indirect jump that can still reach such a target (its `pc` is not a constant)
becomes a `switch` on `pc` whose cases call the function again with `musttail`, and whose default is the old `xl_tail`.
The runtime table of functions maps the address of every entry to the function, so a call from outside enters at the
right place.

`main.c` is a `switch` of 24 cases (each calls its own function) followed by a tail of 48 unrolled steps. The check builds
it for the Mac and for iOS, translates the iOS binary and requires at most 80 lifted functions and at most 12,000 lines
of IR in them (70 functions and 7,530 lines on the author's machine; with the 24 targets as functions of their own it
was 94 or more and 21,100), and, with `--host-only` left out, that the translated program prints on the phone what the
Mac program prints.

### tailcalls

A control for the lift of a branch to the start of another function as a tail call. `Function::Decode` of rellume follows
every direct branch, so a function that ends in `b other` carried a copy of `other`, and of everything `other` branches
to, so a chain of N functions that branch to the next was N(N+1)/2 copies; in the reCAPTCHA Enterprise SDK this was 69 %
of the lifted code. The decoder stops at an address that starts another function (rellume patch 0013,
`ll_config_set_function_start_cb`; the fall-through into such an address stops too) and the branch becomes a `musttail`
call of that function with the state, so the stack does not grow. In a function with landing pads the lowering turns
that `musttail` into a plain call, which in SjLj has call-site index -1: an exception that leaves the callee passes the
frame of the caller and is not dispatched to the caller's pads, which is what the native frame, already gone after the
branch, would do.

A function has one exit block, whose `pc` is a phi of the `pc` of every jump out of it, so a jump to the constant address
of a function went through `xl_tail` and its binary search of the function table, not to the function. Every such jump
now gets a copy of the exit block with a constant `pc` (`Lifter::SplitExits`), and the call is direct. Measured on an
iPhone 4S, a pipeline of eight stages that each hand over with a tail call (the `tailchain` kernel of
[devtime](#perf-devtime)) takes 19.0 ms through `xl_tail` and 2.93 ms with direct calls, which is what the code of the
old lift, with the stages inlined into each other, takes too; the SDK image grows by 2.4 % for it (55,567,600 bytes
against 54,271,808).

`main.c` has a chain of 51 functions, each with a frame of its own, a mark in memory that `main` reads (so that the lift
cannot fold the chain away) and a `musttail` call of the next one; two functions that call each other 300,000 times with
`musttail` (the host stack must stay constant, or the program dies of a stack overflow); and a call through a table of
function pointers. The check builds it for the Mac and for iOS, requires at least 40 `b link<N>` branches from one link
to the next in the arm64 code (so the compiler did emit the tail calls), translates it and requires that none of the 50
functions that end in a tail call reaches the next through `xl_tail` and that together they are at most 9,000 lines of IR
(4,177 on the author's machine; the old lift made them 33,704), and, with `--host-only` left out, that the translated
program prints on the phone what the Mac program prints. The exception side (a function with a landing pad that ends in
a tail jump into a function with a landing pad of its own, and a throw that leaves the second) is `stepTail` of
[libexceptions](#libexceptions).

### lse

A control for rellume's lifting of the ARMv8.1 LSE atomics: LDADD, LDCLR, LDEOR, LDSET, LDSMAX, LDSMIN, LDUMAX,
LDUMIN, SWP and CAS.

`main.c` defines 200 functions, one per operation, access width (8, 16, 32 and 64 bits) and memory order (relaxed,
acquire, release, acq_rel and seq_cst). It is built for arm64 with `-march=armv8.1-a`, so clang emits each as one LSE
instruction rather than an exclusive loop. The check proves three things, all on the host:

1. The arm64 binary carries the expected form in every function: the right mnemonic, the right ordering and size
   suffixes, and `w` or `x` registers.
2. xlate lifts every function, and each lifted function holds exactly one `atomicrmw` or `cmpxchg`, with the
   operation, the integer width, the alignment and the LLVM ordering its instruction asks for. A and L together
   become `acq_rel`, which is also what seq_cst compiles to.
3. The lifted code, compiled for armv7 with the flags `recompiler/tools/translate.lua` uses, carries the byte, halfword, word and
   doubleword exclusive pairs the atomics are lowered to. The program is libc-free and has no Objective-C or blocks,
   which the runtime a full translation links expects, so the check stops at the lifted object.

The lifted IR is checked, not only xlate's failure count. Without the LSE cases, xlate reported 180 of the 200 functions
as undecodable: those whose atomic is the first instruction. The 20 `and` functions start with an `mvn`. rellume
lifted each of them up to the atomic and ended it with an exit to that instruction's guest address. xlate counted
those as lifted, and the program would only fail when it got there.

### llsc

A control for rellume's lifting of the exclusive loads and stores, the loop clang emits for an atomic when the target
has no LSE: `LDXR`, `LDAXR`, `STXR`, `STLXR` and `CLREX`, in the byte, halfword, word and doubleword forms.

`main.c` defines 160 functions: add, and, xor, or, exchange, signed max and unsigned min, and compare-and-swap, in each
access width and each of the five memory orders. It is built with `-march=armv8-a`, so each is an exclusive loop.
The check proves four things on the host:

1. Every function carries the pair its width and order ask for (`ldxr` or `ldaxr`, `stxr` or `stlxr`, with the `b` or
   `h` suffix).
2. xlate leaves no instruction unlifted (`coverage: 0 of ...`, `clrex` among them) and lifts every function.
3. The exclusive monitor is part of the state header (`EXCL_ADDR` and `EXCL_VAL`), and in each lifted function every
   exclusive load is an atomic load of its width (acquire for `LDAXR`) and every exclusive store is a `cmpxchg` that
   expects the loaded value, release for `STLXR`, with no `atomicrmw`. A plain store with a status register of 0,
   which is what `STXR` was lifted to before, has none of these.
4. The lifted code, compiled for armv7, carries the byte, halfword, word and doubleword exclusive pairs.

The monitor remembers the address and the value an exclusive load saw. `STXR` succeeds only when the address is the
recorded one and the `cmpxchg` still finds the recorded value, so a thread that wrote in between makes it fail and
the loop retry. A store that finds the same value written back by another thread succeeds, as it does in a user-mode
emulator; the loops compilers emit are value-based and tolerate it. `LDXP` and `STXP` still lift as a plain load and
store, because a 128-bit `cmpxchg` has no armv7 lowering.

### crypto

A control for the ARMv8 Crypto extension that BoringSSL, and with it CryptoKit, selects at run time on an Apple arm64
CPU: AESE, AESD, AESMC, AESIMC, SHA1C, SHA1P, SHA1M, SHA1H, SHA1SU0, SHA1SU1, SHA256H, SHA256H2, SHA256SU0 and
SHA256SU1, plus the PMULL and PMULL2 that GHASH uses, in their 8-bit polynomial and 64-bit polynomial forms. armv7 has
no instruction for any of them, so the lifter turns each into a call of a helper in `recompiler/src/runtime/crypto.c`;
[Lifted helpers](lifted-helpers.md) is the contract between the two. The check also covers the instructions that
BoringSSL's kernels use and that rellume did not lift or lifted wrongly: TRN1 and TRN2 (the AES-GCM kernel arranges its
GHASH operands with them, and the translated kernel stopped at the first one); SLI and SRI, UADDLV and SADDLV (ChaCha20
rotates with `USHR` and `SLI`); the conversions between half and single or double precision, which a Swift `Float16`
meets (a helper in `recompiler/src/runtime/half.c`); and ADC, ADCS, SBC, SBCS and NGC, whose flags were computed from a
wrapped operand.

`main.c` defines 74 functions: one per instruction, a round of AESE with AESMC, a loop of rounds, TRN1 and TRN2, SLI and
SRI, UADDLV and SADDLV, and FCVT in the element forms and vector widths of each, and the five carry instructions in
their 32- and 64-bit forms with the flags they leave, and the final reduction of Poly1305 (an `ADDS`, two `SBCS` and
three `CSEL`), whose wrong result on the phone found the flag bug. It is built for arm64 with `-march=armv8-a+crypto`,
so clang emits each intrinsic as its instruction; the 64-bit TRN forms and the carry instructions are inline assembly
(`carry.h`, which the oracle includes too, so both run the same instructions), because clang turns the TRN intrinsic
into ZIP and does not pick the carry forms on its own. The check proves six things, all on the host, which is an
Apple-Silicon Mac, so the oracle is the hardware itself:

1. The helpers agree with the instructions. `driver.c` includes `crypto.c` and compares each helper with the ACLE
   intrinsic on 20000 random inputs each (`AESE` and `AESD` also on every byte value in every position). It also runs AES-128 and AES-256 from FIPS 197
   appendix C, encrypting and decrypting with the equivalent inverse cipher (the decryption round keys go through
   AESIMC), and one SHA-1 and one SHA-256 block of `abc` from FIPS 180-4, built from the helpers alone. The half-precision
   helpers are compared with the hardware conversion on all 65536 halves widened to single and double, and on the
   neighbourhood of every half value narrowed (the neighbours, the midpoints, the ties, the values that round up to
   infinity or down to zero, signalling NaNs). `pmull8` is compared with a bit-by-bit product, because on this Mac
   `vmull_p8` is the instruction the helper is built from; `pmull64` with `vmull_p64`.
2. farmdec decodes what an assembler assembles. A sweep of 516512 words (every register combination of each Crypto,
   PMULL, SLI, SRI, SADDLV, UADDLV and FCVT encoding, and a spread of the SIMD space around them) is assembled with
   `llvm-objdump` as the oracle and decoded; the operation, the registers and the arrangement must agree on all of them,
   and no word that `llvm-objdump` rejects may decode as one of these operations (farmdec decodes 632 reserved
   encodings of the last five that `llvm-objdump` rejects; the sweep counts them and no code holds one).
3. xlate lifts every function with 0 failures and leaves no instruction of the fixture unlifted (`coverage: 0 of ...`),
   and each lifted function holds the helper calls of its instruction and no others. SHA1H, a rotate of one word, is
   one `llvm.fshl.i32`.
4. The helper buffers are `alloca` instructions of the entry block, not of the loop that uses them, so the stack does
   not grow with the rounds and no frame is realigned.
5. The lifted functions, compiled natively with the helpers and run on the host, give the hardware's result for every
   function on 4000 states each (the all-zero and all-one states first, then random ones), with the callee-saved
   registers untouched. This is what proves the register
   mapping, the choice of the PMULL halves and the scalar operands, which the IR assertions only describe. The carry
   cases take their operands from a list of edge values (0, 1, 2, all ones, the signed limits, the 32-bit limits) and
   a carry in, because random 64-bit operands almost never wrap: the 2431 mismatches this found in the first version
   were `ADCS` and `SBCS` carry and overflow flags. The lifter's mutants (a mask one bit off in SLI and SRI, the signs
   of UADDLV swapped, the helper names swapped in FCVT) fail this oracle or the IR assertions.
6. The lifted code and the helpers compile for armv7 with the flags `recompiler/tools/translate.lua` uses and link: the
   prototype of every `rellume_aarch64_` function the lifted code declares is the one `crypto.c` and `half.c` define, and no such
   symbol stays undefined.

`recompiler/tools/coverage.lua` measures the same thing on real images: it lists what xlate leaves unlifted in an SDK
and which functions own it. What remains in the Recaptcha SDK and the libswift set, and why, is in
[Lifted helpers](lifted-helpers.md).

### cryptodevice (device part by hand)

The Crypto extension run on a real armv7 phone. `tests/cryptodevice/main.c` takes the vectors of the `crypto` check
(`tests/crypto/vectors.h`: FIPS 197 AES-128 and AES-256 encryption and decryption, and one block each of SHA-1 and
SHA-256 from FIPS 180-4) with the hardware intrinsics in place of the helpers, adds known products of PMULL and PMULL2,
and times a round of AESE and AESMC, a round of AESD and AESIMC, and the two PMULL forms. It prints `ok <name>` or
`FAIL <name>` for each of its 51 checks, and `done`: the ten vectors above, SLI, SRI, UADDLV and SADDLV on known
operands, the half-precision conversions at their boundaries, and the flags of `ADCS` and `SBCS` with an all-ones operand
and of Poly1305's final reduction.

`check.lua <out> --host-only` builds it for the Mac (where it must print all 51 `ok` itself, so a wrong vector is
caught before the phone), compiles it for arm64 with `-march=armv8-a+crypto`, and translates it. `check.lua <out>
--device-only` copies the translated program to the claimed phone and requires all 51 `ok` and exit 0. The times it
prints are in [Lifted helpers](lifted-helpers.md).

### cryptoboringssl (device part by hand)

BoringSSL's own ARMv8 paths run on a real armv7 phone. `tests/cryptoboringssl/main.c` is a C program that links the
`libswiftCryptoKit.dylib` of `revenant@swift-crypto` and calls the BoringSSL functions that library exports
(`CCryptoBoringSSL_SHA256`, `CCryptoBoringSSL_SHA1` and the `EVP_AEAD` interface of AES-128-GCM, AES-256-GCM and ChaCha20-Poly1305). The
library takes its Crypto extension paths on an Apple arm64 CPU without asking the CPU, which the program shows by
printing `OPENSSL_get_armcap()` (`0000003d`: NEON, AES, SHA-1, SHA-256, PMULL; the SHA-512 bit is clear). It checks

- SHA-256 of `abc` and of 1000 bytes, and SHA-1 of `abc`, against known digests;
- AES-128-GCM and AES-256-GCM seals of 16 zero bytes under a zero key and nonce (NIST's test cases) and AES-256-GCM of
  1000 bytes (the oracle for those 1000 bytes is CryptoKit on the Mac), each for the ciphertext, the tag, the open and
  the refusal of a tag with a flipped bit;
- ChaCha20-Poly1305 of RFC 8439 section 2.8.2 (a 114-byte message with 12 bytes of associated data, key `80..9f`; CryptoKit's
  `ChaChaPoly` on the Mac gives the same ciphertext and tag), and of 16 zero bytes and 1000 bytes under a zero key and
  nonce (the oracle is CryptoKit on the Mac), each for the ciphertext, the tag, the open and the refusal of a tag with a
  flipped bit, and for the RFC vector also the refusal of changed associated data. The 1000-byte message takes
  BoringSSL's stitched NEON loop, and its tag came out wrong in its first byte (five too large) until the flags of
  `SBCS` were fixed;
- the throughput of SHA-256, AES-256-GCM and ChaCha20-Poly1305 over 256 KiB.

The translated program imports `libswiftCryptoKit.dylib`, `libswiftCore.dylib` and the C++ runtime as guest images. The
check wants all 28 names `ok`, `done failures=0`, and exit 0. `check.lua <out> --host-only` stops after the translation
(about ten minutes), `--device-only` runs the result on the claimed phone. It needs `XL_SWIFTCRYPTO_LIBS`, the folder
with `libswiftCryptoKit.dylib`, `libswiftCore.dylib`, `libc++.1.dylib` and `libc++abi.1.dylib`, and
`XL_BORINGSSL_INCLUDE`, the `Sources/CCryptoBoringSSL/include` folder of the swift-crypto sources.

It runs the C interface of the library, not CryptoKit's Swift API: the Swift layer needs the Swift runtime images the
Swift fixtures use, and CryptoKit calls these same functions.

### exceptions

A program of Objective-C and C++ (`main.m`, `guarded.mm`) that throws and catches across guest frames. It covers:

- an `NSException` raised in a guest frame (`@throw`) and one raised by the host (`-objectAtIndex:` out of range), both
  caught by a guest `@try` two guest frames up, through a C++ frame whose destructors must run;
- `@catch` of a class the guest defines (a subclass of `NSException`), of `NSException`, of `id` (a thrown string), and
  `@finally`;
- `@throw;` rethrow, and a C++ `catch (...)` that takes an Objective-C exception;
- an exception raised in a block the host calls (`enumerateObjectsUsingBlock:`), so the unwind crosses host frames;
- callee-saved registers live across a catch, a catch followed by a tail call, a catch on a second thread;
- loops that catch 2000 exceptions, one with two `@try` regions in the loop body (each landing pad continues into the
  other), which kept a stack frame per catch before landing pads returned to a loop.

The check builds the program for this Mac and for arm64 iOS. The Mac's output is `tests/data/exceptions/expected.txt`.
On the host xlate must report at least 20 call sites unwinding to at least 6 landing pads, with no "left as plain
calls" line and no unreadable LSDA, the lifted module must carry `invoke`, `landingpad` and both the Objective-C and
the C++ personality, and the translated binary must import `_Unwind_SjLj_Register`. The device part runs the translated
binary and compares its output with the Mac's. The program takes the number of loop rounds as its argument (2000
by default), so a probe can run it deeper by hand.

### libexceptions

The same exception mechanism in a library (`XL_LIBRARY=1`), loaded by a small armv7 host (`host.m`, with the loader) that
takes the class and the method to call, so each step runs in a process of its own and a fault in one hides none of the others.
The guest (`fixture.mm`, class `LibExceptions`) has eight steps: an `NSException` thrown in a guest frame and caught three
frames up through frames with C++ destructors (4 destructors, `@finally` once); one raised by the host
(`-objectAtIndex:` out of range, `NSRangeException`); `@catch` of a guest subclass of `NSException` before `NSException`;
`@catch (id)` of a thrown string; a C++ `catch (...)` that takes an Objective-C exception, with its destructors and the
case where nothing is thrown; a `switch` of twelve cases, each a nested `@try` in an `@catch` (the handler of the first
throw throws again, caught by the inner `@catch` or, in every fourth case, `@throw;` out of the function), followed by a
tail shared by all cases that has its own `@try`/`@catch` and a throw that leaves the function (`stepSwitch`: sum of the
results, number of exceptions that escaped and number of destructors run, each checked against a reference function
without exceptions in the same file); a function with a landing pad (an `@try` that has ended) that leaves with a
`[[clang::musttail]]` call of a second function with its own `@try`, which leaves the same way into a third one that
throws every fifth value (`stepTail`: the two jumps are `b`, so the frames of the first two are gone when the throw
starts, and it must reach the `@catch` of the caller, not the pads that the first two left behind; checked like
`stepSwitch`); and a function with a 20000-byte stack frame, which the compiler enters through
`___chkstk_darwin` (its result is checked against the value a native program computes). The twelve cases are the
targets of a jump table, so the step is also the exceptions test of the multi-entry functions described under
[switchtail](#switchtail).

The host part builds and translates the library and the host, and requires that the library registers SjLj frames
(`_Unwind_SjLj_Register`). The device part runs each step and requires its `ok` names, `done` and `exit=0`. A C++ `throw`
of guest code is the check of [libcxxexceptions](#libcxxexceptions).

### libcxxexceptions

C++ exceptions thrown and caught by guest code in a library (`XL_LIBRARY=1`) that carries the arm64 `libc++` and
`libc++abi` of `revenant@libcxx` (`XL_CXX_LIBS` names another folder of the two) as guest images, loaded by a small armv7 host
(`host.mm`, with the loader) that takes the step to run, so each step runs in a process of its own with
`MallocScribble=1 MallocGuardEdges=1`. The guest (`fixture.mm`, class `LibCxxExceptions`) has eleven steps:

- `stepValue`: `throw` of an `int`, a `const char *`, a `std::string`, a `double`, `char`, `long`, `unsigned short` and
  `bool` (each caught by its own type), and a 32-byte struct caught by value, by reference and by pointer; `throw 1` meets
  `catch (long)` before `catch (int)` and must take the second.
- `stepHierarchy`: a class caught by its exact type, a base, a base of a base, a base by value (sliced), each of the two
  bases of multiple inheritance, a virtual base and a virtual sibling, and a `catch` of an unrelated class that must not
  match.
- `stepStandard`: `std::runtime_error` caught as `std::exception` and as a sibling of `std::logic_error` (which must not
  match), `std::out_of_range` from `std::vector::at`, `std::logic_error`, `std::string::at`, `std::bad_function_call`,
  `std::bad_cast` from `dynamic_cast`, `std::invalid_argument`.
- `stepNested`: a handler that throws another type, `throw;` through a function (the object stays the same one),
  `catch (...)` with `throw;` twice in a row, a `try` inside a handler, and `std::uncaught_exceptions` during unwinding and
  after it.
- `stepUnwind`: destructors run in the order of the frames, the destructors of the members of a constructor that throws,
  a thrown object copied by a `catch` by value (live objects counted), rethrown, and a loop of 200 throws.
- `stepPointer`: `std::current_exception`, `std::rethrow_exception`, copies and assignment of `std::exception_ptr`, the
  object kept past the handler and released, comparison, and `std::throw_with_nested` with `std::rethrow_if_nested`.
- `stepForeign`: the host throws a `std::runtime_error`, an `int`, an `NSException` and a class of its own through guest
  frames; the guest's `catch (...)`, `catch (int)`, `throw;`, destructors and `std::current_exception` handle them.
- `stepRoundTrip`: a guest block that throws, called by the host's `enumerateObjectsUsingBlock:`, caught by the guest that
  called it (a class of the guest's and a `std::runtime_error`).
- `stepEscape`, `stepEscapeInteger`, `stepEscapeStandard`: guest code throws a class, an `int` and a `std::runtime_error`
  that no guest frame catches; the host's `catch (int)` must take the `int`, and for the class and the `std::runtime_error`
  only the host's `catch (...)` matches (`host.caught.other`), because the host does not know the guest's classes.

The host part builds and translates the library and the host and fails if `__cxa_throw` stays a fault in
`report.txt`. The fixture is built with `-mno-outline`, so that the arm64 machine outliner does not hide the exceptions
test behind a different problem (an outlined function that returns the flags).

### hostbridges

A program (`main.m`) that calls the host functions whose guest and host layouts differ or whose argument is an `IMP`:

- `sscanf` and `vsscanf` with `int`, `long`, `long long`, `size_t`, `double`, `float`, `short`, `signed char`, `%x`,
  `%p`, `%c`, `%s`, `%n` and `%ln`, a conversion that fails half way (the later variables stay untouched), empty input,
  a suppressed conversion;
- `getaddrinfo` for a numeric IPv4 host with a service, for IPv6, for a name with `AI_NUMERICHOST` (status 8) and with
  `AI_PASSIVE`, walking the list and `freeaddrinfo`;
- `class_copyMethodList` of a guest class, its metaclass, a guest subclass and `NSObject`, sorted by selector;
- `IMP`s both ways: a guest method's `IMP` called by the guest on a guest instance and on a subclass instance; host
  `IMP`s of a concrete `NSString` class called by the guest; the `NSObject` `-isKindOfClass:` `IMP` called on an instance
  of a guest class that overrides it; `imp_implementationWithBlock` with a captured `__block` variable, added with
  `class_addMethod` and called by a message send, `imp_getBlock` and `imp_removeBlock`; a C function added with
  `class_addMethod`; `class_replaceMethod` and `method_setImplementation` with the old `IMP` called afterwards;
- the imports of the reCAPTCHA work's guest images that had no bridge, one check each: `CGColorCreate`,
  `CGColorGetComponents` (the pointer stays the same for one colour) and `CGImageCreateWithMaskingColors`, whose
  `CGFloat` arrays are `double` in the guest and `float` in the host; `_NSGetArgv` and `__progname`; `getifaddrs` and
  `freeifaddrs` for `lo0` (the address, the netmask, the flags, and the `if_data` of the link entry with its time
  stamp); `getservbyname` for a known and an unknown service; `localeconv_l` of the C locale (strings, numbers, the
  same pointer for the same locale); `sysctl` and `sysctlbyname` of `kern.boottime` (read twice into buffers with
  different contents, which have to give the same `timeval` as the loop of `clock_gettime` needs, by number and by name,
  a size probe, a buffer that is too small giving `ENOMEM` and length 0), `kern.proc.pid` and `kern.proc.all`
  (`kinfo_proc` of the process itself: pid, parent, group, user, name, start time; the list holds the process; a buffer of
  one element gives `ENOMEM`), `vm.loadavg`, `hw.ncpu`, `hw.memsize`, `kern.ostype`, `hw.machine`, `kern.argmax` and two
  names that do not exist; the device part also runs `HostBridges sysctl-unmapped`, which asks for
  `net.inet.tcp.pcblist` (a structure with no guest layout in the bridge) and expects the message that names it and
  `ENOTSUP`; `class_copyIvarList` of a guest class with an `int`, an object and a `double`, and
  of a class without ivars; `malloc_default_zone`, `malloc_zone_from_ptr` (a heap block and a stack address) and
  `malloc_zone_malloc`/`malloc_zone_free` with the zone the guest got; `NSDataDeallocatorUnmap`, `NSDataDeallocatorVM`
  and `NSDataDeallocatorFree` called by the guest, the first two checked by asking the kernel whether the page is
  still mapped; `catopen` of a catalogue that does not exist (the host's `(nl_catd)-1` has to reach the guest as
  `-1`); `swprintf` with `%d`, `%5.2f`, `%s`, `%ls`, `%c`, `%lld`, one that truncates, and one whose format and
  arguments are not ASCII; `_dispatch_source_type_vm` as the type of a dispatch source; `copyfile_state_alloc`,
  `fcopyfile` (a file descriptor copied into another) and `copyfile_state_free`; the lifetime of a block the guest hands to
  the host (`block sync`, `block async`): an object captured by a block of `dispatch_sync` must be released when the call
  returns (`released at return 1`), and one captured by a block of `dispatch_async` after the queue has run and dropped
  it (`released 2`), both with the main pool still open. The control on the 4S, with the generated block bridge keeping
  its holder until a pool drains (`autorelease` instead of `release`), prints 0 on both lines.

Alignment of host constants (the `align` lines): the guest must get a constant string or a `Protocol` of the host at a
multiple of 8, the same pointer each time, and the host must see the original. One check for each path that carries a
host pointer to the guest or a guest pointer back:

| Path | Line |
| --- | --- |
| data import of an object (`NSDefaultRunLoopMode`, `NSLocaleLanguageCode`) | `data import`, `locale key` |
| data import of a Core Foundation reference (`kCFRunLoopDefaultMode`) | `core foundation data import` |
| message result (`objc_msgSend`, `objectAtIndex:`), the same constant twice | `message return`, `same constant twice` |
| fast enumeration | `fast enumeration` |
| a plain pointer returned by a C function (`CFDictionaryGetValue`) | `core foundation return` |
| the host receives an alias (receiver, argument), the class the host sees | `host sees the constant` |
| a guest method called by the host with a constant (`makeObjectsPerformSelector:`) | `guest method argument` |
| `Protocol` (`NSProtocolFromString`, `protocol_isEqual`, `protocol_getName`) | `protocol` |
| `objc_initWeak`, `objc_loadWeakRetained`, `objc_loadWeak`, `objc_storeWeak` | `weak` |
| `dictionaryWithObjectsAndKeys:`, `arrayWithObjects:`, `initWithObjects:`, `setWithObjects:` | `variadic dictionary`, `variadic array`, `variadic init`, `variadic set` |
| `%@` of a constant (covered by construction: no control tells an alias from its original here, see below) | `format argument` |
| arguments of a guest block the host calls (`enumerateObjectsUsingBlock:`) | `block arguments` |
| result of a guest block the host calls (`imp_implementationWithBlock`) | `block result` |
| a guest category method on `NSString` (`self`, and `objc_msgSendSuper2`) | `category self`, `category super` |
| one constant fetched by 64 threads | `constant across threads` |

The Mac prints 1 everywhere, because its constants are aligned and its class names are the same; the 4S prints the same
because of the aliases. Three controls on the 4S, each run with the program unchanged and one part of
`src/runtime/alignment.m` switched off:

- the aliases off (`xl_alias_pointer`, `xl_alias_object` and `xl_protocol_out` return the host pointer): the first value of
  `data import`, `core foundation data import`, `locale key`, `message return`, `fast enumeration`, `core foundation
  return`, `guest method argument`, `protocol`, the four `weak` values, the first value of the four `variadic` lines, of
  `block arguments`, `function imp argument` and `category self`, and the first and third value of `block result`
  print 0;
- the way back off (`xl_alias_resolve` returns what it gets: an alias reaches the host as it is): `host sees the constant`
  and `category super` name `__NSCFString` instead of `__NSCFConstantString`;
- the cache off (`xl_alias_string` makes a new copy at every call): `same constant twice`, `fast enumeration`,
  `constant across threads`, and the identity values of `core foundation return`, `guest method argument`, `weak`, the
  `variadic` lines, `block arguments`, `block result` and `function imp argument` print 0.

`format argument` has no control: the alias is a real copy with the same characters, so a `%@` that gets the alias formats
the same text as one that gets the original, and nothing the program can observe tells the two apart.

The `enumeration` lines are `for … in` loops of the guest over host collections, which
`xl_manual_fast_enumeration` serves ([how](../../explanation/recompiler/how-it-works.md)): an outer loop over 40 strings
that, at its first item, runs 40 inner loops to their end or to a `break` and then 64 `malloc` blocks of the size of a
list of 40 items, filled with `0xa5`, and still has its 40 items (`40 of 40 items intact`; with the 32 shared lists the
bridge had before, the outer loop's list was freed by the thirty-third inner loop and the blocks landed on it); 41 loops
nested in one another; an array, a set and a dictionary of 100, which the guest gets 16 at a time (the array from one
answer of the host, the other two from an answer for every 16); an empty array; a guest collection that forwards the
call to a host array of 100; and an array, a set and a dictionary of 100 that are each changed at the twenty-first item
of their loop, which must raise `NSGenericException` before the loop has seen 100 items. The array is the case that
only the bridge's own comparison can raise: the host's array answers with all its items at once, so the host is not
asked again before the hundredth item and no code of the host runs that could notice, and the comparison of the loop
the compiler emits is the guest's here and reads the bridge's copy. The set and the dictionary are the case of a new
answer, where the bridge writes a new copy and the guest's comparison raises. Each of the two was taken out once, on
2026-11-19, and the translated program run with the Foundation of iOS 6.1.3 (10B329) in the emulator: without the
bridge's comparison the array's line reads `raised 0, before its end 0` and the other two stay; with the guest's
mutations pointer on a word that does not change, the set's and the dictionary's lines read `raised 0, before its end 0`
and the array's stays. So the three lines fail when the mechanism they name is gone, and an array of iOS 6.1.3 does
answer with more than the buffer holds.

The translated program runs in the emulator without a phone, as the first process of a copy of the root filesystem
(`cp -c -R` of `.cache/firmware/rootfs/iPhone4,1/6.1.3_10B329`, the program copied to `usr/local/bin`, then
`emulator boot --rootfs COPY --device iPhone4,1 --binary /usr/local/bin/HostBridges --host-cache DIR --display headless --gles-backend software --time-scale 10 --ticks 4000000000`;
8 seconds). Its lines without a `[` at the start are the program's: 171 of the 176 are those of `expected.txt`, and the
five that differ are the two `getifaddrs lo0` lines and three `sysctl` lines (`kern.proc.pid`, `kern.proc.all` and the
missing number), where the emulator's kernel answers a first process without a network otherwise than the phone's does;
they were the phone's lines before the change of the `enumeration` lines, which touches neither. So this run stands in
for the phone for every line but those, and not for `sysctl-unmapped` and `word-overflow`, which were not run there. The lines say `before its end 1` and not at which item, because the Mac raises at the
twenty-second item and the bridge at the thirty-third ([why](../../explanation/recompiler/how-it-works.md)).

`format locale nil`, `format locale posix` and `format locale unicode` call `-[NSString initWithFormat:locale:arguments:]`
with a `va_list` the program builds. That selector is declared with `NS_FORMAT_FUNCTION(1,0)` and a `va_list` parameter, and
until 2026-11-14 `xlgen` bridged the parameter as a plain pointer: the host read the guest's 8-byte argument words as 4-byte
slots, so `String(format: "%d-%@", 7, "x")` of the Swift overlay (which calls this selector with a nil locale) gave `7-(null)`
on the 4S and a `%@` after another argument read the high half of the previous word. `xlgen` now sends every method with a
`va_list` parameter and a format attribute whose arguments index is 0 through `xl_format_marshal`, as it does the variadic
ones, and the three lines print `7-x`, `a|5|b|12345678901| 3.14` and `é=7|ü` on the 4S as on the Mac (measured on 2026-11-14).
The control is a translation with the `xlgen` of main: the program stops with a signal 11 on the 4S. The SDK has two more
methods of this shape, `+[NSException raise:format:arguments:]` and `+[NSPredicate predicateWithFormat:arguments:]`; they take
the same path and no line of the check calls them. The `%K` of a predicate format is not a conversion of `xl_format_marshal`
and stops the program with its message.

- a C function pointer the guest passes to the host: forty distinct functions through `dispatch_once_f` (twice each, they run
  once), `dispatch_sync_f` and `dispatch_async_f` (each waited for before the next). The host holds a trampoline per
  distinct guest function, 32 for each signature, and a function pointer passed for `dispatch_once_f`, `dispatch_sync_f`
  and the like is held until the call returns, one for `dispatch_async_f` until it has run, so the reCAPTCHA SDK's
  `swift_once`, which passes the initializer of every lazy global to `dispatch_once_f`, no longer ends with "callback pool
  4 exhausted" at the 33rd global. The host part requires that the wrappers of the three hold the slot with the life that
  fits them and that the two that run the function during the call release it.
- a key built from a 64-bit constant: `objc_setAssociatedObject` and `objc_getAssociatedObject` with `0x636861726f6e4143` and
  a second constant that differs in the last byte (and with the address of a static, as before), and
  `dispatch_queue_set_specific`, `dispatch_queue_get_specific` and `dispatch_get_specific` with the same constant. Two
  constants stay two keys, clearing one leaves the other, and the address key still works. Before, the reCAPTCHA SDK's
  `charonAC` association key ended the program with "objc_getAssociatedObject argument 1 value 0x636861726f6e4143 does not
  fit the host type". The same step stores the plain words 1 and 3 with the policy assign and reads them back (before, the
  SDK's flag of 1 ended the program with "objc_setAssociatedObject argument 2 is 0x1, not an object pointer"); the host
  part requires that the wrapper of the setter takes its value with `xl_object_in_word` and that of the getter gives it
  back with `xl_object_out_word`.
- the opaque 64-bit words of `recompiler/src/xlate/opaque_words.h`, one check for each position class, with `WORD(n)` =
  `0x4d4e636572 + n` ("recNM", the context a Swift program hands to `dispatch_once_f`): the contexts of `dispatch_once_f`,
  `dispatch_sync_f`, `dispatch_barrier_sync_f`, `dispatch_async_f`, `dispatch_barrier_async_f`, `dispatch_after_f`,
  `dispatch_apply_f`, `dispatch_group_async_f` and `dispatch_group_notify_f` (each function receives the very word, and a
  small word and an address still pass as they are); `dispatch_set_context` and `dispatch_get_context`; the value of
  `dispatch_queue_set_specific` read back by `dispatch_queue_get_specific` and inside the queue by `dispatch_get_specific`;
  `pthread_setspecific` and `pthread_getspecific`, the argument and the result of a thread made with `pthread_create` and
  joined with `pthread_join` (an out slot that the guest has not set), the value of `pthread_exit`, and the value that a key
  destructor receives; the thunk of `qsort_r`; a value of more than 32 bits stored with the policy assign; the arguments of
  `performSelector:withObject:` and
  `performSelector:withObject:withObject:`; the keys, values and contexts of a Core Foundation dictionary, set and array with
  NULL callbacks (set, get, contains, `GetValueIfPresent`, apply, and the arrays that `CFDictionaryCreate` and `CFArrayCreate`
  take); the key and value of an `NSMapTable` and a member of an `NSHashTable` with the pointer personality; the `info` of the
  context of a `CFRunLoopTimer`, which the callback receives and `CFRunLoopTimerGetContext` gives back. The host part
  requires the wrapper of one function of each class to narrow with `xl_narrow_word`, the wrapper of `pthread_join` not to read
  the result slot, and `report.txt` to hold no line "opaque word table" (a row that does not match the SDK). The device part
  also runs the program with `word-overflow`, which passes 300000 distinct words to `dispatch_sync_f`, and requires that it
  stops with "holds 262144 distinct words and is full" and a non-zero status instead of reusing a slot.

The check builds the program for this Mac and compares its output with `tests/data/hostbridges/expected.txt`, translates
the arm64 build (which fails on any import without a bridge) and requires that the program imports each of the bridged
functions. The device part runs the translated binary and compares its output with the Mac's.

### segmentlimit

Seven small arm64 dylibs, each with a function and a global, are the guest images of one executable. An executable has the
segments `__PAGEZERO`, `__TEXT` and `__DATA`, then a text and a data segment for every guest image, and dyld's bind and
rebase opcodes name a segment with 4 bits (index 0 to 15). The data segment of the seventh image is segment 16, and an
executable of twelve images (the reCAPTCHA work's full set) died with SIGSEGV before `main`: the last bind that
`DYLD_PRINT_BINDINGS=1` printed on the 4S was at `0x1400`, in `__PAGEZERO`, right after the last bind in the data
segment of the second image (`0x105f87f8`, segment 6), which is what a segment index truncated to 4 bits looks like.

The check lifts the seven as an executable and requires `xlate` to refuse, naming the 4-bit index, the limit of six
images and `--library`; it lifts six and requires that no such refusal is said, and lifts the seven with `--library`
and requires the same. Nothing is run and nothing is compiled past the lift.

### absolutes

A symbol of a dylib can be absolute (`nm -m`: `(absolute) external`): it has a value and no address in any section.
libswiftCore has one, `__swiftImmortalRefCount` (`0x80000004ffffffff`, the reference count the statically initialised
objects of libswiftFoundation, libswiftCryptoKit and libswiftNetwork carry). `xlate` read only the symbols of a section,
so those binds stayed unresolved and the translation named the symbol as an import of the host, which has none.

One dylib defines `absolute_value` as `0x123456789` with `.set`, another holds `&absolute_value` in a global. The check
lifts the second alone and requires the refusal "data bind to unresolved symbol _absolute_value"; lifts both and requires
that no symbol is unresolved and that the data slot of the bind holds `0x123456789`, the value itself: a section symbol
is slid with its image, an absolute value is not.

### rebasetag

dyld adds the slide to the whole 64-bit word at a rebase, so the top byte of the word stays. It is data: the object word
of a Swift `String` whose literal lives in the image is `0x8000000000000000` plus the address of the bytes less `0x20`,
and `swift_bridgeObjectRetain` leaves a word with bit 63 alone. `xlate` wrote every rebased word as `target &
0x00FFFFFFFFFFFFFF`, so a global `let` string of the reCAPTCHA SDK (`"www.recaptcha.net"`, at `0x15dc80`) became a
native-looking pointer into `__cstring`, and the first `String.append` of it made the guest retain that read-only page
(SIGBUS, KERN_PROTECTION_FAILURE, a write at guest `0x180f9398`).

The image holds a global `{marker, (unsigned long long)text + 0x8000000000000000, marker}`, which the linker emits as a
rebase with a top byte. The check lifts it with `--library` and requires the eight bytes of the word in the lifted
image to end in `0x80` and not in zero.

### flagflow

The lift gives a call no condition flags (see [Scope and limits](../../explanation/recompiler/how-it-works.md#scope-and-limits)),
and xlate refuses an image where code depends on them: it scans every `bl` and `blr` for a flag read after the call and
every callee for a flag read on entry. The check lifts small dylibs and reads the error and the `report.txt` summary
(`--flag-flow-summary`):

- refused, from assembly (`direct.S`, `indirect.S`, `entry.S`): an outlined function that ends in `cmp; ret` and a caller
  that runs `cset` after `bl`; the same after `blr`; a callee that starts with `cset` after the caller's `cmp`. The error
  names the function, the call, the callee and the reader.
- refused, from the compiler (`notes.c` at `-Oz`): six functions that repeat one sequence, which Apple clang 21 outlines
  into functions that return the result of `cmp w9, #0x3f` to a `b.hi`. If a compiler stops making that function, the
  check fails and the fixture needs a new example.
- translated (`clean.S`, `notes.c` at `-Oz -mno-outline`): a callee that sets the flags and a caller that ignores them and
  compares again, and a read of the flags after a call to a function that is one `brk` (not counted as a site, and counted
  once in the summary); the summary says that no call passes the flags.

`xlate --flag-flow <file> <image>` lists the sites of an image without lifting it, which is how the SDK, `libswiftCore`
and `libc++` were measured.

### objectsplit

A synthetic module of 6500 functions, each with 120 `invoke`s into one SjLj cleanup landing pad (15 MB of bitcode, about
20 MB of armv7 code). It is the swiftobjc regression in miniature: the guest `libswiftCore` with its exception edges
split into pieces of 14 to 16 MB of bitcode and every piece failed with "can not encode offset ... in resulting
scattered relocation", because an armv7 Mach-O scattered relocation, which the SjLj frame of a function with a landing
pad needs for the label difference between `__text` and `__gcc_except_tab`, addresses 24 bits of a section: nothing past
16 MB of `__text` can carry one.

The check compiles the module as one object and requires that to fail with that message, so that the module keeps being
too big. Then `compile_lifted` of `translate.lua` compiles it with its own piece size: at least three objects, each
smaller than 16 MB, and every function defined once across them. The objects are compiled with `-O0` to keep the check
at about a minute; the limit is on the size of an object, and `-O0` code is bigger than `-O2` code.

### tsdscan

A control for xlate's build-time TSD offset scan (`src/xlate/tsd_scan.cpp`). xlate refuses to lift an image that reads
`TPIDRRO_EL0` at an offset nobody has audited. Two builds of `main.c` are fed to xlate directly; neither is run:

1. `TSD_OFFSET=0x358`, Swift's `__PTK_FRAMEWORK_SWIFT_KEY7`. This is the one offset that `src/runtime/runtime.c`'s fake TSD
   block is measured and sized for, so xlate must accept the image.
2. `TSD_OFFSET=0x40`, an offset no guest has ever been measured touching. xlate must refuse it. The error must name the
   offset and each of the three cases by its function:
   - `read_tsd_slot`, a straight line;
   - `dead_path_clobber`, a clobber on one arm of a branch;
   - `callee_reads_tsd`, the base crossing a call in a callee-saved register.

   An address-ordered, per-function sweep missed the last two, so a scanner that catches only the first must fail.

The logs and binaries are removed before each run. A failed build would otherwise leave the previous run's output in
place, and it would be read as this run's answer.

### tsdguard

Proves the page-protection scheme of `src/runtime/xl_tsd_guard.h` on the build host. That header is the runtime half of the
`TPIDRRO_EL0` workaround. mmap, mprotect and SIGSEGV are POSIX, so `main.c` is compiled for the host and run directly. There
is no device, lift or translation.

It also checks the guest stack of a thread: `xl_stack_length` (the thread's own stack rounded up to a page, and a guard
page) for five sizes, `xl_stack_map` (the guard page faults and the first byte above it reads; a mapper that refuses above
1 MB gives no smaller stack for 4 MB, a mapper that refuses everything gives none) and `xl_stack_used` (nothing for a
stack nobody wrote to, then the depth of the lowest write after writes at five depths).

It proves the arithmetic at this machine's page size, which `main.c` prints: 16384 on Apple Silicon. The 4 KiB device
case rests on `xl_tsd_guard.h` reading the page size from `sysconf`. Each check in `main.c` forks with its own `alarm()`,
a bounded parent-side wait and a SIGKILL fallback, after a real hang on a device. The outer 60-second limit in
`check.lua` is a second, independent belt: if it ever fires, `main.c`'s own bounding failed.

### int128

Checks `src/runtime/int128.c` (`__udivti3`, `__umodti3`, `__divti3`, `__modti3`) against a 128-bit reference in Lua. The
inputs are:

- edge values, and every pair of them;
- random values of widths 1, 8, 31, 32, 63, 64, 65, 100, 127 and 128 bits, from a fixed seed.

`INT128_MIN / -1` is left out, because it overflows in C. The reference runs its own self-test first. The driver
`driver.c` is built for the host and fed the cases on stdin. An optional second argument sets the number of random
values (3000 by default).

### ordinal

A guest image that defines a name a host library also has (`NSString`, `getpid`) answers a bind only when the bind
names that image. This holds for each kind of bind: the superclass pointer, a class reference and a call stub.

- The class reference and the stub are not in the manifest. They are resolved when the image is lifted.
  - A bind that a guest image answers leaves no reference to the host symbol in the lifted module.
  - A bind that no guest image answers is a passthrough: a declaration of the host symbol in the module.
- A call stub to libSystem's `getpid` has no answer in a guest image that merely defines `getpid`, and `--strict` says
  so.
- Two images with one file name are told apart by install name. A bind takes the image whose install name it spells,
  not the one that comes first.
- Refused, each with both files named:
  - two images that are the same library;
  - one library named twice in `--replaces`;
  - a `--replaces` entry that is an image's own install name.
- A bind to a system path is the host's library unless `--replaces` says a guest image stands for it.
- A library that an image re-exports whole (`LC_REEXPORT_DYLIB`) is answered by that image, and counts as answered in
  the list `recompiler/tools/translate.lua` reads.
- `recompiler/tools/translate.lua` takes the symbols that no host library supplies from xlate's own answers, not from what the images
  export. An app that binds the host's `NSString` next to an embedded image that defines its own still needs `NSString`
  bridged. An app that binds the embedded image's `NSString` does not.

The image indices in xlate's JSON are 1-based in Lua: the app, libfrombx, `a/libcoll` (the app's link), then
`b/libcoll` (libfrombx's).

### devicegate

No phone. It reads `--host-only`, `--device-only` and the two tables through `corpus.options` and checks six
combinations, then points the lease folder at a temporary one and shows that `corpus.device()` refuses a holder that
named nobody, a phone nobody claimed and a phone another holder claimed, and lets the holder of the claim through with
`/var/root/revenant-scratch/<holder>` as its `scratch` folder. The module refuses a holder name that is empty, has a
slash, starts with a dot or holds `..`, and does not erase the folder of a holder without a claim. It also claims the
phone under one private cache and shows that a claim under another is refused, that the lease sits in
`~/.revenant/devices` and that neither cache gets a `devices` folder. Two
checks (`hostbridges`, `libexceptions`) read only the table before this test; a build meant for the Mac took the string
as nothing and ran on the phone.

### checkapi

The check scripts reach the tool modules (`corpus`, `translate`, `env`) through a local alias, and a call to a function
the module no longer defines fails only when that script runs. The device group's scripts run rarely, so a rename in a
module once left `ordinal` calling `corpus.sorted` for weeks after the helper moved to `env`. `checkapi` reads every
`tests/*/check.lua`, takes each `local <alias> = import("<module>", {rootdir = <tools>})`, and fails for every
`<alias>.<name>(` that `tools/<module>.lua` does not define as a function. It needs no phone and no build, and fails
when it finds no call at all (the pattern that reads the scripts no longer matches).

### weakimport

Weak imports, judged both by what `--strict` says and by what the translated program does.

1. Host part. A call stub is weak or strong by its own image. A library that checks for `getppid` does not excuse an
   executable that calls it.
   - An image with bind entries for its stubs says whether each stub is weak in two places.
   - Only an image without bind entries depends on the stub's own symbol-table flag alone. Such an image is one pulled
     out of a shared cache; `macho.unbind` makes one by zeroing the bind, weak-bind and lazy-bind ranges of
     `LC_DYLD_INFO`.
   - The unbound executable is refused for its stub's flag alone. The unbound library's weak stub stays weak by its
     own flag.
2. Device part. The program runs twice on the iPad 2: once built natively for iOS 6, once translated from arm64. Both
   must print `expected.txt`. The outputs are kept as `run-native.txt` and `run.txt`.

### classpair

Classes that the Swift runtime lays out, and the calls that hand them to libobjc. `main.c` has the story, and the
README's "Classes the Swift runtime lays out" has the design.

1. Host part. `main.c` is built for macOS, where objc4 is the real thing, and run. Its output must stay `expected.txt`.
2. Host part, from xlate's manifest of the translation itself. `XLPairListedOverClsro` is a `__objc_classlist` class
   whose immediate superclass is laid out only in `__objc_clsrolist`. It must be moved to the guest layout.
   - `SplitGuestLayoutClasses` once walked ancestors only among `__objc_classlist` classes, so this class was silently
     kept at host layout.
   - The manifest's own safety check misses this case for the same reason.
3. Device part. The program is translated from arm64 and run on the iPad 2, and must print what macOS printed.
   - iOS 6's libobjc has none of `objc_readClassPair`, `_objc_realizeClassFromSwift` and
     `objc_setHook_lazyClassNamer`, so the program cannot be built for iOS 6 natively. The macOS run is the oracle.
4. Device part, two cases of a callback into the guest while a message is routed ("Callbacks into the guest" in
   [how the recompiler works](../../explanation/recompiler/how-it-works.md)):
   - `XLPairClsroLeaf` is laid out only in `__objc_clsrolist` under the guest root class `XLPairRoot`. Its shadow is
     built when the first message reaches it, and building it sends `+class` to `XLPairRoot`, a guest method. That first
     message is `self`, and it must return the class, not what `+class` left in `x0`.
   - `XLPairRoot` has a `+initialize` that fills `x0` to `x8` and `d0` to `d7`. libobjc sends it to the shadow of
     `XLPairFresh` while the first message to that class is looked up. The message has integer and floating-point
     arguments and a structure result, and the receiver and all four arguments must arrive.
5. Device part, the identity of a host class ("twin pair" in
   [how the recompiler works](../../explanation/recompiler/how-it-works.md)): the program has Objective-C classes under
   `NSObject` and no Swift class, so `class_getSuperclass` of `XLPairStatic` and `XLPairBuilt`, `object_getClass` of an
   `NSObject` instance and `[NSObject class]` must all be `&OBJC_CLASS_$_NSObject`, as on macOS. The run on the iPhone 4S
   prints `expected.txt` whole.

The arm64 input is linked with Revenant's `ld64`. The linker of Xcode 15 and later drops `__objc_clsrolist`, which Swift
binaries carry.

### swiftconformance (device only)

A control for the `_dyld_register_func_for_add_image` bridge in `src/runtime/bridge.m`, the fix for the
`_DictionaryStorage.allocate` crash.

In `fixture.swift`, `Widget`'s conformance to `Hashable` is a `__swift5_proto` record in the guest image itself. The
Swift runtime can find that record only if something tells it the image exists and feeds it the image's sections,
which is what the bridge does. At run time, `x is Hashable` prints `hashable` or `not-hashable`.

The check translates the fixture twice. The normal build must print `hashable`; the control, built with
`-DXL_TEST_NO_DYLD_IMAGE_BRIDGE=1`, must print `not-hashable`.

The fixture is compiled with Revenant's from-source Swift toolchain (`revenant@swift`), not Xcode's Command Line Tools:

- The CLT `swiftc` cannot cross-compile for `arm64-apple-ios`. It fails with "Cannot read legacy layout file ...
  layouts-arm64.yaml", because CLT ships `lib/swift/macosx/` only.
- That file is not Apple-internal. It is in the open-source Swift tree at
  `stdlib/toolchain/legacy_layouts/iphoneos/layouts-arm64.yaml`, and an install of `revenant@swift` that kept its source
  cache carries it.
  - The check looks for such an install by what it contains.
  - It never takes the first match, because several hashed installs of one version can exist.
- Two flags close the gap:
  - `-Xfrontend -read-legacy-type-info-path=<that file>`;
  - `-runtime-compatibility-version none`, which skips auto-linking the `swiftCompatibilityNN` back-deploy shims. That
    resource tree lacks them, and the fixture does not need them.

The fixture links only libSystem and `@rpath/libswiftCore.dylib`. libswiftCore itself reaches into libc++ and
libc++abi on the conformance path, the demangler among them. Without those as guest images, the program crashes on the
device with "call to an address without translated code" before main prints anything.

So the fixture is translated like the demo:

- with libswiftCore, libc++ and libc++abi from the folder in `XL_SWIFTCONFORMANCE_LIBS`;
- with `XL_REPLACES` mapping `/usr/lib/libc++.1.dylib` to the guest libc++.

`XL_SWIFTCONFORMANCE_ALSO_DEMO=1` adds a second, independent confirmation, off by default because it costs two more
full translations. It also translates the real demo (`XL_SWIFTCONFORMANCE_DEMO`), normally and with the bridge
compiled out. The control must crash with exit 139, and the normal build must not.

### swiftobjc (device only)

A control for the twin scheme of `src/runtime/swift_classes.m`: Swift classes that inherit from a class of the host's
Objective-C runtime (here `NSObject`), translated with `XL_SWIFT_HOST_ANCESTORS=1` (`--swift-host-ancestors` of xlate).

The fixture has three classes: `Client`, an `NSObject` subclass with stored properties (a `String`, an `[String]`, an
optional reference, a closure); `Sub`, a final subclass of `Client` that overrides `bump` and calls `super`; and
`Token`, a final `NSObject` subclass whose Swift `deinit` prints; and two subclasses of `NSError`, `FixtureError` and
`Trio` (three stored fields: a `String`, an `Int` and an `Any?`). It prints `ok <name>` or `FAIL <name>` for 37
checks, among them:

- an `Error` that is an `NSError` the host made becomes an `NSError` again (`error.bridge*`: `error as NSError` of a
  `Trio`, one thrown and caught, 24 of them made between plain `NSError`s): the NSError that comes back is the same
  object, its code, domain and user info are the ones it was made with, its three fields and the plain `NSError`s
  around it do not change. The guest runtime's `_swift_stdlib_bridgeErrorToNSError` read the domain of the error at
  the offset the Swift error box keeps it (24 on arm64), where the host's armv7 `NSError` (`_reserved` 4, `_code` 8,
  `_domain` 12, `_userInfo` 16, 20 bytes) has the tail of its allocation: it read nil, took the error for a box that was
  not computed yet and stored the code at 16 (the host's `_userInfo`: the reCAPTCHA Enterprise SDK's error had 0x2
  there, its code), the domain at 24 and the user info at 32, past the object. The recipe's patch
  `a-real-nserror-is-not-read-through-the-layout-of-the-swift-error-box.patch` asks first whether the object is a real
  `NSError`. The host part reads the disassembly of the runtime that `XL_SWIFTOBJC_LIBS` names and requires the class
  check before the first load-acquire of that function, so a runtime of the older recipe stops it with no phone;

- construction through `Client()` (the Swift `init` of an ObjC ancestor runs `objc_msgSendSuper2` with the class from
  `swift_getObjectType`, which must be the guest's own metadata);
- Swift and `@objc` dispatch, `super` calls through the guest vtable, and an `as?` cast of an `AnyObject`;
- `respondsToSelector:`, `performSelector:` (of a method that returns an object) and `isKindOfClass:` from the host side;
- the Swift `deinit` of `Token` reached through the host's `dealloc`, and the release of the stored properties of a
  `Client` and of a `Sub` when they die (the `.cxx_destruct` of the guest class, which the host's libobjc does not run
  for a class it did not read from an image);
- an instance the host allocates with `class_createInstance` (no `objc_alloc` on the way, so the copy of the Swift part
  of the class must be current; no `init` runs, so only its class is used) and one made by `NSObject.Type.init()`,
  which is then dispatched to and cast;
- `_typeName` of the classes;
- the stdlib's own statically laid out classes, which the host first meets through a message: `AnyCollection` of an
  array and of a `String` (the prespecialized `_IndexBox<Int>` and `_IndexBox<String.Index>`), the children of a
  `Mirror`, and `String(describing:)` of a struct and of a class;
- a Swift value passed to Core Foundation (`cf.dictionary.*`, `cf.array.count`, `cf.data.length`, `cf.string.length`): `["alpha": 1,
  "beta": "two"] as [String: Any] as CFDictionary` is a `_SwiftDeferredNSDictionary` of the guest, and
  `CFDictionaryGetCount`, `CFDictionaryContainsKey` and `CFDictionaryGetValue` make Core Foundation send it
  `count`, `objectForKey:` and the like, which only works when the host got a proxy of the object and not its raw
  pointer (the crash of the reCAPTCHA Enterprise SDK's keychain query in `SecItemCopyMatching`, 2026-11-15); the same
  for a bridged array, data and string.

The groups `error.*` and `cf.*` (9 + 7 of the names) need the Foundation overlay: `error as NSError` calls
`_convertErrorToNSError` and a `String`, a `Dictionary` or an `Array` reaches Core Foundation through `_bridgeToObjectiveC`,
all of them in `libswiftFoundation`, which the translation of this executable does not carry (it would hold 24 guest segments
of 12 images, and dyld's bind opcodes name a segment with 4 bits), so the translated functions stop the program with
`unsupported: $sSS10FoundationE19_bridgeToObjectiveCSo8NSStringCyF` (measured on the 4S on 2026-11-16, and
`__objc_autoreleasePoolPush`, which the Swift `autoreleasepool` calls, had no bridge: it is a manual bridge now, as is
`_objc_autoreleasePoolPush`). The fixture runs those groups only when it is given an argument, the device part gives none
and wants the other 28 names, and the host part still translates the code of both and requires its checks.

The check wants every name `ok`, no `FAIL`, the `deinit` line, and exit 0. The host part also reads the generated
`host.m` and requires that the wrappers of `CFDictionaryGetCount`, `CFDictionaryContainsKey`, `CFDictionaryGetValue`,
`CFArrayGetCount`, `CFDataGetLength` and `CFStringGetLength` take their object argument through `xl_object_in`.

The translation takes about ten minutes and needs no phone: `check.lua <out> --host-only` stops after it, and
`check.lua <out> --device-only` runs the fixture that run left in `<out>/xl` on the claimed phone (28 names `ok`).

It needs the arm64 runtime, so `XL_SWIFTOBJC_LIBS` names the folder with `libswiftCore.dylib` (the one that
`revenant@swift-runtime` built for arm64, which carries `-DSWIFT_CLASS_IS_SWIFT_MASK=1ULL`), `libc++.1.dylib` and
`libc++abi.1.dylib`. The fixture is compiled like swiftconformance's, for iOS 12.0 with the legacy type info: that
target marks a Swift class with bit 0 of the class data, the bit the guest's libswiftCore tests. A class compiled for
iOS 12.2 or later (bit 1) is accepted too, because the runtime rewrites that bit when it sets the class up.

### proxytable

A control for the proxies of guest objects ([how it works](../../explanation/recompiler/how-it-works.md)), run on the Mac:
`tests/proxytable/main.m` links `src/runtime/proxy.m` as it is, and gives it what the translated library gives it, a
shadow class whose `retain`, `release`, `autorelease`, `retainCount`, `_tryRetain`, `_isDeallocating`, `allowsWeakReference`
and `retainWeakReference` stop the process, and a guest object that is a counted block (`swift_retain` and `swift_release`
are atomic counters). The check builds it with `MallocScribble` and `MallocGuardEdges` and requires `ok` for each of:

- `proxy.in`, `proxy.shape`: a proxy is made for a noted guest class, its class is `XLProxy.<shadow>`, `-class` is the
  shadow, and it is a kind of the shadow and of `NSObject`, and of no other class.
- `proxy.roundtrip`, `proxy.identity`: `xl_proxy_out` and `xl_self_out` give the guest pointer, a host object that is not a
  proxy comes back unchanged, and a second lookup finds the same proxy.
- `proxy.holds-guest`, `proxy.memory-selectors`, `proxy.released`: a live proxy holds one count on its guest object,
  `retain` and `release` on the proxy leave the guest count alone and never reach the shadow's implementations, and the
  count is back to zero when the pool drains.
- `proxy.renote`, `proxy.unknown`: noting a class again keeps its proxy class (no second class named `XLProxy.<shadow>@<address>`),
  and a pointer of a class that was never noted, a low pointer and `nil` give no proxy.
- `proxy.weak.alive`, `proxy.weak.cleared`, `proxy.weak.recreated`, `proxy.weak.balanced`: a `__weak` reference to a proxy
  loads while it lives and is `nil` after it died, the next lookup makes a new proxy, and the counts balance.
- `proxy.race.single`, `proxy.race.balanced`: four threads make, find and drop proxies of eight guest objects for 100 000
  rounds each. In no round do two threads hold different proxies of one guest object at once, a second lookup in a pool
  finds the proxy the first made, and every count taken is given back (the argument of the binary sets the number of rounds).

A control with `XL_PROXY=0` must fail at `proxy.in`. Each of these was also checked to fail when the code is broken in
one place at a time: the entry removed by a dying proxy that no longer owns it (10 223 violations in 800 000 rounds), a lookup
without `objc_loadWeakRetained` (signal 11), a lookup outside the lock (signal 11), no guest retain or no guest release (the
count checks), no replacement of the memory selectors (abort in the shadow's `retain`).

### systemclasses (device part by hand)

A library translated with `BACKPORTS_DIR` binds a class the iOS 6 cache has to the system library, not to the proxy
that a Backports library exports under the same symbol ([library mode](library-mode.md)). The fixture is a guest
`SCDict : NSMutableDictionary` that implements the five primitives of the class cluster and nothing else, and
`SCFixture`, whose `+run` reports `ok <name>` or `FAIL <name>` for each of:

- `superclass`: the superclass of `SCDict` is the system `NSMutableDictionary`, not a proxy that stands between them.
- `kind`: an `SCDict` is a kind of `NSMutableDictionary` by the class the guest names and by the class `objc_getClass` finds,
  and of `NSDictionary`.
- `addEntriesFromDictionary`, `removeAllObjects`, `setDictionary`: the three mutators that `NSMutableDictionary` implements
  and `NSDictionary` does not work on an `SCDict`.
- `absent`, `shadowed`, `dispatch`: the guest still gets a class of its name for `NSURLQueryItem`, which the cache lacks, for
  `CASpringAnimation`, which `shadowed-classes.txt` lists, and for `OS_dispatch_queue`, which the cache has but its `libSystem`
  does not export as a symbol.
- `wide`: the guest sends host class `SCHostWide` four messages through a cast `objc_msgSend`, whose parameters are
  `int, long long`, `long long, long long`, `int, int, int, long long` (the last on the stack) and `unsigned char,
  unsigned long long`. The armv7 iOS ABI does not align a `long long` argument to an even register: the low word goes in
  `r3` and the high word at `[sp]`, and stack arguments are consecutive 4-byte words (`clang -target armv7-apple-ios6.0`
  shows it). `xl_dynamic_send` once padded to the even register as AAPCS does, so the host method read a wrong high word.
  A fixture built with that runtime reports `FAIL wide` on the 4S.
- `native`: the host calls `-[NSObject scNative:]`, a method the fixture adds as a category on the system class `NSObject`
  and the SDK does not declare, with an `NSInteger` (a 32-bit `int` on armv7), and checks `-5`, `0x40000000` and `-1`
  (`NSNotFound`, `0x7fffffff`, is widened to the arm64 `NSNotFound` by design). The stub reads that argument as the armv7
  caller passes it, one word ([method widths](library-mode.md#the-integer-width-of-a-method-the-sdk-does-not-declare)).
- `blocks`: the guest hands host class `SCHostWide` a block `NSInteger (^)(NSInteger)` and a block `NSUInteger
  (^)(NSUInteger)`, and the host calls them with `-5`, `NSNotFound` and `7`, and `0xfffffff0` and `7`. The guest block
  records what it was given: the signed arguments have to arrive as `-5`, the arm64 `NSNotFound` and `7`, the unsigned ones
  as `0xfffffff0` and `7`; the host checks what the block returned (`-5`, its own `NSNotFound`, `7`). A runtime that
  zero-extends every `q` reports `FAIL blocks` on the 4S (`-5` arrives as `4294967291`).

The host part needs no Backports build. It compiles two stand-in libraries for the armv7 target, `libFoundationBackports`
from the sources of `NSMutableDictionaryAlias.m` (the proxy `RevenantNSMutableDictionary` and the alias symbols) and a
class `NSURLQueryItem`, `libUIKitBackports` with `REVENANT_ALIAS(CASpringAnimation)` and `libSystemBackports` with
`REVENANT_ALIAS(OS_dispatch_queue)`, under the install names of the
real ones. It translates the fixture with `BACKPORTS_DIR` naming them, and requires of the library:

- `_OBJC_CLASS_$_NSMutableDictionary` and `_OBJC_METACLASS_$_NSMutableDictionary` are imported from a library that is not a
  Backports library, in the symbol table and in every bind entry of the dyld info (there are at least two: the class
  reference and the superclass of `SCDict`), and `system-classes.txt` lists both with the system library they moved to;
- `_OBJC_CLASS_$_NSURLQueryItem`, `_OBJC_CLASS_$_CASpringAnimation` and `_OBJC_CLASS_$_OS_dispatch_queue` stay on their Backports libraries, which `otool -L`
  still lists, and `proxy-classes.txt` says why (`absent from the iOS 6 cache`, `shadowed`, `the iOS 6 cache does not export it from libSystem.B.dylib`);
- `report.txt` gives the host method `-[SCNative scNative:]`, a category on `NSObject`, `L12@0:4l8` for the guest encoding `Q24@0:8q16`
  (the `q` and `Q` as the 32-bit `long`), and the host method `-[SCGuestWide scBig:]`, of a guest class that derives only from
  `NSObject`, `q16@0:4q8` for `q24@0:8q16` (the 64-bit type kept).

The control translates the same fixture with `XL_PROXY_CLASSES=1`, which keeps every class on the Backports as the
translator did before, and requires that `NSMutableDictionary` binds to `libFoundationBackports` and that
`system-classes.txt` is empty.

A third translation leaves `BACKPORTS_DIR` out and checks the `uncovered-classes.txt` report. It must list exactly
`NSURLQueryItem`, which the iOS 6 cache lacks, and `OS_dispatch_queue`, which the cache's `libSystem` does not export, and
the library must import those two weakly and `NSMutableDictionary` and `CASpringAnimation` strongly. A report that lists
every imported class, or none, fails here: `classes_armv7.json` holds its classes as a JSON object, and a check that
takes its length instead of its keys sees an empty set. The translation with the Backports must report no uncovered class.

The device part (`--device-only`) translates the fixture against the Backports build that `REVENANT_ALIAS_LIBRARIES` names
(default `build/iphoneos/armv7/release`), loads it in a small armv7 host with the loader, and requires `ok` for each name
above. The control with `XL_PROXY_CLASSES=1` must report `FAIL superclass`: the Backports reparent a proxy that has no
instance variables under the system class when they load, so the other names may pass there, and `superclass` is the one
that shows the proxy still between the guest class and the system class.

```sh
./xmakew l -P . recompiler/tests/systemclasses/check.lua <out>
```

### libgenerics (device part by hand)

The generic classes that the guest Swift runtime instantiates at run time, in a library (`XL_LIBRARY=1`) with the guest
`libswiftCore`. The runtime's own metadata is prespecialized only for the common element types, so `[() -> Int]` or
`[String: String]` makes `swift_getGenericMetadata` build a `_ContiguousArrayStorage<T>` or `_DictionaryStorage<K, V>` class
and look its superclass up through `swift_getTypeByMangledName`. A small armv7 host (`host.m`, with the loader) takes the
class and the method to call, so each step runs in a process of its own. The device part runs them with `MallocScribble` and
`MallocGuardEdges`, and a `malloc:` line from the host's allocator fails the step.

`XL_SWIFTOBJC_LIBS` names the same folder as for swiftobjc. The host part translates the library and builds the host
(`check.lua <out> --host-only`, about ten minutes), the device part runs the steps of that run on the claimed phone
(`--device-only`):

```sh
XL_SWIFTOBJC_LIBS=<folder> ./xmakew l -P . recompiler/tests/libgenerics/check.lua <out>
```

The steps are `stepDictionary` (`[String: String]`), `stepDictionaryAny` (`[String: Any]`), `stepClosures` (`[() -> Int]`),
`stepNested` (`[[Int]]`), `stepSubstring` (`[Substring]` appended to and split) and `stepStress` (10 000 appends to an
`[Int]`, a `[String]`, a `[Substring]` and a `[String: Int]`, under `MallocScribble`).

`stepClassesOfHost` is the control of the two things the guest runtime does with a class of the host (`how-it-works.md`):
it does not read the class as Swift metadata (`ClassMetadata::isTypeMetadata` answers `false` outside the guest images and
the arena), and it takes its superclass from the host, not from where `ClassMetadata` keeps it. A literal `NSDictionary`,
an `NSMutableDictionary` and the immutable copy of it (made with Objective-C methods and a key the host made) are each cast
to three classes of the guest, which walks their chain of superclasses (`hostclass.guest.*`: `LibGenerics`, `Holder<Int>`
and the generic `Base<Int>`), and their metatype is cast to a generic class's (`hostclass.metatype.*`); a host object is
asked for a protocol it may conform to, which walks the same chain in the conformance lookup (`hostclass.conforms`); a host
object is cast to a host superclass, to a host subclass and to a host class it is not (`hostclass.superclass`,
`hostclass.number`); a guest class instance is cast to host and guest classes (`hostclass.control`); and two generic Swift
classes the runtime builds at run time (`Base<T>`, `Derived<T>`) are cast and asked for their superclass
(`generic.dyncast`, `generic.superclass`, `generic.subclass`), which need the arena the runtime's metadata allocator
takes them from to be one the test accepts. The cast of a host dictionary to `[String: Any]` is not a step of this
library: the bridging conformance of `Dictionary` is in the Foundation overlay, which the library does not carry, so
the cast is nil for every dictionary, an empty one too, with the old runtime and the new. A fixture with the overlay
(the reCAPTCHA SDK's, `JSONSerialization.jsonObject(with:) as! [String: Any]`) runs it.

`stepSwiftObjectHash` is the case of `-[_SwiftObject hash]`: an object of a Swift class that has no superclass of its own
is hashed by the Objective-C method of `_SwiftObject`, which asks whether the object's class conforms to `Hashable` and
walks the chain of superclasses to `_SwiftObject`, an Objective-C class of the guest's images whose layout the host kept.
`stepProxyHash` asks the host for `hash` twice of the shared object of the fixture and `stepPlainHash` of a plain Swift
class (`PlainHashed`); both report `proxy.hash` and `plain.hash` as `ok` on the 4S (measured on 2026-11-14, runtime and
lift of `64fa5260a`). Two steps of the same family are not in the check: `proxy.copy`
(`dictionaryWithDictionary:` of the bridged dictionary) stops with `unsupported: $sSS10FoundationE19_bridgeToObjectiveCSo8NSStringCyF`
because the library of this check has no Foundation overlay, and `proxy.json`
(`JSONSerialization.isValidJSONObject` of the bridged dictionary) reports `FAIL` on the 4S, which is the right answer for a
library without the overlay (cause measured on 2026-11-15). A spy on `+[NSJSONSerialization isValidJSONObject:]` (a library
preloaded with `DYLD_INSERT_LIBRARIES`) saw the dictionary arrive as the proxy of `_SwiftDeferredNSDictionary<String, String>`
with three entries, all of them an `XLG.__SwiftValue`: without the overlay `String` has no `_ObjectiveCBridgeable` conformance,
so the elements of a deferred dictionary are boxed instead of bridged to `NSString`, and the system method, which wants strings
for keys, refuses the boxes. A fixture with the overlay returns `true` for the same expression and for ten other shapes (a
`[String: String]` of long and of short strings, a `[String: Any]`, arrays and numbers; `stepProbeV` of the reCAPTCHA-style
fixture, 4S, 2026-11-15): its keys are `__SharedStringStorage` and `__StringStorage` objects of the type id of `CFString`, and
`JSONSerialization.data(withJSONObject:options:)` of the same dictionaries writes the JSON. The step is not in the check, because
its expectation holds only with the overlay.

`stepVaListBuilder` calls `getVaList([Int32(7), Int32(8)])` of the standard library and reads the two words of the list, then
returns. `getVaList` autoreleases its builder, an object of the static class `__VaListBuilder`, and the host's autorelease pool
drains after the step: the step reports `valist.builder` as `ok` and runs to `done` (4S, 2026-11-14). With `XL_PROXY=0` the
same library reports `ok valist.builder` and then stops with signal 11 in `objc_msgSend` at the pool's pop, the receiver's first
word being the address of `$ss15__VaListBuilderCN`; that is the control, and it is the failure that `NSString(format: "%d-%@", 7, "x")` and
`NSString(format:arguments: getVaList(...))` had on the 4S before `xl_proxy_hold` (the translated app fixture, probes U5, U7 and F3). The 41 steps of this check except `stepProxyRace` ran to `done` on the 4S with it.

The proxy steps hand an object of such a class to the host and use it there. `stepProxyCount`, `stepProxyKind`,
`stepProxyDescription`, `stepProxyIdentity` (`NSArray(object:)` gives back the object that went in), `stepProxyNested`,
`stepProxyMutation` and `stepProxyAny` bridge a `[String: String]` or a `[AnyHashable: Any]` (`_SwiftDeferredNSDictionary`) and have
the host ask `count`, `isKind(of:)` and `description`; a dictionary that the guest mutates after the host got it keeps three
entries on the host's side and has four on the guest's. `stepProxyLifetime` and `stepProxyUnique` (each
has an `After` step that `host.m` runs in a new autorelease pool) show the count of +1: a `Holder<Int>` the host keeps is not
destroyed when the guest drops it, the guest's `isKnownUniquelyReferenced` is false while the host holds it, a value whose
storage was handed out is copied on the next mutation (the host's side reads the old value through a round trip back to the
guest, the guest reads the new one), and both the uniqueness and the `deinit` are back after the proxy is gone.
`stepProxyWeak` has the host keep a `__weak` reference to a proxy and `stepProxyRace` has four host threads ask for the
same guest object 100 000 times each; both end with the guest checking that nobody holds the object but its own global.
`XL_PROXY=0` makes `stepProxyKind`, `stepProxyDescription`, `stepProxyIdentity`, `stepProxyNested`, `stepProxyAny`,
`stepProxyLifetime`, `stepProxyUnique` and `stepProxyWeak` stop with a signal 11 where the host reads the guest's metadata as a
class (the controls of `check.lua`, measured on the 4S). `stepProxyCount` and `stepProxyMutation` pass without a proxy as
well, so they only guard against a regression.

`stepProxyObject`, `stepProxyKeys`, `stepProxyValues` and `stepProxyEnumerate` use the same dictionary from the guest's
side: a lookup with a key that the dictionary gave (and none for an absent key), `allKeys` and `allValues` as arrays of
three, and `enumerateKeysAndObjects`, a block that goes from the guest to the host's `NSDictionary` code and back. The
`stepHost` steps (`Count`, `Object`, `KeyEnumerator`, `AllKeys`, `AllValues`, `GetObjects`, `Fast`, `Enumerate`) are done by
`host.m` itself, in armv7 code, with the messages that the host's own code sends to such a dictionary:
`-getObjects:andKeys:count:` into arrays of three, `-getObjects:range:` on the arrays that `allKeys` and `allValues` return,
`for ... in` (`countByEnumeratingWithState:objects:count:`) and `enumerateKeysAndObjectsUsingBlock:` with a stack block. The
methods of `_SwiftDeferredNSDictionary` are in the `ro` of a generic class, which the image gives no class object, so they
are found through `swift_generic_methods` of the manifest and their host IMPs are typed like the others: an `id *` buffer
whose length is the `count` argument or the length of the `NSRange` is converted element by element, the
`NSFastEnumerationState` is converted as a record and its items are given to the host as 32-bit objects, and a block
goes through the block bridge. Before that these methods had a host IMP of bare words, which wrote 8-byte pointers into the
host's 4-byte arrays and passed the stack block as an object.

`stepHostSequence` checks the same fast-enumeration path without a dictionary: `LibGenericsSequence` is a guest class that
conforms to `NSFastEnumeration` and hands out 40 objects in batches of the buffer size, and `host.m` calls
`countByEnumeratingWithState:objects:count:` on it directly. It checks the batches (16, 16 and 8), that every item the host reads
is non-nil and distinct, that `mutationsPtr` is the host state's own `extra[0]` (the guest sets it to its own `extra[0]`, which
is in the temporary record the wrapper converts the state through, so the wrapper maps it back) and that `for ... in` sees 40.

What the steps do not cover: the keys and values of the bridged dictionary come to the host as `XLG.__SwiftValue` boxes
and not as `NSString`, because the `_ObjectiveCBridgeable` conformance of `String` is in the Foundation overlay, which this
fixture does not load. So the steps look up with a key that the dictionary gave, a lookup with a host `NSString` finds
nothing, and `JSONSerialization` refuses the dictionary for its non-string key, as it should. JSON, `NSDictionary(dictionary:)`
and a lookup by string need a fixture that loads the guest's Foundation overlay. Measured on the 4S on 2026-11-14:
`+[NSDictionary dictionaryWithDictionary:]` of the bridged dictionary stops the process, the cause is not yet established;
`hash` sent from the host to a Swift object, a proxied one or an instance of a plain Swift class alike, stops in
`swift_conformsToProtocolCommon` (`_swift_class_getSuperclass` reads a null class at +0x20); and a Swift string of up to 15
ASCII bytes is bridged through `+[__StringStorage newTaggedNSStringWithASCIIBytes_:length_:]`, which iOS 6 does not have.
`stepShortString` bridges `"abc"` and reads its length and a character. It runs on two hosts: `host` has
`NSString+TaggedASCII.m` of the Backports compiled in (the library answers nil, and the Swift runtime then makes a heap
`__StringStorage`, the path of the longer strings) and reports `ok short.string`; `host_bare` has not and stops with
`unrecognized selector sent to class` (measured on the 4S on 2026-11-14, a control of `check.lua` that must not run to its end).
The page [the tagged ASCII string factory](../backports/Foundation/TaggedASCIIString.md) has the reasoning.

`stepDlsymFunction` calls two host CoreFoundation functions the way the Swift standard library does: it asks
`dlsym(RTLD_DEFAULT, "CFStringGetTypeID")` and `"CFGetTypeID"` for the address and calls it. A call through such an address
is guest code calling a host pointer, so before 2026-11-14 it stopped the process with "call to an address without translated
code" and a host address (`0x310aaba9` is `CFStringGetTypeID` in CoreFoundation on the 4S; the same stop ended a
`JSONSerialization` run of the reCAPTCHA fixture, because `_initializeBridgingFunctionsImpl` looks up `CFStringGetTypeID`,
`CFGetTypeID`, `CFStringHashNSString` and `CFStringHashCString` this way). `xlgen` maps `dlsym` to `xl_shim_dlsym`, which
answers a name that a guest image exports with the guest's address (`stepDlsymGuest`), the four names with an address of a slot in a table of the runtime and everything else with the host's answer; a
call to a slot runs `xl_function_entry`, which narrows the arguments by the shape in `xl_host_functions` (`o` object, `p`
pointer, `u` unsigned, anything else signed), calls the host function and widens the result. A further host function the
guest may look up needs a line in that table. The control is a translation without the `dlsym` line of the shim map: the
step then stops with the message above, naming `CFStringGetTypeID+0 of CoreFoundation`; with the line it reports
`ok dlsym.typeid` and `ok dlsym.object` (measured on the 4S on 2026-11-14, runtime of main). The message of a call or jump to
an address without code now says which host symbol and image the address belongs to, when it is one, and the host frames of a
crash report carry the offset in their image.

`stepDlsymGuest` is the other half of `dlsym`: a name that a guest image exports is answered with the guest's address, not the
host's. The Swift runtime looks up `$sSo10CFErrorRefas5Error10FoundationMc` (the conformance of `CFError` to `Error`),
`$sSo8NSObjectCSH10ObjectiveCMc` and three Foundation functions of the `NSError` bridge with `dlsym(RTLD_DEFAULT, ...)`; a
host that carries its own armv7 `libswiftFoundation` has the same names, the guest took those, followed the type reference of
the conformance to the host's metadata accessor `$sSo10CFErrorRefaMa` and called armv7 code (the stop of drop17 of the
reCAPTCHA SDK, `libswiftFoundation +0xa9bb8` in the host). `xlate` writes `xl_dlsym.h`: the exports of every guest image in the
order of the images (the first image that exports a name answers it, as dyld does), without the exports of the bridge image,
as a sorted pool of names with a table of offsets and addresses (no relocations; 31,000 names for the reCAPTCHA SDK with its
Swift libraries, 2 MB). `xl_shim_dlsym` searches it first when the handle is `RTLD_DEFAULT` and asks the host only when the
name is not found, so `CFStringGetTypeID` and the other host functions above are unchanged. The step looks up `rcf_dlsym_own`, which
only the guest exports (`dlsym.guest.own`), and `rcf_dlsym_shadow`, which the guest and the host executable both export
(`dlsym.guest.first`: the guest's answer 1, not the host's 2). `RTLD_NEXT` and `RTLD_SELF` take the same way. A handle that the guest got
from a host `dlopen` (the Swift overlays open `libdispatch`, `libicucore`, `libresolv` and `libSystem` and look functions up in them)
goes to the host. What the host answers is checked: an address in a section of code (`S_ATTR_PURE_INSTRUCTIONS` or
`S_ATTR_SOME_INSTRUCTIONS` of the image `dladdr` names, Thumb bit ignored) that has no slot of `xl_host_functions` is not given
to the guest, since a call to it stops the process at an address without translated code; `dlsym` answers `NULL` as for a
function the host does not have, and `xl-dlsym.log` (with `xl-log`) names it. `dlsym.host.refused` looks up `getpid` and
`dispatch_get_specific`, `dlsym.host.data` a data symbol (`kCFAllocatorNull`), which is handed over as before. The same step
checks the classes: `RCFTwin` is a class of the guest (`@objc(RCFTwin)`) and of the host, and `objc_getClass`,
`objc_lookUpClass` and `objc_getMetaClass` (a manual bridge since 2026-11-16, the host's function looked
for the name without the namespace prefix) answer the guest's class (`class.guest.first`, `class.meta.guest.first`).
`NSClassFromString` is not in the step: it takes a `String`, and the bridge of a `String` to `NSString` is in the Foundation
overlay, which the library of this check does not carry (the step stopped on the 4S with
`unsupported: $sSS10FoundationE19_bridgeToObjectiveCSo8NSStringCyF`, measured on 2026-11-16).

What the audit of the guest images' call sites of `dlsym`, `dlopen`, `dladdr`, `objc_getProtocol` and the class lookups (2026-11-16, the
SDK with its twelve Swift libraries) left as it is: `dladdr` of a guest address answers 0 (the guest range is in no host image;
the Swift runtime uses it for diagnostics); `__dyld_is_objc_constant` of a guest address answers false; `_dyld_register_func_for_add_image`
calls back for guest images only in library mode, and no guest image imports `_dyld_image_count`, `_dyld_get_image_header` or
`_dyld_get_image_name`; the CoreFoundation names of `__initializeAvailabilityCheck` (`CFPropertyListCreateWithData` and others) are
reached only when `dlsym` finds no `_availability_version_check`, which the guest's own `dlsym` answers; `objc_getProtocol` looks a name up in
the host's runtime, where the registry registers the guest's protocols under their own names, so a protocol of the same name in
the host and in the guest is the one that registered first.

`stepExtraInhabitants`, `stepExtraInhabitantsStdlib` and `stepExtraInhabitantsBig` keep the contract of an extra inhabitant
of a pointer ([extra-inhabitants.md](extra-inhabitants.md)). They round-trip store and get for a struct with a class field in
an optional, an enumeration with a class payload and empty cases 0 to N, and an `Optional` of a class, once through code that
knows the type and once through a generic function (the witnesses), and each of them *consumes* the values (`consume`,
`removeAll`) and counts the deinits: the tag of the generic `Optional` reads anything but 1 as `.some`, while the outlined copy
and destroy read `tag == 0`, so a wrong tag shows as a leak or a release too many, not as a wrong answer. `…Big` has 4095
empty cases and the `nil` of the optional as the 4096th, the last index inside the contract. The steps report
`xi.enum.*`, `xi.struct.*` (`generic`, `inline`, `copies`, `destroyed`, `balance`, `consumed`, `released`), `xi.class.released`,
`xi.stdlib.*` and `xi.big.*`, and `check.lua` also requires `report.txt` to list the witnesses of `XiBox` and
`AncestorRepresentation` as rewritten and `Plain`, `AnyHashable` and `SmallVectorBase` as not. Measured on the 4S on
2026-11-14: with the runtime patched and the lift on, every name is `ok`; with `XL_XI_EXCEPT="Plain AnyHashable"`
(`stepExtraInhabitantsControl`) `xi.control.struct`, `xi.control.enum` and `xi.control.stdlib` FAIL (the lift negative
control); with the lift on and the runtime of main (`LeastValidPointerValue` 4 GB) only `xi.class.released` FAILs, because
the runtime's own witness for an `Optional` of a class, which a generic function reaches, took a pointer for an extra
inhabitant and the object was never released (the runtime negative control).

`stepExtraInhabitantsTuple` keeps the count of an extra inhabitant: generic code stores the `nil` of an
`Optional<(label: String?, value: Any)>` (the element of `Mirror.children`) into memory filled with `0xAA`, and code that
knows the type reads it back as `nil` (`xi.tuple.none`); the runtime and the compiler agree on which element of the tuple
holds the extra inhabitant only when they count the same for `Any` and `String?`. The step then walks the children of a
structure (`xi.tuple.children`) and prints it (`xi.tuple.describe`), which stopped the program in `swift_retain(1)` at the end
of the loop while the runtime counted 4096 for `Any`.

A library on the device has no
`dladdr` for the guest image, which the loader maps itself, so the runtime knows its range (`xl_guest_low`,
`xl_guest_high`) and a class of the guest is a class of the library. A class that the Swift runtime builds at run time has
the superclass's size and fields from the host layout: the runtime reconciles them when it registers the shadow, and a
subclass smaller than its superclass stops the program with a message.

The host part also reads `report.txt` of the translation. Swift declares the `NSRange` argument of the `NSString` methods that
`__SharedStringStorage` overrides as `{?=qq}`, which no SDK declaration matches name for name, so the host IMP of
`getCharacters:range:` was built from the guest encoding: a 16-byte struct of two `long long`, which the host's call
(`NSRange` is two 32-bit words) read from the wrong registers and stack slots, and `NSURL(string:)` died in
`String.UTF16View` with "String index is out of bounds". `xlgen` now matches a guest method with an SDK declaration by the
shape of its encoding (struct names ignored, integers compared without their signedness), and the check requires the
report to say that the IMP of `getCharacters:range:` comes from the SDK declaration and is `{_NSRange=II}`. On the 4S
`URLRequest(url:)` of a Swift `String` runs after the fix and fails before it.

Each fix has a step that fails without it (the 4S, one fix taken out at a time): without the image range `stepDictionary`
exits 139 (so do `stepClosures`, `stepNested`, `stepSubstring` and `stepStress`); without the reconciliation
`stepDictionary` and `stepDictionaryAny` still pass, and `stepClosures`, `stepNested`, `stepSubstring` and `stepStress`
stop on a `malloc:` checksum error of a freed block.

### library (device part by hand)

A control for [library mode](../../explanation/recompiler/library-mode.md): an app that loads a translated library into
its own process, next to a heap of its own size. `tests/library/check.lua` has two variants, `objc` (the default) and
`swift`, one fixture each with the same public API: `RCFClient` (`+clientWithSeed:`, `-bump`, `-seed`,
`-describedLength`, `-hostBundle`, `-tokenForAction:`, `-executeWithAction:completion:`) and `RCFToken`. Nothing in the
API is a string, because a Swift `String` that crosses an Objective-C signature goes through the Foundation overlay,
which the guest does not have yet; the strings stay inside the library (`describedLength` builds one).

The host part, which `recompiler_corpus/library` runs, first runs the loader on the Mac (`loader.c`: `xl_loader.c` over a
model of a 4S process's address space, fourteen scenarios of reserving, releasing, loading without a reservation and of every
failure, each of which must leave nothing held that the host did not ask to keep;
[the scenarios](library-mode.md#the-check)). It then translates the `objc` fixture with `XL_LIBRARY=1` and checks
the dylib statically:

- the library has no `__X<n>` segment, has `__XGUEST` and `__LINKEDIT`, and the guest image header (`magic`, `version`, a
  granule-aligned range not below `XL_BASE`) is right;
- the dylib exports exactly `_xl_library_class`, `_xl_library_diagnostics`, `_xl_library_init` and the `_xl_objc_category_<n>` of the guest's categories;
- the registry `<name>-classes.dylib` has only the `__objc_*` sections, no code and no exports, and a category list entry for
  each category;
- the armv7 host app (`host.m` with `xl_loader.c`) builds and signs.

The device part copies the dylib and the host to the claimed phone and runs the host. The host first grows its own
resident set to the size given as an argument (85 MB by default, `XL_LIBRARY_RESIDENT_MB`), loads any dylibs named after
it the way an app's frameworks are loaded, reserves the guest range, loads the library, and prints `ok <name>` for 23 checks (22 in the Swift variant):
`reserve`, `load`, `class` (`NSClassFromString`), `create`, `methods`, `describe` (a string built in the library),
`bundle` (the library's `hostBundle` is the app's `mainBundle`), `bundle.path`, `token` (a value that depends on a
static of the library), `category` (a method that a category of the guest adds, found through the registry; the Objective-C
variant only), `completion` and `completion.thread` (a block called on another thread), and the class lookup by name
(`find.unloaded`, `find.exact`, `find.unknown`, `find.thread`; `find.before`, `hook.absent`, `hook.old`, `hook.guest`, `hook.exact`,
`hook.unknown`, `find.hook` in the Objective-C variant, where the guest installs a hook through `objc_setHook_getClass`;
`find.swift`, `find.host` and `block.generic` in the Swift variant, where the guest's own `libswiftCore` installed it: `xl_find_class`
finds `"RCFixture.Client"` and the host's `NSClassFromString` does not; [the contract](library-mode.md#the-class-of-a-name-xl_find_class-xl_library_class-objc_sethook_getclass)).
Four negative controls run first: a held
range, a guest image format the loader does not read, a registry that is not next to the library, and an init without a
reservation. Two more launches are a host that keeps no reservation: one never calls `xl_reserve` and loads after its heap
grew (`lazy.free`, then every name but `reserve`), one reserves, calls `xl_release` and reserves again (`release.held`,
`release.free`, then every name). `XL_LIBRARY_LAUNCHES` repeats the launch, and `XL_LIBRARY_INSTALL_NAME=executable` names the library by
`@executable_path` and starts the host without `DYLD_FALLBACK_LIBRARY_PATH`. It prints
`measure <step> resident=… virtual=… threads=…` after each step and the address map of the process (`map <step>
<start>-<end> <protection>`). A watchdog `alarm` ends a hung host after 180 seconds.

`./xmakew l -P . recompiler/tests/library/check.lua <out> [objc|swift] [--host-only]` runs a variant whole (with an
absolute path to the script). The `swift`
variant needs `XL_SWIFTOBJC_LIBS` (the same folder as swiftobjc) and takes the translation of the guest `libswiftCore`,
`libc++` and `libc++abi` with it, which is minutes to an hour of compile time depending on the load of the machine.
It also builds the host with Swift code of its own (`hostswift.swift`, against the armv7 runtime of
`revenant@swift-runtime`) and checks that the host's Swift names and bridging are the same before and after the
library loads (`host.bridge.before`, `host.names`, `names.disjoint`, `host.bridge.after`), and that the Objective-C
runtime reports no class implemented twice. [The names and variables](library-mode.md#the-check).

### recaptchareal (device part by hand; needs the real SDK)

The reCAPTCHA Enterprise SDK is not in the repository. The check runs it when the SDK is at hand and says `skip:` and ends
without an error when it is not: `XL_RECAPTCHA_SDK` names the file, or `telegram-build/.agent-work/recaptcha-sdk/RecaptchaEnterprise.dylib`
is found by walking up from the checkout; its sha256 is pinned in `recompiler/tools/recaptcha_build.lua` and another file is
refused. `XL_SWIFTOBJC_LIBS` names the folder with the arm64 Swift runtime of `revenant@swift-runtime`, `libc++.1.dylib` and
`libc++abi.1.dylib`.

`./xmakew l -P . recompiler/tests/recaptchareal/check.lua <out> [--drop recaptcha-sdk.txt] [--execute] [--rounds N] [--seconds N] [--host-only]`
translates the SDK in library mode (or takes the library of a drop's `recaptcha-sdk.txt`), builds `rcsdk`, a host program of
the shape of an app that has its own armv7 Swift runtime (`hostswift.swift` runs `Locale`, `Data`, `URL`, a Swift `Error` as `NSError` and an
`NSDictionary` of the host's libswiftFoundation before the library is loaded), and runs it on the claimed phone: `xl_reserve`, `xl_load`, `xl_find_class` of `RecaptchaEnterprise.Recaptcha` and `RecaptchaAction`,
`fetchClientWithSiteKey:completion:` with an empty key and no network (the answer is an error, not a crash), with `--execute`
`executeWithAction:completion:`, `--rounds` times, then three seconds for the pools of the guest threads. It prints a line for
each step with the resident size. It fails when a step is missing, when the fetch does not answer in `--seconds`, or when the
process does not end with exit 0. A run takes 16 s on the 4S; the drop17 stop (`dlsym` answered with the host's `CFError: Error`
conformance, see `stepDlsymGuest` above) and the double free of drop16 both reproduced in it.

`./xmakew l -P . recompiler/tools/drop.lua NAME [--out DIR] [--no-verify]` builds a drop in one command and stops at the first step that
fails: it builds `xlate` and `xlgen`, translates the SDK with the same recipe as the check, copies the library, its registry,
the loader files and the reports to `telegram-build/.agent-work/recaptcha-real/NAME` (or DIR), writes `recaptcha-sdk.txt` with the
two sha256 and, when `telegram-build/tools/recaptcha_sdk.lua` is there, verifies the drop with it. It prints the path and both
digests. It needs `XL_SWIFTOBJC_LIBS` and `BACKPORTS_DIR` in the environment (and `REVENANT_CACHE` in a worktree); the second translation of an
unchanged lift reuses the lifted objects (`lift.stamp`).

The guest Swift runtime of a drop is the install of the current recipe and nothing else (drop17 to drop21 were lifted from the install of an
older recipe, because the scratch folder of libraries still pointed at it). `drop.lua` resolves the real path of every runtime library in
`XL_SWIFTOBJC_LIBS` and stops unless they all lie in one `swift-runtime` install whose `manifest.txt` carries the `recipe` of
`packages/s/swift-runtime/port/digest.lua`, or whose build hash is the one `--runtime-key BUILDHASH` names; a `libswiftCryptoKit` or
`libswiftNetwork` of the folder built against another runtime stops it too. After the translation it reads the `revenant_swift_runtime_<hash>`
mark the guest `libswiftCore` leaves in the library and stops unless that is the only mark and the key of the runtime it was given. The drop gets
a `runtime.txt` beside `recaptcha-sdk.txt` (`runtime_key`, `runtime_recipe`, `libswiftcore_sha256`; the reader of `recaptcha-sdk.txt` in
telegram-build refuses a key it does not know, so those lines are not in it). The check `dropkey` builds a store of two fake installs and
runs every one of those refusals.

The library link takes the runtime objects from the same loop that compiles them (`runtime_objects` in `tools/translate.lua`), and a
link that fails on an undefined `_xl_*` symbol is not retried with `-U`: those symbols are the runtime's own, nothing in the application
defines them, and a lazy binding would stop the program at its first call. `drop.lua` also reads `nm -u` of the library before it
writes the drop and stops on any `_xl_*` import (drop20 shipped five `_xl_journal_*` imports because `journal.o` was not in the link).

### cxxinit and refrepro

These build targets each translate an app to an `.app`, for a device or the emulator.

- `recompiler_cxxinit` covers C++ static initialisers in an Objective-C++ app.
- `recompiler_blockid` is a console program that passes Objective-C blocks across the guest boundary: a block stored in an `NSArray` and read back and invoked from the guest, its identity kept, a block used as a dictionary key, a block that survives the release of its array, and a block invoked from the host. It prints `PASS` or `FAIL`.
- `recompiler_refrepro` is built with ARC, like OneBusAway, so ivar stores compile to `objc_storeStrong`. That is the
  release-of-old-ivar site that faulted.

## perf: devtime

`recompiler_devtime` builds the on-device wall-clock benchmark, which compares translated and native code. It is a
normal armv7 iOS command-line executable that links libSystem and libm.

1. The arm64 kernels are lifted to armv7.
2. `kernel_addrs.h` is generated: each kernel's guest address is its `_k_<name>` symbol plus `0x10000000`, in
   `native_run.c`'s order.
3. The native kernels, the dispatch and the timing main are compiled.
4. Everything is linked with the guest segments fixed at their vmaddrs (`-no_pie` and the layout), and with libSystem
   for `mach_absolute_time`, `task_info`, `printf` and libm.

The ninth kernel, `tailchain`, is a pipeline of eight stages that each hand over to the next with a tail call (what a
compiler makes of functions that end in a call). The other eight kernels have no jump to the start of another function,
so a change in how the lift treats such jumps (see [tailcalls](#tailcalls)) leaves their lifted code byte for byte as
it was and can only show in this one.

### Lifted-code mode: Thumb-2 and the outliner

The lifted code is compiled in the mode `XL_LIFTED_MODE` names: `thumb` (default) or `arm`; the benchmark's
`./xmakew l -P . recompiler/tests/perf/build.lua <out>` takes the same variable. Measured on an iPhone 4S (A5), the same
kernels three times per mode, with every result equal to the native one:

| | arm | thumb |
|---|---|---|
| geomean xl/native, three runs | 1.91, 1.89, 1.91 | 1.89, 1.90, 1.90 |
| crc32, ms (median of three) | 0.796 | 0.793 |
| sha256 | 4.807 | 5.145 |
| fnv64 | 1.018 | 1.016 |
| sort | 14.554 | 12.920 |
| list | 10.171 | 10.101 |
| geometry | 8.809 | 8.902 |
| matrix | 7.923 | 7.921 |
| text | 3.546 | 3.707 |

Thumb-2 leaves the geomean where it was (per kernel, sort is 11% faster, sha256 7% and text 5% slower in all three runs,
the rest within 1%) and takes a third out of the code: the `__text` of three pieces of the reCAPTCHA SDK's lifted code (about 6 MB of bitcode
each) is 7.59, 7.63 and 7.72 MB in ARM mode and 5.03, 5.09 and 5.09 MB in Thumb-2 (33 to 34% less); a translated
library of the libexceptions check is 382,048 bytes in ARM mode and 348,784 in Thumb-2. The `hostbridges` and
`libexceptions` checks pass on the phone in both modes.

LLVM's machine outliner (`-mllvm -enable-machine-outliner=always`, Thumb-2 only) would take another 10.5 to 12.5% off
the same pieces (4.47, 4.46 and 4.55 MB), but with LLVM 23.1.3 it miscompiles the lifted code, and the translator does not
offer it. The same two checks, built with it, fail on the phone: `libexceptions` ends with SIGSEGV in its first step and
`hostbridges` with a fault at address 0x1a0 inside an outlined function. What the compiler does: a call to an outlined
function that needs `lr` saves it with `str lr, [sp, #-8]!` and restores it with `ldr lr, [sp], #4`, so `sp` is 4 bytes
lower after every such call, and the body of the outlined function reads the stack at an offset adjusted by 4 (`ldr.w
r4, [sp, #0x910]` where the code it replaced read `[sp, #0x90c]`) while `sp` has moved by 8, so it takes the neighbouring
slot. There is no option that chooses another call construction (`-mllvm -help-hidden` lists none).

`recompiler/tests/outliner/repro.ll` is one lifted function (`sub_10106460` of the `hostbridges` check, 20 KB of IR) in
which the outliner makes two such calls. After a change of the LLVM package, one command says whether the compiler still
does it:

```sh
./xmakew l -P . recompiler/tests/outliner/check.lua <out>
```

It compiles `repro.ll` with the outliner, writes the assembly to `<out>/repro.s`, and compares the amount `lr` is saved
and restored by at each call. It prints the compiler's version and either that the amounts still differ, or that they
agree and the outliner can be tried again (the flags above, then the `hostbridges` and `libexceptions` checks on the
phone). It is not in the corpus's test list, because both of its answers are a pass.
