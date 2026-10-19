# Carrying a 64-bit NaN-boxed JSValue on ARMv7

Written August 2026, when the plan was to build an ARMv7 baseline JIT against WebKit trunk.
That plan was abandoned the same day: `webkitglib/2.54` was branched before the 2026-08-01
removal and still carries `ARMv7` in `offlineasm/backends.rb`, `ARMv7Assembler.h`,
`MacroAssemblerARMv7.h` and `LowLevelInterpreter32_64.asm`, so we get a working ARMv7 JIT and
the old 32-bit JSValue representation for free by basing on that branch instead.

That reprieve expires. When 2.56 drops ARMv7 (expected March 2027) the port has to be written
against an engine that has only one JSValue representation, and it is 64-bit. This note is what
was worked out before the switch, so that work does not have to be redone.

Everything below was derived from trunk at `1798fb124` (`webkit-trunk-jit`, branch
`ios6-armv7-jit`) and from the 32-bit backend upstream deleted.

## What upstream did, and what it means for this fork

**The port has an ARMv7 JIT today.** `webkitglib/2.54` was branched before the
removal and still ships the whole 32-bit backend, and the port builds it:
`ENABLE_JIT=ON`, `ENABLE_DFG_JIT=ON`, `ENABLE_C_LOOP=OFF`. Nothing has to be
restored, and nothing upstream does to trunk can take it away from a branch that
already carries it.

What upstream's removal decides is the *next base*. Two commits did it, and any
series cut after the second has no ARMv7 backend to inherit:

| Commit | Date | Effect |
| --- | --- | --- |
| `653075383222` | 2026-03-13 | `[ARMv7] Disable JIT` — *"no longer working after recent breakage, disabling to keep EWS green"*; 9 files, +19 / -51 |
| `857bd4334690edda28e6f535e2f828dbc5064c4d` | 2026-08-01 | `[armv7] Remove ARMv7 JIT support` — *"ARMv7 runs on CLoop now"*; 187 files, +455 / -18903 |

```sh
git -C <a full WebKit clone> show 857bd4334690 > remove-armv7-jit.patch
```

That diff is worth reading on the day the base moves, to see exactly what a
newer tree is missing. It is not, however, where the code comes back from: this
fork's own branch builds and runs that backend, so an update carries it forward
from here, along with the fixes this port made to it. See
[core-update.md](core-update.md), step 4.

These are the files the removal deleted whole, and they carry over as files:

    Source/JavaScriptCore/assembler/MacroAssemblerARMv7.h / .cpp
    Source/JavaScriptCore/assembler/ARMv7Registers.h
    Source/JavaScriptCore/dfg/DFGSpeculativeJIT32_64.cpp
    Source/JavaScriptCore/jit/JITOpcodes32_64.cpp
    Source/JavaScriptCore/jit/CallFrameShuffler32_64.cpp
    Source/JavaScriptCore/offlineasm/arm.rb

One warning if the diff is ever reverted onto a newer tree rather than carried
over from here: it restores the code **and the breakage that caused the March
disable**. That commit points at where the breakage lives: `Repatch.cpp`
(`linkPolymorphicCall`, `tryCacheArrayGetByVal` / `PutByVal` / `InByVal`) and
`DFGJITCompiler.cpp` (`link`, `addPropertyInlineCache`) — polymorphic call
linking and property inline caches. Both are DFG and inline-cache territory, so
the cheap experiment is to revert both commits and then build with the baseline
JIT only and the DFG off: if the breakage is confined to the optimising tier,
that sidesteps it and still buys most of the speedup over the interpreter.

The JIT also needs executable memory. The device is jailbroken and does not
enforce code signing, so `PROT_EXEC` mappings should be available — untested.

Carrying either revert is a permanent fork of some seventeen thousand lines,
re-applied on every engine update. Note also that a reverse-apply reintroduces
`#if USE(JSVALUE64)` guards around code that must always be live, and trunk no
longer defines that macro at all, so those guards evaluate false and delete the
code they wrap. That is the first trap in this direction.

---

## 1. The problem, precisely

Modern JSC has exactly one JSValue representation: a 64-bit NaN-boxed value. `USE(JSVALUE32_64)`
is gone, and so is `USE(JSVALUE64)` — there is no macro, because there is no choice. In trunk
`git grep -c "USE(JSVALUE64)" -- Source/JavaScriptCore` returns nothing.

So an ARMv7 JIT for the current engine is not the old tag/payload JIT. It has to run 64-bit
values through 32-bit registers, of which there are about ten.

Relevant encoding constants (`runtime/JSCJSValue.h`):

| constant | value | high word | low word |
|---|---|---|---|
| `NumberTag` | `0xfffe000000000000` | `0xfffe0000` | `0` |
| `NotCellMask` = `NumberTag \| OtherTag` | `0xfffe000000000002` | `0xfffe0000` | `0x2` |
| `DoubleEncodeOffset` (1<<49) | `0x0002000000000000` | `0x00020000` | `0` |
| `ValueNull` / `ValueFalse` / `ValueTrue` / `ValueUndefined` | `0x2` / `0x6` / `0x7` / `0xa` | `0` | small |
| a `JSCell*` | 32-bit pointer | `0` | pointer |

The high word carries all the type information and the low word carries all the payload. That is
the single most useful fact in this document: **on a 32-bit-pointer machine, every tag test is a
test of one 32-bit register.**

