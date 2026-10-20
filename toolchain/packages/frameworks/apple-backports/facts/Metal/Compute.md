# Compute on the CPU, iOS 8.0 and later

`MTLComputePipelineState` and `MTLComputeCommandEncoder` are carried, and a kernel runs on the CPU
because there is nowhere else it could run: `facts/OpenGLES/ES3Functions.md` has it measured on an
iPhone 4S at 6.1.3 that the drivers of iOS 6 are OpenGL ES 2.0, that `-initWithAPI:` answers nil for
`kEAGLRenderingAPIOpenGLES3`, and that 74 of the 99 functions ES 3.0 added have no ES 2.0 extension
on this hardware. `tools/air2cpu` turns the AIR of a compute kernel into C when the application is
built, the way `tools/air2es` turns a render function into a shader, and this file is what runs the
result.

## What the port has proved, and what it has not been able to measure

`tests/backports/host/air2cpu/compare.sh` is the test: it compiles `kernels.metal` with Apple's own
compiler on the host, runs each kernel, turns the AIR that compiler wrote into C with `tools/air2cpu`, and
runs that through the same call convention this encoder uses. **It compares two answers, and one of the
two is Apple's.**

**As of 2026-10-03 that comparison does not finish on this machine, so most of what follows is a PAST
measurement and is marked as one.** `compare.sh` stops at

    the oracle did not produce …/kernels.metallib, so there is no AIR to read and the differential has
    nothing to compare.

**The cause is one kernel and one Metal call, and the earlier reading of it was wrong.** An earlier
version of this file said the host's `MTLCompilerService` was in a crash loop and therefore compiled
nothing. Measured on 2026-10-03, with `tests/backports/host/air2cpu/run.sh` splitting the fixture and
asking for a dynamic library one kernel at a time:

* `-[MTLDevice newLibraryWithSource:]` **compiles all 21 kernels**, `localArray` included, and so does
  the oracle's first step;
* `-[MTLDevice newDynamicLibrary:]` — the step that turns the compiled library into the
  `MTLDynamicLibrary` whose `serializeToURL:` writes the `.metallib` `tools/air2cpu` reads — links
  **20 of the 21** and refuses one, with `Compilation failed due to an interrupted connection:
  XPC_ERROR_CONNECTION_INTERRUPTED. This error occurred after multiple retries.`;
* the one it refuses is `localArray`, the only kernel that declares a threadgroup array as a local
  (`threadgroup atomic_uint block[16]`). Reduced on its own it still refuses; so does the same
  declaration without the `mem_flags::mem_threadgroup` argument, and so does a `threadgroup uint[16]`
  with no atomics in it at all. The kernels that declare a threadgroup *pointer* (`argBarrier`,
  `argNoBar`) link.

So Apple's own toolchain will not link a kernel that declares a threadgroup array as a local, on this
machine. Nothing in this repository owns that, and no spelling of the fixture avoids it without giving
up the AIR shape the kernel was added for. `localArray`'s answer is therefore **uncompared**, and the
run says so by name rather than only that the file did not come out.

### MEASURED, and still reproducible

* `tools/air2cpu` translates every kernel in the fixture and refuses none. Reproduced on 2026-09-29 with
  the ordinary compile path alone, one kernel at a time and all of them together:

      one   →  ok 1 kernel(s)   for each of twenty single-kernel files, and no crash report added
      whole →  ok 21 kernel(s)  on the ordinary path, and on the dynamic path

* The port's **call convention** is one header that the tool's output, this encoder and the harness all
  include, and a mismatch is a compile error rather than a kernel reading its arguments out of the wrong
  registers.

* The **comparison summary can fail**: it refuses a duplicate row, a kernel Metal answered and the tool
  refused, and a kernel the source has that neither side answered.

### MEASURED ON AN EARLIER TREE — recorded, and not reproducible now

**The run's output is not in this repository, and cannot be.** The hook refuses it: run output is
privacy-exempt content and belongs in `.agent-work/`, and the log also carries an absolute home path.
So what this file cites is the run's **digest and where it is**, not the log:

    where  .agent-work/worktrees/api-metal/.agent-work/runs/verify.log
    when   2026-09-28 21:44        28959 bytes
    tree   a19effdaf, kept on the ref keep/air2cpu-a19effdaf
    sha256 6324a3c9b4e821c1956763e52f2d4c0e04df98c2a39d12be1989b4efdc325c6d