---

## 2. What arm64_32 gets for free that ARMv7 does not

arm64_32 (watchOS) already runs a 64-bit JSValue with 32-bit pointers, so it looks like the
precedent. It is not, and the reason is worth stating plainly.

WTF distinguishes two axes, and they are already separate in `PlatformCPU.h`:

* `CPU(ADDRESS64)` / `CPU(ADDRESS32)` — pointer width, from `__SIZEOF_POINTER__`.
* `CPU(REGISTER64)` / `CPU(REGISTER32)` — general purpose register width.

arm64_32 is `ADDRESS32` + `REGISTER64`. ARMv7 would be the **first `REGISTER32` JIT target**.
`MacroAssembler.h` already keys `loadRegWord`/`storeRegWord` off `CPU(REGISTER64)`, so the axis
exists; nothing has ever exercised the `REGISTER32` side of it.

What that buys arm64_32:

* A JSValue is one register. `JSValueRegs` stays a single `GPRReg`. `load64`/`store64`/`move` are
  one instruction each, and they are single-copy atomic.
* The entire ADDRESS32 delta in the backend is **one conditional**. `MacroAssemblerARM64.h` is
  8318 lines and contains exactly one `#if CPU(ADDRESS64)` — a `loadPtr` that dispatches to
  `load64` or `load32` for call targets. Everything else is handled by one macro,
  `DEFINE_PTR_FUNC` in `TargetAssemblerDefinitions.h`, which makes `xxxPtr` mean `xxx32` when
  pointers are 32-bit.
* 31 allocatable registers, so pinning `numberTagRegister` and `notCellMaskRegister` costs ~6% of
  the register file. On ARMv7 the same two constants would cost 40% (see §4).
* AAPCS64 passes and returns 64-bit values in single registers. No argument alignment, no
  arguments split across a register and the stack.

So arm64_32 tells you nothing about how to do this. It is a 64-bit backend with narrow pointers.
ARMv7 is a 32-bit backend with wide values, and no existing WebKit target has that shape.

---

## 3. The register model

### 3.1 The register file

Darwin/iOS ARMv7 (`ARMv7Registers.h` already encodes the Darwin callee-save set correctly, and
notably marks **r9 as volatile on Darwin**, unlike the generic AAPCS):

```
  r0 r1 r2 r3   AAPCS argument/result, volatile
  r4 r5         callee saved
  r6            callee saved
  r7            platform frame pointer (Darwin ABI mandates it)
  r8            callee saved
  r9            volatile on Darwin
  r10 r11       callee saved
  ip (r12)      volatile, linker veneer scratch
  sp lr pc      fixed
```

Two of those are non-negotiably spoken for by the backend itself: the existing
`MacroAssemblerARMv7` reserves `r6` as `addressTempRegister` and `ip` as `dataTempRegister`, and
it needs both — one to materialise an address, one to materialise a constant. `r7` is the call
frame register, which is also the platform frame pointer, so backtraces through JIT frames keep
working. That leaves **ten allocatable registers**.

### 3.2 A 64-bit register is a fixed pair named by its low half

`JSValueRegs` in `jit/GPRInfo.h` holds a single `GPRReg` and the whole engine is written against
that. Changing it back to a tag/payload pair means changing every consumer — that was the
JSVALUE32_64 world and it is gone. So the model has to be:

> A logical 64-bit register **is** a `GPRReg`. It names the physical register holding the low
> word. The physical register holding the high word is a fixed, statically known partner.

The pairing is not free to choose. Two constraints fix it:

1. The engine already spells out `jsRegT10`, `jsRegT32`, `jsRegT54` and documents them as
   "`jsRegT{2n+1}{2n}` always maps one-to-one to GPR `regT{2n}`". That naming is a fossil of the
   32-bit world and it means the pairing must be `regT{2n}` with `regT{2n+1}`.
2. AAPCS returns a 64-bit value in `r0:r1` and requires a 64-bit argument to start at an even
   register. If `regT0` is `r0`, then the `regT0` pair is `r0:r1`, which is exactly the AAPCS
   64-bit return pair — so an operation returning an `EncodedJSValue` lands its result directly
   in the baseline accumulator with no shuffle.

Both constraints agree. The pairing is:

| logical 64-bit reg | low (name) | high (partner) | notes |
|---|---|---|---|
| `regT0` / `jsRegT10` | r0 | r1 | AAPCS 64-bit return; first 64-bit argument slot; baseline accumulator |
| `regT2` / `jsRegT32` | r2 | r3 | second AAPCS 64-bit argument slot |
| `regT4` / `jsRegT54` | r4 | r5 | callee saved pair |
| `regT6` / `jsRegT76` | r8 | r9 | split on callee-savedness (r8 saved, r9 not), so treat the pair as caller-saved |
| MacroAssembler scratch | r6 | ip | non-adjacent, see below |
| — | r10 (`regCS0`) | — | pinned: metadata table pointer, 32-bit |
| — | r11 (`regCS1`) | — | pinned: JITData pointer, 32-bit |
| — | r7 | — | `callFrameRegister` |

**Four 64-bit registers.** That is the number the whole port has to live inside.

The odd-numbered `regT`s keep their names because plenty of what the baseline JIT holds — a
`Structure*`, a bytecode offset, a butterfly, a `StructureStubInfo*` — is 32 bits wide and does
not want a partner. `BaselineJITRegisters.h` refers to `regT0` through `regT5` as distinct
registers and would not compile otherwise.

`r10`/`r11` are pinned rather than paired. Once the four pairs and the two backend temporaries are
allocated they are all that is left, and both the metadata table pointer and the JITData pointer
are 32-bit and wanted on nearly every bytecode. Pairing them into a fifth JSValue register and
reloading them from the frame would cost more than it bought.

The scratch pair `(r6, ip)` is **not adjacent**, which is legal only because this is Thumb-2:
`LDRD`/`STRD` in Thumb-2 encode `Rt` and `Rt2` as independent 4-bit fields, unlike the ARM A1
encoding which demands an even/odd consecutive pair. Any future code that wants `LDREXD` should
recheck this — in Thumb-2 those are also independently encoded, but the ARM encoding is not, and
it is an easy thing to get wrong from memory.

### 3.3 `JSValueRegs::uses()` must see both halves, and that is the audit tool

Making `JSValueRegs::uses(gpr)` return true for the partner turns every existing
`static_assert(noOverlap(...))` in `BaselineJITRegisters.h` into an ARMv7 register-pressure check
that fires at compile time. Likewise `StaticScratchRegisterAllocator::countRegisters(JSValueRegs)`
has to return 2, and `constructScratchRegisters` then automatically stops handing out high halves,
because it already filters with `noOverlap`.

This is the cheapest correctness mechanism available in the whole port. Do it first. The
compile errors it produces are the list of opcodes that do not fit (§7.2).

### 3.4 Frame layout and calling convention

* `sizeof(Register)` is 8 (it holds an `EncodedJSValue`), so JS frame slots are 8 bytes on ARMv7
  exactly as on ARM64. Nothing changes there.
* `prologueStackPointerDelta()` is `2 * sizeof(CPURegister)` = 8 bytes: the prologue pushes fp and
  lr. `CPU.h` in the worktree already has ARMv7 added to that branch.
* Stack alignment stays 16 bytes; AAPCS only requires 8 at public interfaces, so this is safe.
* `NUMBER_OF_CALLEE_SAVES_REGISTERS` is 18 = r10, r11, plus d8..d15 at two GPR-slots each.
* r4, r5, r6, r8 are AAPCS callee-saved but used as JIT temporaries, so the VM entry thunk has to
  save them. The old backend did exactly this; it is not new work.

**Passing a JSValue.** AAPCS assigns core registers in order, and a 64-bit integral type is
8-byte aligned, so it must start at an even register — if the next free register is odd, one
register is skipped as padding. Anything that does not fit goes on the stack.

The practical consequence is severe. For a typical operation
`op(JSGlobalObject*, EncodedJSValue, EncodedJSValue)`: r0 takes the global object, r1 is skipped
for alignment, r2:r3 takes the first value, and **the second value goes on the stack**. Only one
JSValue argument fits in registers on almost every operation JSC has.

---

## 4. Dropping the tag registers — the ARM64 optimisation inverts here

ARM64 pins `NumberTag` in x27 and `NotCellMask` in x28 because materialising a 64-bit constant
there costs four instructions (movz + three movk), so keeping them live pays for itself.

On ARMv7 that trade inverts completely:

* **Cost.** Neither constant has a zero low word (`NotCellMask` is `NumberTag | OtherTag`, low
  word `0x2`), so pinning both means two full pairs — four of ten allocatable registers, and two
  of the four JSValue registers. The baseline JIT cannot function with two JSValue registers.
* **Benefit.** Approximately zero, because every test only looks at the high word:

| test | sequence | instructions |
|---|---|---|
| `isNumber` — `v & NumberTag` | `lsrs t, hi, #17` | 1 + branch |
| `isInt32` — `v >= NumberTag` unsigned | `cmn hi, #0x20000` | 1 + branch |
| `isCell` — `!(v & NotCellMask)` | `and t, lo, #2` ; `orrs t, t, hi, lsr #17` | 2 + branch |
| box int32 | `movw hi,#0` ; `movt hi,#0xfffe` | 2 |
| box double | `vmov lo, hi, Dn` ; `add hi, hi, #0x20000` | 2 |
| unbox double | `sub hi, hi, #0x20000` ; `vmov Dn, lo, hi` | 2 |
| box/unbox cell | high word is zero / take the low word | 0 |

Two of these deserve explanation.

`cmn hi, #0x20000` is a compare against `0xfffe0000`: `CMN Rn,#imm` computes `Rn + imm` and
`0x100000000 - 0x20000 = 0xfffe0000`, so it sets exactly the flags `CMP Rn,#0xfffe0000` would,
and unlike that compare the immediate **is** a valid Thumb-2 modified immediate (a single set
bit). `0xfffe0000` is not. The existing `MacroAssemblerARMv7::compare32AndSetFlags` already tries
`cmn` with the negated immediate when `cmp` cannot encode it, so this falls out for free. The
low word can be ignored because for an unsigned relational compare against a value whose low word
is zero, no unsigned low word is ever less than zero — the high word decides. (The same argument
holds for signed `>=` / `<`, since the low halves compare unsigned.)

`lsr #17` works because `0xfffe0000` is exactly bits 31..17.