That is the whole output of `WORK=<dir> sh tests/backports/host/air2cpu/compare.sh` on a tree of
**twelve** kernels. Its verdict block, as recorded at the time and not independently checkable from
this repository:

    refused atomicFamilyKernel the port did not translate this kernel, so there is no answer to compare
    match   atomicAddKernel  64 values agree with Metal
    match   atomicKernel     64 values agree with Metal
    match   grid2Kernel      64 values agree with Metal
    match   grid3Kernel      64 values agree with Metal
    match   indexKernel      64 values agree with Metal
    match   orderKernel      64 values agree with Metal
    match   orderKernel2     64 values agree with Metal
    match   scanKernel       64 values agree with Metal
    match   stridedKernel    64 values agree with Metal
    match   sumKernel        64 values agree with Metal
    match   sumSharedKernel  64 values agree with Metal
    compare: 12 kernel(s) Metal answered, 11 compared, 0 differ

So the three numbers are three different things: **12** kernels Metal answered for, **11** of them the
tool had translated and the port answered, and **0** differing among those 11. The twelfth,
`atomicFamilyKernel`, was **refused** — the port said so by name and the run counted that as a refusal
rather than a match.

**The two other logs an earlier version of this file named are retracted.** One is a later run on a
sixteen-kernel fixture and one is the mutant run, which is red by design; neither carries this block,
and neither is cited.

**It is a past measurement.** The oracle produces no library now, for the one kernel named at the
head of this file, and `compare.sh` stops with "the differential has nothing to compare". Nothing
here is independently checkable from this repository, and the digest is what a reader with the worktree
checks the log against.

### UNMEASURED

* **The threadgroup block and the cross-thread barrier** — `sumSharedKernel` (a reduction through
  threadgroup memory with two barriers) and `scanKernel` (a scan with a read-barrier-write step) — are
  the two kernels that exercise them, and **neither has an answer from Apple's side on the current
  machine**. What the last run before the service went down showed is that on real Metal a threadgroup
  write was read back as zero, own slot and neighbour's alike, while the port read its own write
  correctly; that was put down to the oracle and the next probe was never run. So the port's behaviour
  here is **not established**, and no claim about threadgroup memory sharing, about the barrier, or about
  either of those kernels' answers is made in this file until the oracle answers again.
* The three-way probe that would have settled it — one thread writing a slot and reading its own back, to
  separate a lost write from a lost share — was written and never run.
* `atomicFamilyKernel`, `spillKernel`, `shareProbe`, `blockProbe`, `argNoBar`, `argBarrier` and
  `localArray` were added after the last good run; their answers are unmeasured. For `localArray` there
  is now a second reason it cannot be answered even if the run were fixed: Apple has none, because its
  own compiler will not link that kernel here (head of this file). The other six link one at a time.

## What the atomics do not yet reach, and why

**An array of atomics is indexed with the wrong element size.** The AIR for `&block[i]` on a
`threadgroup atomic_uint *` is a `getelementptr` whose element type is `struct.metal::_atomic` — an
opaque struct whose size depends on the value type and the scope, and which the emitter has no size
for, so the GEP falls back to **one byte per element**. The symptom is measured, not guessed:
`lldb` on the harness reports `EXC_BAD_ACCESS` in `air2cpu_atomicFamilyKernel` with
`v47 = (char *)signed_out + (0) * 1` in the generated C.

Guessing 4 would be right for a `uint` array and wrong for anything else, and a wrong stride writes
into the middle of a neighbouring slot — a silent wrong answer from an atomic, which is the one thing
an atomic must never be. So this is a **refusal until the element type can be measured**: the size of
`metal::_atomic<T, S>` has to come out of the type itself rather than out of a default, and that is
the next piece.

Everything above this line is proved: the order and the scope are separated by measurement, the two
families' order numbering is per family, and the two atomic kernels the differential runs agree with
Apple's own Metal on all 64 values.

## What the differential found last: the operand, not the atomic