**Therefore:** set `numberTagRegister` and `notCellMaskRegister` to `InvalidGPRReg` on ARMv7 and
reclaim four registers. This needs almost no new code, because `TagRegistersMode` already exists
with a `DoNotHaveTagRegisters` path that emits the `TrustedImm64` form of each test. All that is
required is that ARMv7 default to that mode, and that `branch64(cond, reg, TrustedImm64)` and
`branchTest64(cond, reg, TrustedImm64)` in the backend **skip the half whose immediate word is
zero**. Do that and the generic `AssemblyHelpers` path compiles to the table above with no
ARMv7-specific code in `AssemblyHelpers.h` at all.

`CallFrameShuffler` already handles `numberTagRegister == InvalidGPRReg` (it checks explicitly
before locking the register), so that part is anticipated.

---

## 5. What the 64-bit layer looks like

The deleted backend is a much better starting point than expected, because Wasm i64 support had
already forced a pair-based 64-bit arithmetic layer into it. `MacroAssemblerARMv7.h` from the
removal patch already contains, with explicit `(Hi, Lo)` quadruple signatures:

`add64`, `and64`, `or64`, `xor64`, `sub64`, `mul64`, `compare64`, `branch64` (with a correct
signed/unsigned two-word comparison), `branchTest64`, `countLeadingZeros64`,
`countTrailingZeros64`, `move64ToDouble`, `moveDoubleTo64`, `truncateDoubleToInt64/Uint64`,
`loadPair32`/`storePair32`, `transfer64`, `uMull32`, and the `ldrd`/`adc`/`sbc`/`umull`/`mla`/
`rbit`/`clz`/`ldrexd`/`strexd` emitter calls they need.

So the work is not "write 64-bit arithmetic". It is **an adaptation layer**: keep those as private
primitives and expose the modern single-register interface on top.

```cpp
void add64(RegisterID op1, RegisterID op2, RegisterID dest)
{
    add64(highRegister(op1), op1, highRegister(op2), op2, highRegister(dest), dest);
}
```

There is no signature ambiguity — the pair forms take 4-6 arguments and the modern forms take 2-3
— with **one exception**: the existing `branchTest64(ResultCondition, RegisterID regHi,
RegisterID regLo)` means "test one value given as a pair", while the modern
`branchTest64(cond, value, mask)` means something entirely different with the same arity. Rename
the old one (`branchTest64Pair`) before anything calls it.

Missing entirely from the deleted backend and needing to be written: `load64`, `store64`,
`move64`, `move(TrustedImm64, RegisterID)`, `neg64`, `not64`, the immediate forms of
`add64`/`sub64`/`and64`/`or64`/`xor64`, `lshift64`/`rshift64`/`urshift64`,
`signExtend32To64`/`zeroExtend32To64`, `moveConditionally64`, `branchAdd64`/`branchSub64`,
`test64`, `patchableBranch64`.

Two implementation notes that cost time to work out:

* `load64` should route through the existing `loadPair32(Address, dest1, dest2)`, which already
  handles base-register aliasing and picks `ldrd` when the offset is a multiple of 4 within
  ±1020. `store64` should route through `storePair32`, which deliberately emits two `str`s — the
  existing comment says "strd does not support unaligned accesses on some chips". See §7.1 before
  changing that.
* `neg64` has no direct sequence, because **Thumb-2 has no `RSC`**. Use
  `mvn hi,hi ; mvn lo,lo ; adds lo,lo,#1 ; adc hi,hi,#0` — four instructions, all with emitters
  the old backend already had.

The disjoint-pair invariant kills most aliasing analysis: two logical registers are either
identical or share no physical register, so the only aliasing case any 64-bit op has to handle is
`src == dest`. Assert it and stop thinking about it.

---

## 6. Operations that cannot be expressed in a bounded, cheap sequence

This is the part worth keeping. Each of these has to be either avoided, routed through a runtime
call, or accepted as slow — none of them can be papered over in the MacroAssembler.

**6.1 64-bit integer division (`div64`, `uDiv64`, and the modulo forms).** Not merely expensive —
absent. ARMv7 as shipped on the A4/A5 (Cortex-A8/A9) has no `SDIV`/`UDIV` at all; those are
ARMv7VE/Cortex-A15 and later. Even *32-bit* division is a libcall on this target. 64-bit division
is `__aeabi_ldivmod`. Unbounded, and a real function call with its own register discipline. The
baseline JIT does not need it (`JITDivGenerator` goes through doubles), so this is only a problem
for B3/Wasm i64 — which is another reason to keep those off.

**6.2 64-bit integer / double conversion.** `convertInt64ToDouble`, `convertUInt64ToDouble`,
`truncateDoubleToInt64`, `truncateDoubleToUint64`. VFP's `VCVT` converts only 32-bit integers.
The 64→double direction needs a normalise-and-round sequence: a `clz`, two `vcvt`s, a `vmla`, and
a rounding fixup, ~15-25 instructions and two FP scratch registers, or a libcall. The deleted
backend's `truncateDoubleToInt64(FPRegisterID src, RegisterID destLo, RegisterID destHi,
FPRegisterID scratch1, FPRegisterID scratch2)` — note it demands **two** FP scratch registers in
its signature — is the shape of the honest answer. Bounded, but must never be on a hot path.
`convertInt32ToDouble` is fine and is what the baseline actually uses.

**6.3 Variable-amount 64-bit shifts.** `lshift64`/`rshift64`/`urshift64` by a *register* amount is
eight instructions and needs **two scratch registers** — which is exactly the number of
MacroAssembler temporaries that exist. So a variable 64-bit shift cannot be composed with an
address computation that also needs a temporary, in the same expression. The sequence for `<<`:

```
  rsb t1, n, #32          ; 32 - n
  lsr t2, srcLo, t1
  lsl destHi, srcHi, n
  orr destHi, destHi, t2
  sub t1, n, #32          ; n - 32
  lsl t2, srcLo, t1
  orr destHi, destHi, t2
  lsl destLo, srcLo, n
```

It is branch-free only because ARM register-amount shifts read the low 8 bits of the shift
register and produce zero for counts ≥ 32. That property is doing all the work; do not "simplify"
it. Constant-amount shifts are 2-3 instructions and are what the baseline actually emits.
`rsb` is not in the deleted backend's emitter set and has to be requested from the encoder.

**6.4 `rotateRight64` by a variable amount.** ~8-10 instructions plus both temporaries. Same
composition problem as 6.3.

**6.5 `countPopulation64`.** ARMv7 has no scalar population count. Either a NEON `VCNT`/`VPADDL`
chain — which means moving the pair into a D register, counting, and moving back, and drags a
NEON dependency into the baseline — or ~15 instructions of bit-twiddling per half.

**6.6 `branchMul64` with overflow detection.** The product itself is fine (`umull` + two `mla`,
four instructions). Detecting overflow requires the discarded upper 64 bits, which is another
`umull`/`mla` chain plus comparisons: ~8-10 instructions and both temporaries. The baseline uses
`branchMul32` for JS integers, so this is only a B3/BigInt concern.

**6.7 64-bit compare-and-swap.** Expressible — `LDREXD`/`STREXD` exist, and in Thumb-2 `Rt`/`Rt2`
are independently encoded so the pair need not be even/consecutive. But the retry loop needs the
expected pair, the new pair, the base, and a status register live simultaneously: **seven of ten
registers**. Any use of `atomicStrongCAS64` in JIT-generated code is effectively a register-file
emergency.

**6.8 — the important one — there is no single-copy atomic 64-bit load or store.**

ARMv7 guarantees `LDRD`/`STRD` are single-copy atomic only on implementations with LPAE. The
Cortex-A8 and A9 do not have it. So every `load64`/`store64` of a JSValue is two independent
32-bit accesses and **can tear**. The existing backend already flinches at this — `storePair32`
avoids `strd` outright, and `transfer64` carries the comment "Warning: not atomic".

The consequences are not confined to the MacroAssembler:

* A concurrent GC marker, or a conservative stack scan, can observe a half-updated JSValue. The
  dangerous direction is a slot whose high word still says "not a cell" while the low word already
  holds a live cell pointer — a missed mark, which collects a reachable object.
* Neither store order is safe in isolation. Low-word-first exposes (old tag, new payload), which
  is the missed-mark case. High-word-first exposes (new tag, old payload), which can present a
  stale int32 payload as a cell pointer.
* JSVALUE32_64 JSC had an explicit store-ordering discipline for exactly this. The JSVALUE64
  engine has none, because it has never needed one — it has always had atomic 64-bit stores.

The likely answer is that Riptide's write barrier saves us: it logs the *owner object* and
re-scans it at the end of marking, so a torn read of a slot inside a barriered object is
tolerable; and conservative stack scanning validates candidate pointers against the heap, so a
torn stack value is at worst a false positive. But that is an argument, not a proof, and it has
to be checked slot class by slot class before the JIT is trustworthy. **This is the deepest
problem in the port and it is not a MacroAssembler problem.** Budget real time for it.

(Alignment, at least, is not an issue: `LDRD` needs word alignment and JSValue slots are 8-byte
aligned everywhere — JS frame slots, inline property storage, butterflies.)

**6.9 Anything wanting a third scratch register.** The backend has exactly two (`r6`, `ip`).
`branchTest64` against a two-word mask, the variable shifts, `mul64` with overlapping operands,
and 64-bit CAS each consume both. Sequences that need a temporary *and* an address computation
have to spill.

**6.10 Not a problem, worth recording:** `VMOV Rlo, Rhi, Dn` moves a whole 64-bit value between a
D register and a GPR pair in **one instruction**. Boxing and unboxing doubles is 2 instructions
each (§4). This is the one place where being a 32-bit machine with a 64-bit FPU actually helps,
and it means the double fast paths are competitive.

---

## 7. Engine-level blockers outside the backend

These are not MacroAssembler work and were not in scope, but they will stop the port dead and
they were discovered while designing the model.

### 7.1 `CCallHelpers` cannot marshal a 64-bit argument

`setupArguments<OperationType>` counts **one register per argument** and has no notion of an
8-byte-aligned register pair, of skipping a register for alignment, or of an argument split
between registers and the stack. `setupArgumentsImpl(..., JSValueRegs arg, ...)` simply forwards
`arg.gpr()` as a single GPR — which on ARMv7 passes half a value in the wrong slot.

The JSVALUE32_64 version of that marshaller existed and had the right shape — the removal patch's
reject files still show the `requires std::same_as<CURRENT_ARGUMENT_TYPE, EncodedJSValue>`
overloads that consumed two registers. It was deleted in `857bd4334690` and has to come back,
alignment rules included. This is a substantial, self-contained piece of work and it is on the
critical path: nothing calls an operation without it.

### 7.2 Some opcodes do not fit in the register file at all

`preferredArgumentJSR<Op, N>()` in `GPRInfo.h` walks the argument registers one per argument. Made
ABI-aware (skip an odd register before a 64-bit argument; consume two per 64-bit argument; extend
the list past r0-r3 into r4/r5/r8/r9 because later arguments are stack-bound anyway), it produces
a concrete verdict, verified by compiling the model standalone:

For `operationPutByValStrictOptimize(JSGlobalObject*, EncodedJSValue base, EncodedJSValue
property, EncodedJSValue value, void*, void*)`:

```
  r0      = globalObject
  r1      = skipped for 64-bit alignment
  r2:r3   = base
  r4:r5   = property
  r8:r9   = value
  ...and there is nothing left for the last two pointer arguments.