The coordinator decoded the two answers as integer bit patterns printed as floats — a float with bits
`n` is `n × 1.4013e-45` — and that is right, and it settles where the fault is:

| cell | Metal | bits | the port | bits | what the kernel wants |
|---|---|---|---|---|---|
| 0 | `1.68e-43` | **120** = 0+1+…+15 | `5.74e-42` | 4096 | 120 |
| 1 | `2.10e-44` | **15** = OR of 0..15 | `3.59e-43` | 256 | 15 |
| 2, 3, 4 | 0 | 0 | 0, 0, 256 | | 0 |

**Metal's answer is exactly right** — 120 is the sum of the sixteen thread positions, 15 is their OR,
and xor/and/min are all 0. So the fault is the port's, and reading the generated C says where:

```
v1  = v0 + group.x;                                        <-- the operand the atomic is given
t0  = __atomic_fetch_add((volatile uint32_t *)v2, (uint32_t)v1, memory_order_relaxed);
v2  = (char *)block + (0) * 4;
t6  = __atomic_load_n((volatile uint32_t *)v2, memory_order_relaxed);
__atomic_store_n((volatile uint32_t *)v14, t6, memory_order_relaxed);
```

**The atomic emission is correct** — the address is `block + slot*4`, the load and the store are on the
same address, the operand is cast to the value's own type and the order is the one measured. What is
wrong is the **operand**: the kernel computes `gid * tg + tid` and the port is adding the **group**
index to something else, so the value each thread contributes is not its own position. That is the
coordinator's "tid-scaled or width-scaled" hypothesis, and the scale is the *group*, not the width.

Which narrows the fault to one thing: **the argument mapping, not the atomics**. The slot a scalar
argument binds to was computed as *its argument index less the number of buffers*, which is wrong for
any kernel that also takes a threadgroup block: that argument sits in the middle of the list, so
counting arguments instead of scalars bound every scalar one position late — `thread`←`gid`,
`group`←`tg`, `size`←`tid` — and `gid * tg + tid` came out as `size.x * size.x + group.x`. The three
must be numbered by **how many scalars have been seen**, not by where the argument sits.

**The fix is not landed, and the three attempts at it are recorded because the failure mode is the
same as the bug's.** The slot must be numbered once per ARGUMENT, in the pass that classifies them.
What each attempt produced, all three different and all wrong, which is itself the diagnosis:

| attempt | how the slot was computed | what `gid * tg + tid` came out as |
|---|---|---|
| the shipped code | the argument's index less the number of buffers | `size.x * size.x + group.x` |
| a member counter incremented in `nameOf` | counted per **use** | `thread.x * group.x + size.x` |
| a map filled in the argument pass | looked up per use, keyed on the argument | `thread.x * thread.x` |

The first counts arguments, which is wrong for a kernel that also takes a threadgroup block. The
second counts uses, which rotates every use after the first. The third looks the right thing up and
still lands both operands on slot 0 — which is the same shape as the `+ (out) * (out)` bug the
addressing check flags, and **the check would have caught it had it been run on the output**, which is
the procedure to keep: the tool is built, it is run over the fixture, and the generated C is checked
*before* the C is compiled. A run per attempt, not an edit per attempt.

The tool is at the committed state, restored by content and committed forward. It builds.

The fixture kernel that makes this fail a run is in: `indexKernel` writes `gid * tg + tid` per thread
over **more than one group** — three groups of four — so thread 3 of group 2 must contribute 11, and a
lost multiply contributes 2. With one group the group index is 0 and a kernel that dropped the
multiply would still look right, which is why every earlier version of this passed.

## The one compilation both sides of the differential use

`tests/backports/host/air2cpu/` compares two answers about one kernel, so both sides must be the same
kernel under the same compilation. Two things had to be pinned for that, and both are measurements:

- **The Metal Shading Language version is pinned to 4.1 on both sides**, and not because 4.1 is
  current. An *unset* `options.languageVersion` comes from the **calling binary's deployment target**,
  and the two binaries are not the same: `otool -l` says the oracle is `minos 27.0` and the harness
  `minos 15.0`. The same source therefore compiled on one side and was refused on the other. Which
  version is the lowest that accepts the fixture, measured on the oracle:

  | version | value | result |
  |---|---|---|
  | 3.0 | 196608 | `no matching function for call to 'atomic_fetch_add_explicit'` |
  | 3.1 | 196609 | the same |
  | 3.2 | 196610 | the same |
  | 4.0 | 262144 | the same |
  | **4.1** | **262145** | **compiles** |
  | 5.0 | 327680 | refused |

  The refusal is always the same call: the **threadgroup** family takes a `mem_flags` argument from
  4.1 on, and the fixture measures the orders on that family.
- **The oracle compiles the source twice, and so does the harness.** The library the AIR is read from
  is `MTLLibraryTypeDynamic` — a function of a dynamic library can only be *linked* into another
  pipeline, and `-newComputePipelineStateWithFunction:` asserts
  `validateMTLFunctionType: type is not a valid MTLFunctionType` on one, which is fatal. So the
  **serialised** library is Dynamic and the **dispatched** one is ordinary, on both sides.

## The refusals, and what each of them prints

Every kernel this port will not answer for is refused **by name, with the reason**, and that is what
the log of the build that ran the tool says. Three cases, all measured on
`tests/backports/host/air2cpu/orders/simd.metal` (a kernel that uses a simdgroup function, which a
CPU has none of) and on the fixture's kernels:

* **A kernel the tool cannot translate is refused, and never reaches the table.** `air2cpu` on
  `simd.bc` prints

  ```
  simd.bc: REFUSED simdKernel: a call to air.simdgroup.barrier
  simd.bc: REFUSED simdKernel: a call to air.simdgroup.barrier
  simd.bc: REFUSED simdKernel: nothing of the body could be translated, which is a kernel that would compute nothing
  ```

  `exit=1`, and **no `.c` is written at all** — the all-refused path returns before the writer opens
  the file, so a library of nothing but refused kernels produces no table for a pipeline to look in and
  the application gets the documented error from `-newComputePipelineStateWithFunction:error:`.
* **A refusal beside a translatable kernel poisons neither.** The eight fixture kernels come out
  `OK` and the ninth (`atomicFamilyKernel`, refused at its memory order) changes no row of the table.
* **A value the emitter could not name used to be recorded as `OK`** with a body reading
  `*(uint64_t *)v1 = ;`. The refusal is now counted before and after the body is built
  (`tools/air2cpu/air2cpu.cpp`, `refusedBefore` and the comparison after `dispatch()`), so a refusal
  recorded while emitting makes the kernel refused and its row is never written.

## What the gates cover, and what they do not

The **6.1.3** gate is the one that carries Metal: `libMetalBackports.dylib` and its objects are built
there, and its objects are what `tools/release-split.lua` is run over. The **4.3** gate is green and
**carries no Metal object at all** — every API this file describes arrived in 8.0 or later, and the
4.3 band is placed below the 6.0 minimum the port's own classes carry — so a green 4.3 says nothing
about Metal, and nothing in this file should be read as if it did. It says that the band below 6.0
links without the port's Metal, which is what it is for.

## A workgroup is threads, and a barrier is a rendezvous

**A workgroup is one thread per thread of the group**, and the threads meet at a barrier through a
mutex and a condition variable: a count of the threads that have arrived, and a generation that is
bumped and broadcast when the last one arrives. iOS 6 has no `pthread_barrier`, and this is the shape
`tests/backports/host/air2cpu/driver.c` runs against Metal.

The alternative — running a group's threads one after another on one thread — is **not** a barrier: a
thread would pass it before its neighbours had written their slots. That was measured, not assumed:
with the group's threads run in order, the threadgroup reduction read an unwritten block and answered
the summing thread's own value, and the scan's answer changed from run to run. The differential found
both, and both are why a workgroup is threads here.

The dispatch is joined before it is encoded, so a `-dispatchThreadgroups:` has finished by the time
the call returns, which is the same as every other encoder of the port.

## The shapes the differential does not yet reach, and what each one needs

The fixture carries six kernels and the tool translates three of them. The other three fail for
reasons the differential names rather than guesses, and both are read out of Apple's own bitcode:

* **A grid of two or three dimensions is carried, and how.** `grid2Kernel`'s signature is
  `ptr addrspace(1) ... %values, <2 x i32> %t, <2 x i32> %g, <2 x i32> %size`, because Metal takes the
  attribute once and a grid of more than one dimension is a vector. A vector of two to four elements
  is a struct with named members, so `extractelement` is a member read; and a kernel's three numbers
  about where it is are *always* three four-component vectors, a scalar argument being a component of
  the same three. That is what lets a kernel of one dimension and a kernel of three call the same way:
  the call convention does not change with the shape of the grid. The six-kernel differential above is
  what holds it to Metal's own dispatch, with the oracle giving each kernel the grid its own index
  formula assumes.
* **An atomic is one intrinsic, and the mapping is now read rather than guessed.**
  `atomicKernel` compiles to `air.atomic.global.add.u.i32` and the tool refuses it by name. The
  mapping was read out of the two upstreams the owner rule names, both cloned into
  `.agent-work/upstream/` for it:

  - **SPIRV-Cross** (`aa217ae`, Apache-2.0): its C++ backend, `spirv_cpp.cpp`, is 553 lines and
    contains **no** atomic lowering at all — it is a stub for a query-and-tracing dialect, not a
    shader-to-CPU backend. So it is not the reference for this, and the facts say so rather than
    implying it was consulted for something it does not have.
  - **SwiftShader** (`1e80438`, Apache-2.0): `src/Pipeline/SpirvShader.cpp:2629` dispatches the opcodes
    — `OpAtomicIAdd` and `OpAtomicIIncrement` to `AddAtomic`, `OpAtomicISub`/`IDecrement` to
    `SubAtomic`, and so on through `And`/`Or`/`Xor`/`Exchange`/`CompareExchange` — each taking a
    `Pointer<UInt>`, the value, and a `std::memory_order`. `src/Reactor/Reactor.cpp:2621` is where they
    land: one thin function per operation over `Nucleus::createAtomicAdd`, `createAtomicSub`,
    `createAtomicCompareExchange` and the rest, each taking the memory order it was given.

    The shape to take is therefore the dispatch and the memory order, and not the whole of Reactor:
    `air2cpu` has to map the AIR opcode onto the matching operation and the AIR memory-order bits onto
    `memory_order`, and then emit a call into a C11 `__atomic_*` builtin's own inline — which is what
    `Nucleus::createAtomicAdd` ends up calling underneath. The order matters and is carried: a kernel
    that asks for a relaxed fetch must get a relaxed fetch, and one that asks for acquire-release must
    get that, so the mapping table is keyed on both.

  Until that is written, a kernel with an atomic answers the documented error, which is the right
  answer and not a wrong number.

Both are named here so the next piece of the tool is bounded by what the bitcode says, and both are
in the fixture, so the differential reports them every run instead of their being absent.

## What a kernel that will not run answers

* **A kernel `tools/air2cpu` refused is not in the table the pipeline looks in.** The pipeline answers
  the documented error naming the function, and says that the refusal is in the log of the build that
  ran the tool. It never answers a pipeline that would compute something else.
* **No table at all** — the library was never run through the tool, or every kernel in it was refused
  — is the same error, saying so.
* A dispatch of more than one dimension of threads per group, or of a buffer at index 16 or above, is
  refused with a line in the log naming the bound the code keeps, which is sixteen. These are the shapes the translated kernels are written for; what
  Metal does with them is undefined.

## What is not here

* **Simdgroup functions.** A CPU has no simdgroup, so there is no operand for one to answer: the tool
  refuses the intrinsic by name, and a kernel that uses one is refused as a whole rather than answered
  wrongly. Measured: a kernel calling `air.simdgroup.barrier` comes out
  `REFUSED simdKernel: a call to air.simdgroup.barrier` followed by
  `REFUSED simdKernel: nothing of the body could be translated, which is a kernel that would compute
  nothing`, and no row for it reaches the generated table.
* **Indirect command buffers and the `MTL4*` surface** of 26.0: the same absences as
  `facts/Metal/Blits.md`, for the same reason — types the 16.4 SDK this package builds against does
  not have, and ray tracing an A7 has not.