```

`GetByVal` and `PutById` with the HandlerIC scratch set are in the same position: three JSValue
operands plus a stub-info pointer plus a profile pointer plus two scratches plus `handlerGPR`
exceeds ten registers.

This is exactly the territory the March 2026 "disable ARMv7 JIT" commit blamed — inline caches —
and it is worth being clear that **it is a register-file problem, not a bug**. The fixes are
architectural: spill an operand around the IC, cut the HandlerIC scratch requirement on ARMv7, or
give the IC a stack-based scratch protocol. Pick one deliberately rather than discovering it
opcode by opcode.

The pair-aware `noOverlap` (§3.3) is what turns this from a debugging exercise into a compile-time
list.

### 7.3 Keep DFG and FTL off

FTL is already forced off on `!CPU(ADDRESS64)`. DFG should be too, and the reverse-applied removal
patch re-enables it on ARMv7 — that has to be undone. Baseline alone is worth roughly 2x over the
interpreter by WebKit's own per-bytecode figures, and both things the March commit blamed
(polymorphic call linking in `Repatch.cpp`, property inline caches in `DFGJITCompiler.cpp`) live
in the optimising tier and in IC territory.

---

## 8. State of the abandoned attempt

Work was done in the `webkit-trunk-jit` worktree (branch `ios6-armv7-jit`) and then stopped
mid-flight. That worktree also contains a **reverse-applied `857bd4334690`**, which restores the
entire JSVALUE32_64 world across ~224 files including `.rej` files from hunks that did not apply.
Note that reverse-apply reintroduces `#if USE(JSVALUE64)` guards around code that must always be
live — and since trunk no longer defines that macro at all, those guards evaluate to false and
delete the code they wrap. If anyone revisits that worktree, that is the first trap.

What was actually written, before the stop:

* `Source/JavaScriptCore/jit/GPRInfo.h` — the model from §3 and §4: `armv7PairedHigh()`,
  pair-aware `JSValueRegs::uses()` and `noOverlap`, the ARMv7 `GPRInfo` block with
  `numberTagRegister`/`notCellMaskRegister` set to `InvalidGPRReg`, `JSRInfo::jsRegT76`, and an
  ABI-aware `preferredArgumentJSR`. The JSVALUE32_64 `JSValueRegs` was removed again.
* No `MacroAssemblerARMv7` work landed. The 64-bit layer described in §5 was designed but not
  written.
* The ARMv7 argument-assignment logic was verified standalone (it compiles and produces the
  §7.2 result); nothing else was compiled, because `ARMv7Assembler.h` does not exist in trunk —
  it is not even in the removal patch, so a new encoder has to be written from scratch. §9
  below is what that would cost.

Originals of both edited files are gone with the scratch directory; `git diff` in that worktree is
the only record.

---

## 9. If the encoder has to be written: 2017 → trunk API deltas

Notes taken while porting `webkit-603/.../ARMv7Assembler.h` (2017 vintage) onto current
trunk in `webkit-trunk-jit`. Superseded for now — `webkitglib/2.54` still ships a working
ARMv7 JIT, so we take that branch instead of writing an encoder. Keep this only in case a
future branch drops ARMv7 as well.

The port did reach the point of compiling: `MacroAssembler.h` (which pulls in both
`ARMv7Assembler.h` and `MacroAssemblerARMv7.h`) built clean for armv7 with zero errors and
zero warnings, as did `MacroAssemblerARMv7.cpp`, `AbstractMacroAssembler.cpp`,
`MacroAssembler.cpp`, `ProbeContext.cpp` and `ProbeStack.cpp`. The file is on branch
`ios6-armv7-jit` if it is ever wanted as a reference.

### Where the contract lives

The authority is not the old assembler — it is what `LinkBuffer.cpp`
(`copyCompactAndLinkCode`), `AbstractMacroAssembler.h` (`Jump::link`, `Call::linkThunk`,
`repatchNearCall`, `flushNearCall`) and the ported `MacroAssemblerARMv7.h` actually call.
`ARM64Assembler.h` in the same tree is the living example to copy shape from. Compiling
`MacroAssembler.h` on its own is a fast, complete check of the whole interface.

### 1. `AssemblerLabel::m_offset` is private

Every `label.m_offset` becomes `label.offset()`. Construction is
`explicit AssemblerLabel(uint32_t)`. Affects `getRelocatedAddress`,
`getDifferenceBetweenLabels`, `getCallReturnOffset`, `linkJump`, `linkCall`,
`linkPointer`, `labelForWatchpoint`, `label`.

### 2. `performJITMemcpy` is templated on a repatching mode

`AssemblerCommon.h` defines `RepatchingFlag { Atomic, Memcpy, Flush }`,
`using RepatchingInfo = WTF::ConstexprOptionSet<RepatchingFlag>`, and the constants
`jitMemcpyRepatch`, `jitMemcpyRepatchAtomic`, `jitMemcpyRepatchFlush`, `memcpyRepatch`,
`memcpyRepatchFlush`, plus `noFlush(RepatchingInfo)`.

Plain `performJITMemcpy(dst, src, n)` is replaced by
`machineCodeCopy<repatch>(dst, src, n)`. This matters for correctness, not just typing:
`LinkBuffer` calls `link<memcpyRepatch>` when writing into a scratch buffer and
`link<jitMemcpyRepatch>` when writing straight into the JIT region. So **every** static
link/patch helper has to become `template<RepatchingInfo repatch>` and thread it through:
`linkJumpT1/T2/T3/T4`, `linkConditionalJumpT4`, `linkBX`, `linkConditionalBX`,
`linkJumpAbsolute`, `setInt32`, `setPointer`.

The `bool flush` trailing parameter of `setInt32`/`setPointer` disappears; the flush is
driven by the flag instead:

    machineCodeCopy<noFlush(repatch)>(...);
    if constexpr ((*repatch).contains(RepatchingFlag::Flush))
        cacheFlush(...);

Public entry points that are also called untemplated take a default:
`template<RepatchingInfo repatch = jitMemcpyRepatchFlush>`.

### 3. `fillNops` is templated, and loses its bool

Old: `fillNops(void*, size_t, bool isCopyingToExecutableMemory)`.
New: `template<RepatchingInfo repatch> static void fillNops(void* base, size_t size)`,
with `static_assert(!(*repatch).contains(RepatchingFlag::Flush))`. `LinkBuffer` calls
both `Assembler::fillNops<memcpyRepatch>` and `<jitMemcpyRepatch>`.

### 4. `LinkRecord` grew three members

`LinkBuffer::copyCompactAndLinkCode` now calls, generically:

- `linkRecord.to(&macroAssembler.m_assembler)` — takes the assembler pointer
- `linkRecord.setFrom(&macroAssembler.m_assembler, writePtr)` — likewise
- `linkRecord.isThunk()`

The assembler argument exists only so ARM64E can diversify a signed `m_to` by the
assembler's address. On ARMv7 both just ignore it (`UNUSED_PARAM`-style). `isThunk()` can
be `static constexpr bool isThunk() { return false; }` — jump islands are ARM64-only, and
`Jump::linkThunk` / `Call::linkThunk` only call `m_assembler.linkJumpThunk` under
`#if CPU(ARM64)`; every other CPU goes through `masm->addLinkTask(...)`. So ARMv7 needs
**no** `linkJumpThunk` / `linkNearCallThunk`.

Also: define both a copy constructor and `operator=` (returning `LinkRecord&`), or clang
warns `-Wdeprecated-copy-with-user-provided-copy` when `std::sort` moves records.

### 5. Near calls are now real `BL`, and tail calls real `B`

This is the biggest behavioural change and the easiest thing to get wrong. The ported
`MacroAssemblerARMv7::linkCall` dispatches three ways:

    if (!call.isFlagSet(Call::Near))
        Assembler::linkPointer(code, call.m_label.labelAtOffset(-2), fn);  // far: MOV/MOVT + BLX
    else if (call.isFlagSet(Call::Tail))
        Assembler::linkTailCall(code, call.m_label, fn);                   // near tail: B (T4)
    else
        Assembler::linkCall(code, call.m_label, fn);                       // near: BL

Consequences:

- `bl()` must exist as an emitter and `linkCall` must relocate a **BL immediate**, not
  patch a MOV/MOVT pointer the way the 2017 `linkCall` did.
- `linkTailCall(void*, AssemblerLabel, void*)` is new and has no ARM64 counterpart to copy.
  It is just `linkJumpT4`, since `nearJumpRange` is 16 MB, comfortably inside B T4 range.
- `AbstractMacroAssembler::repatchNearCall` calls
  `AssemblerType::template relinkCall<repatch>` and `relinkTailCall<repatch>`, while
  `MacroAssemblerARMv7::repatchCall(CodeLocationCall, …)` calls plain `relinkCall(a, b)`
  for the **far** form. One name, two instruction shapes. A default template argument makes
  both call sites compile, but the body has to tell them apart at runtime. The reliable
  discriminator: `from` is always the return address, so look at `from[-1]` — a far call
  ends in `BLX <reg>` (`0x4780 | (Rm << 3)`, mask `0xff87`), whereas the last halfword of a
  `BL` is `>= 0xD000`. No overlap.
- `flushNearCall` wants `flushCall` / `flushTailCall`; `repatchJump` wants `relinkJump`.
  `prepareForAtomicRelinkJumpConcurrently` / `…CallConcurrently` are behind
  `ENABLE(JUMP_ISLANDS)` and are not needed.

### 6. Registers moved out of the assembler header

`ARMv7Registers.h` (which upstream kept, and which comes back cleanly from the removal
patch) owns `FOR_EACH_GP_REGISTER`, `FOR_EACH_REGISTER_ALIAS`, `FOR_EACH_SP_REGISTER`,
`FOR_EACH_FP_SINGLE_REGISTER`, `FOR_EACH_FP_DOUBLE_REGISTER`, `FOR_EACH_FP_QUAD_REGISTER`.
The 2017 header's hand-written `FOR_EACH_CPU_*` macros and enums must be deleted and the
enums generated from those macros instead, exactly as `ARM64Assembler.h` does, inside
`namespace RegisterNames` (`ARMv7Registers.h` does `#define RegisterNames ARMRegisters`).

Required because `RegisterInfo.h`, `RegisterSet.cpp` and `ProbeContext.h` consume the same
macros. `ProbeContext.h` additionally needs `gprName` / `sprName` / `fprName` returning
`ASCIILiteral`, and therefore a real `SPRegisterID` enum (`apsr`, `fpscr`) plus
`firstSPRegister()` / `lastSPRegister()` / `numberOfSPRegisters()` — none of which the
2017 file had.

Two more register-level gaps the ported `MacroAssemblerARMv7.h` depends on:
`ARMRegisters::asSingleUpper(FPDoubleRegisterID)` (the high half of a double as a single,
i.e. `(reg << 1) + 1`), and — because `CPU(ARM_NEON)` is on for armv7 iOS — a
`FPDoubleRegisterID` enum running to `d31`, so `lastFPRegister()` has to be conditional.

Note that the enums are now `enum : int8_t`, which makes `op | reg` an enum-enum operation
and trips `-Wdeprecated-enum-enum-conversion` in the instruction formatter. Cast the
register to `int` at those three sites.

### 7. Smaller renames

- `UNLIKELY(x)` is gone → `if (x) [[unlikely]]`.
- `bitwise_cast` → `std::bit_cast`.
- `COMPILE_ASSERT` → `static_assert`.
- `WTF::bitCount` → `std::popcount` (needs `<bit>`).
- `cacheFlush` on Darwin: `sys_icache_invalidate(code, size)` (per `ARM64Assembler.h`),
  not the 2017 `sys_cache_control(kCacheFunctionPrepareForExecution, …)`. Needs
  `<libkern/OSCacheControl.h>`.
- Include style is `<JavaScriptCore/Foo.h>`, not `"Foo.h"`.
- `buffer()` accessor is required (`LinkBuffer` calls
  `m_assembler.buffer().releaseAssemblerData()`); mark it `LIFETIME_BOUND`, as should
  `jumpsToLink()`.
- `replaceWithNops(void*, size_t)` is new (non-templated), and `invert(Condition)` and
  `isBkpt(const void*)` are called by `MacroAssemblerARMv7.h` but absent from 2017.
- `ENABLE(BRANCH_COMPACTION)` is on, so the `copyCompactAndLinkCode<uint16_t>` path — and
  hence `canCompact` / `computeJumpType` / `jumpSizeDelta` / `link` — is live.

### 8. Instruction-set gap, if this is ever redone

A static comparison of what `MacroAssemblerARMv7` calls against what the 2017 file provides
found ~33 missing `m_assembler.X()` emitters. Beyond the obvious ones, three are easy to
miss because the name exists but the needed overload does not:

- `adc(rd, rn, rm)` — 2017 has only the immediate form; the register form (`0xEB40`) is
  needed for `add64`.
- `ldrsb` / `ldrsh` with an `ARMThumbImmediate` or an `(offset, index, wback)` triple —
  2017 has only the register-offset forms.
- the whole single-precision family (`vadd`, `vsub`, `vmul`, `vdiv`, `vsqrt`, `vabs`,
  `vneg`, `vcmp`, `vcmpz`, and the `vcvt` float-source variants), which is the same
  encoding with the `sz` bit clear.

Two encodings needed genuinely new machinery rather than a new opcode constant:

- `vand` / `vorr` are **Advanced SIMD**, not VFP — VFP has no bitwise ops. They need their
  own formatter, because the existing `vfpOp` puts `size` at bit 8 of the second halfword,
  which for SIMD three-registers-same-length is part of the opcode. The D/N/M register
  extension bits also attach to Vd/Vn/Vm respectively, unlike `vfpOp`'s layout.
- `vldmia` / `vstmia` need a load/store-multiple formatter (`imm8` is *twice* the number of
  doubleword registers).

And one trap worth writing down: `LDREX` and `LDRD (immediate)` share the first-halfword
base `0xE850`. They are distinguished by P:W — `P == 0 && W == 0` is the exclusive-access
encoding space, so `ldrd` must assert `index || wback`.

### 9. One bug found in the ported MacroAssembler (not fixed here)

`MacroAssemblerARMv7.h`, in `absoluteAddressWithinShortOffset`:

    return reinterpret_cast<int32_t>(addressDelta);   // addressDelta is intptr_t

`reinterpret_cast` between two integer types is ill-formed; it must be `static_cast`. This
was the only error left in the whole assembler directory once the encoder was in place.
Whoever owns `MacroAssemblerARMv7.h` should make that change — it is presumably present in
the `webkitglib/2.54` copy too, or was introduced when the file was extracted from the
removal patch, and is worth checking either way.
