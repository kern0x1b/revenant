// The kernels the differential runs on both sides: Apple's compiler turns these into the AIR with the
// real air.kernel metadata that tools/air2cpu reads, and the host GPU runs them so their answers are
// Apple's rather than ours.
#include <metal_stdlib>
using namespace metal;

// Each thread adds a stride of four values and writes its sum, so the buffer's tail holds one sum per
// work-item. Simple enough to be translated, complete enough to use the thread position and a buffer.
kernel void sumKernel(device float *values [[buffer(0)]],
                      uint tid [[thread_position_in_grid]],
                      uint gid [[threadgroup_position_in_grid]],
                      uint tg [[threads_per_threadgroup]])
{
    uint base = (gid * tg + tid) * 4;
    float s = 0.0f;
    for (uint i = 0; i < 4; i++)
        s += values[base + i];
    values[base] = s;
}

// The same sum through threadgroup memory: every thread puts its own value in the group's block, the
// group is held at a barrier, and the last thread adds the block up. This is the case that needs
// air.threadgroup and air.threadgroup_memory_barrier.
kernel void sumSharedKernel(device float *values [[buffer(0)]],
                            uint tid [[thread_position_in_grid]],
                            uint gid [[threadgroup_position_in_grid]],
                            uint tg [[threads_per_threadgroup]],
                            threadgroup float *block [[threadgroup(0)]])
{
    uint base = (gid * tg + tid) * 4;
    float s = 0.0f;
    for (uint i = 0; i < 4; i++)
        s += values[base + i];
    block[tid] = s;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (tid == 0) {
        float total = 0.0f;
        for (uint i = 0; i < tg; i++)
            total += block[i];
        values[base] = total;
    }
}

// A prefix sum inside one workgroup, in threadgroup memory, in the shape that has one answer: every
// thread reads its neighbour's slot into a register, the group is held at a barrier, and only then does
// anyone write. The first version read the neighbour and wrote its own slot with nothing between them,
// which is a kernel with no defined answer - Metal gave one interleaving, the port's threads gave
// others, and both were right. That was the fixture's fault and it is fixed here rather than argued
// about; the same kernel with the read hoisted above the barrier has to agree on both sides.
kernel void scanKernel(device float *values [[buffer(0)]],
                       uint tid [[thread_position_in_grid]],
                       uint gid [[threadgroup_position_in_grid]],
                       uint tg [[threads_per_threadgroup]],
                       threadgroup float *block [[threadgroup(0)]])
{
    uint base = gid * tg + tid;
    block[tid] = values[base];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    // the read is into a register, and the barrier is after it
    float mine = block[tid];
    float neighbour = tid > 0 ? block[tid - 1] : 0.0f;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (tid > 0)
        block[tid] = mine + neighbour;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    values[base] = block[tid];
}

// The three shapes the differential had not reached: a grid of more than one dimension, an atomic, and
// a threadgroup block written by every thread and read back by the last.

// A 2-D grid: each thread owns one cell, and the two dimensions come in as their own arguments.
kernel void grid2Kernel(device float *values [[buffer(0)]],
                        uint2 t [[thread_position_in_grid]],
                        uint2 g [[threadgroup_position_in_grid]],
                        uint2 size [[threads_per_threadgroup]])
{
    uint index = (g.x * 8 + g.y) * size.x + t.x;
    values[index] = (float)(index + 1) * 2.0f;
}

// A 3-D grid, the same kernel over three dimensions.
kernel void grid3Kernel(device float *values [[buffer(0)]],
                        uint3 t [[thread_position_in_grid]],
                        uint3 g [[threadgroup_position_in_grid]],
                        uint3 size [[threads_per_threadgroup]])
{
    uint index = (g.z * 4 + g.y) * size.x + g.x * 8 + t.z;
    values[index] = (float)(index + 1) * 3.0f;
}

// An atomic: every thread of a group adds its own value to one cell, and the answer is the number of
// threads in it. A kernel that races on a plain read-modify-write answers one interleaving; this one
// has to answer 16 whatever the interleaving.
kernel void atomicKernel(device atomic_uint *counters [[buffer(0)]],
                         uint tid [[thread_position_in_grid]],
                         uint gid [[threadgroup_position_in_grid]],
                         uint tg [[threads_per_threadgroup]])
{
    atomic_fetch_add_explicit(&counters[gid], 1u, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);
}

// The comparison table, which nothing else reaches: the other kernels only ever emit == and !=, so a
// wrong ordering operator would pass every one of them. This one is built on > and >= in the same
// expression, and the seed it is given makes the two differ for half the threads, so a table that maps
// one onto the other shows up in a single element of the answer.
kernel void orderKernel(device float *values [[buffer(0)]],
                        uint tid [[thread_position_in_grid]],
                        uint gid [[threadgroup_position_in_grid]],
                        uint tg [[threads_per_threadgroup]])
{
    // Each thread reads a PAIR of its own and writes the first of it, so no thread reads an element
    // another is writing: the first version read values[tid + 1] while its neighbour wrote values[tid],
    // which is a race with no defined answer, and the port's sixteen real threads lose it more often
    // than Metal's own dispatch does. The seed of 1, 1, 2, 2 ... still makes > and >= differ for half
    // of the pairs, which is what the kernel is here for.
    float a = values[tid * 2];
    float b = values[tid * 2 + 1];
    values[tid * 2] = (a > b) ? 1.0f : ((a >= b) ? 2.0f : 3.0f);
}

// The atomics, the way MPS uses them. Every thread of a group adds its own value to one cell of a
// device buffer, so the answer is the number of threads that got there however they interleave, and a
// plain read-modify-write would be a kernel with no defined answer. The rest of the family is in the
// same kernel so that one differential run covers all of it.
kernel void atomicAddKernel(device atomic_uint *counters [[buffer(0)]],
                            uint tid [[thread_position_in_grid]],
                            uint gid [[threadgroup_position_in_grid]],
                            uint tg [[threads_per_threadgroup]])
{
    atomic_fetch_add_explicit(&counters[gid], 1u, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);
}

// The whole family, in threadgroup memory, where a wrong order or a wrong operator shows up in the
// answer and not only in a count.
kernel void atomicFamilyKernel(device atomic_uint *out [[buffer(0)]],
                               device atomic_int *signed_out [[buffer(1)]],
                               uint tid [[thread_position_in_grid]],
                               uint gid [[threadgroup_position_in_grid]],
                               uint tg [[threads_per_threadgroup]],
                               threadgroup atomic_uint *block [[threadgroup(16)]])
{
    // WITHIN METAL'S LIMIT, which is 30 slots: "'threadgroup' attribute parameter is out of bounds:
    // must be between 0 and 30". So this kernel is a group of EIGHT with TWO slots per thread - one
    // unsigned, one signed - which is 16, and every slot is a thread's own, so every value a thread
    // contributes is a number this test can name and the sums are over eight known values.
    //
    //   slots 0..7    the unsigned family, one per thread
    //   slots 8..15   the signed family, one per thread
    //
    // The previous version indexed to slot 143 and declared 160, which is not a kernel Metal can
    // express: it compiled only because the metallib under test predated the change. AddressSanitizer
    // found the overflow, and the language found the declaration.
    uint base = gid * tg + tid;

    // every operation of the family, on the thread's own unsigned slot
    atomic_fetch_add_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_sub_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_max_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_min_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_or_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_xor_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_and_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    uint exchanged = atomic_exchange_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // the compare-exchange on its OWN slot, seeded with a known value, with the expected value RIGHT
    // for an EVEN thread - which SUCCEEDS - and deliberately wrong for an ODD one - which FAILS. Both
    // answers are read out, so both cases are exercised and neither is undefined.
    atomic_store_explicit(&block[8 + tid], 7u, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint expected = (tid % 2 == 0) ? 7u : 999u;
    bool ok = atomic_compare_exchange_weak(&block[8 + tid], &expected, base + 1);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // and the signed family, on the signed slot
    int sbase = (int)base;
    atomic_fetch_add_explicit(&block[8 + tid], sbase, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_min_explicit(&block[8 + tid], -sbase - 1, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_max_explicit(&block[8 + tid], sbase, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    atomic_store_explicit(&out[base], atomic_load_explicit(&block[tid], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
    atomic_store_explicit(&out[8 + base], ok ? 1u : 0u, memory_order_relaxed);
    atomic_store_explicit(&out[16 + base], exchanged, memory_order_relaxed);
    atomic_store_explicit(&out[24 + base], ok ? atomic_load_explicit(&block[8 + tid], memory_order_relaxed, mem_flags::mem_threadgroup) : 0u, memory_order_relaxed);
    atomic_store_explicit(&signed_out[base], atomic_load_explicit(&block[8 + tid], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
}

// Every order Metal's language allows on a threadgroup atomic - the threadgroup family is the one that
// takes a mem_flags argument, and so the one that can carry more than relaxed - and the same five on a
// device atomic, which the language allows only relaxed. The port's table maps Metal's own enumeration
// onto the C11 orders, and this is what holds it to them: a table with 4 and 5 the wrong way round gives
// acq_rel where seq_cst was asked for, and the order of the sums in the answer says so.
kernel void orderKernel2(device atomic_uint *out [[buffer(0)]],
                         threadgroup atomic_uint *block [[threadgroup(0)]],
                         uint tid [[thread_position_in_grid]],
                         uint gid [[threadgroup_position_in_grid]],
                         uint tg [[threads_per_threadgroup]])
{
    uint base = gid * tg + tid;
    atomic_fetch_add_explicit(&block[0], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_or_explicit(&block[1], base, memory_order_acquire, mem_flags::mem_threadgroup);
    atomic_fetch_xor_explicit(&block[2], base, memory_order_release, mem_flags::mem_threadgroup);
    atomic_fetch_and_explicit(&block[3], base, memory_order_acq_rel, mem_flags::mem_threadgroup);
    atomic_fetch_min_explicit(&block[4], base, memory_order_seq_cst, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    atomic_store_explicit(&out[0], atomic_load_explicit(&block[0], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
    atomic_store_explicit(&out[1], atomic_load_explicit(&block[1], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
    atomic_store_explicit(&out[2], atomic_load_explicit(&block[2], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
    atomic_store_explicit(&out[3], atomic_load_explicit(&block[3], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
    atomic_store_explicit(&out[4], atomic_load_explicit(&block[4], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
}

// The regression sentinel, and the reason it is a kernel and not a comment: an array indexed by a
// constant OFFSET, where every element must come out at base + n*4. The tool's GEP bug made all of
// them land on element zero, and this kernel's answer is that in the differential: if the generated C
// addresses block[0..7] at + 0*4 .. + 7*4 the sums come out 0, 36, 100, 196, 324, 484, 676, 900, and
// any of them aliased onto another changes the whole row. A comment about the bug does not fail a
// run; this does.
kernel void stridedKernel(device atomic_uint *out [[buffer(0)]],
                          threadgroup atomic_uint *block [[threadgroup(0)]],
                          uint tid [[thread_position_in_grid]],
                          uint gid [[threadgroup_position_in_grid]],
                          uint tg [[threads_per_threadgroup]])
{
    for (uint slot = 0; slot < 8; slot++)
        atomic_store_explicit(&block[slot], slot * slot, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (tid == 0)
        for (uint slot = 0; slot < 8; slot++)
            atomic_store_explicit(&out[slot], (float)atomic_load_explicit(&block[slot], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
}

// gid * tg + tid, per thread, over MORE THAN ONE GROUP, so that a lost multiply fails a run. With one
// group the group index is 0 and `gid * tg` is 0, so a kernel that dropped the multiply would still
// look right; over three groups of four it cannot, because thread 3 of group 2 must contribute 11 and
// a lost multiply contributes 2. Each thread writes its own base into the output, so the row IS the
// expression the kernel computes.
kernel void indexKernel(device uint *out [[buffer(0)]],
                        uint tid [[thread_position_in_grid]],
                        uint gid [[threadgroup_position_in_grid]],
                        uint tg [[threads_per_threadgroup]])
{
    out[gid * tg + tid] = gid * tg + tid;
}

// The smallest kernel that forces an ADDRESS SPILL, and the regression test for it. A compare-exchange
// takes its expected value BY ADDRESS, so the compiler must put it somewhere: a compare-exchange is
// therefore the one construct in Metal that guarantees a slot holding a pointer, and the port must be
// able to emit it. On the translator as it stood, this kernel is REFUSED - "a spill this port does not
// model" - which is the point of having it: the refusal is a measured state, not a surprise, and this
// kernel is what makes it visible.
kernel void spillKernel(device atomic_uint *out [[buffer(0)]],
                        threadgroup atomic_uint *block [[threadgroup(16)]],
                        uint tid [[thread_position_in_grid]],
                        uint gid [[threadgroup_position_in_grid]],
                        uint tg [[threads_per_threadgroup]])
{
    // ORDER-INDEPENDENT BY CONSTRUCTION. An exchange has no defined answer when many threads exchange
    // into one slot - Metal and the port exchanged in a different order and both were right - so the
    // outcome here is an OR over every thread, which is the same whatever order they arrive in, and
    // the compare-exchange is still what forces the SPILL, because it takes its expected value by
    // address. Each thread also has its OWN slot, so no two of them share a prior value.
    atomic_store_explicit(&block[tid], 7u, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint expected = 7u;
    bool ok = atomic_compare_exchange_weak(&block[tid], &expected, 9u);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    atomic_fetch_or_explicit(&out[0], atomic_load_explicit(&block[tid], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
    atomic_store_explicit(&out[16 + tid], ok ? 1u : 0u, memory_order_relaxed);
    atomic_store_explicit(&out[32 + tid], expected, memory_order_relaxed);
}


// What the KERNEL sees, which is the only way to tell a dispatch's shape from an emitter's: the group
// position in the grid, the group's size, the group's width in the grid, and the thread's index in its
// group - one cell each, written by thread 0, so a run that says anything about a dispatch says it from
// Metal's own numbers and not from the host's arguments.
//
// It was added to this file by a script that RAISED before it wrote, so for two runs the source had no
// such kernel and the run said nothing about it - which is a failure a comment cannot fix and a guard can.
kernel void positionKernel(device atomic_uint *out [[buffer(0)]],
                          uint t [[thread_position_in_grid]],
                          uint gx [[threadgroup_position_in_grid]],
                          uint size [[threads_per_threadgroup]])
{
    // THE THREE SCALARS THE CALL CONVENTION CARRIES: the thread position in the grid, the threadgroup
    // position in the grid, and the size of the group. The other two the language offers - the index in
    // the group and the width of the grid - are DERIVED: the index is the thread's position inside its
    // own group, and the width is the grid's, and both are had from the three by the kernel rather than
    // carried by the convention, which is the point of the witness: it must not ask for what the
    // convention does not pass.
    uint inGroup = t - gx * size;
    uint gridWidth = size;
    // EVERY THREAD REPORTS, into its OWN cell. Reporting only from thread 0 cannot tell "every thread
    // is at position 0" from "they are at 0..7" - which is exactly the difference atomicFamilyKernel
    // turns on, and the first version of this witness could not see it.
    atomic_store_explicit(&out[t], gx, memory_order_relaxed);
    atomic_store_explicit(&out[16 + t], inGroup, memory_order_relaxed);
    atomic_store_explicit(&out[32 + t], size, memory_order_relaxed);
    atomic_store_explicit(&out[48 + t], gridWidth, memory_order_relaxed);
}





// A COPY of atomicFamilyKernel's own parameter list and attributes, which writes each of them into its
// OWN cell - so if the port binds them in the AIR's ORDER and Metal binds them by ATTRIBUTE, a kernel
// whose AIR order is not (thread, group, size) shows a swap here, where positionKernel cannot: its order
// is the canonical one, so it agrees either way.
kernel void atomicFamilyKernelProbe(device atomic_uint *out [[buffer(0)]],
                                    uint t [[thread_position_in_grid]],
                                    uint g [[threadgroup_position_in_grid]],
                                    uint sz [[threads_per_threadgroup]])
{
    atomic_store_explicit(&out[0 + t], t, memory_order_relaxed);
    atomic_store_explicit(&out[16 + t], g, memory_order_relaxed);
    atomic_store_explicit(&out[32 + t], sz, memory_order_relaxed);
}

// The block as the KERNEL sees it, after the family has run: every slot into its own cell. This decides
// between the three candidates for atomicFamilyKernel's difference - an OFFSET, a WIDTH, or the value
// the exchange stored - without guessing at any of them:
//   sixteen distinct values, one per thread  -> each thread has its own slot
//   one value repeated                        -> all eight threads share a slot: width or offset
//   both sides agree and the cell still differs -> what the exchange stored, which is `base`
kernel void blockProbe(device atomic_uint *out [[buffer(0)]],
                       threadgroup atomic_uint *block [[threadgroup(16)]],
                       uint tid [[thread_position_in_grid]],
                       uint gx [[threadgroup_position_in_grid]],
                       uint size [[threads_per_threadgroup]])
{
    uint base = gx * size + tid;
    atomic_fetch_add_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_sub_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_max_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_min_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_or_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_xor_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_and_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_exchange_explicit(&block[tid], base, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint slot = 0; slot < 16; slot++)
        atomic_store_explicit(&out[slot], atomic_load_explicit(&block[slot], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
}

// (A) DEFINED BEHAVIOUR, and the probe that settles it. Every thread writes its OWN slot, there is a
// BARRIER, and every thread then reads its NEIGHBOUR's slot. Nothing here depends on the block's
// initial contents and nothing depends on the order threads run in, so both implementations must answer
// the same thing and any difference is one of them being wrong. Real Metal's threadgroup memory is
// shared by the group - that is what it is for - so the answer is 2 3 4 5 6 7 8 1.
kernel void shareProbe(device atomic_uint *out [[buffer(0)]],
                       threadgroup atomic_uint *block [[threadgroup(8)]],
                       uint tid [[thread_position_in_grid]],
                       uint gx [[threadgroup_position_in_grid]],
                       uint size [[threads_per_threadgroup]])
{
    atomic_store_explicit(&block[tid], tid + 1, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    // The thread's OWN slot and its NEIGHBOUR's, both after the barrier, in separate cells. If the own
    // cell is right and the neighbour's is zero, the WRITE landed and the cross-thread READ lost it; if
    // the own cell is zero too, the write itself did not land. One run, and the fault is on one side or
    // the other rather than a third reading of the same numbers.
    uint own = atomic_load_explicit(&block[tid], memory_order_relaxed, mem_flags::mem_threadgroup);
    uint neighbour = atomic_load_explicit(&block[(tid + 1) % 8], memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_store_explicit(&out[tid], neighbour, memory_order_relaxed);
    atomic_store_explicit(&out[8 + tid], own, memory_order_relaxed);
}

// (2) THE SENTINEL PROBE: it touches NO threadgroup memory and writes a value nothing can produce by
// accident. If the oracle does not answer 0xC0FFEE + tid, the loss is in its READBACK path - the
// buffer's storage, the wait, or a synchronize - and not in the block at all.
kernel void readbackProbe(device atomic_uint *out [[buffer(0)]],
                          uint tid [[thread_position_in_grid]],
                          uint gx [[threadgroup_position_in_grid]],
                          uint size [[threads_per_threadgroup]])
{
    atomic_store_explicit(&out[tid], 0xC0FFEEu + tid, memory_order_relaxed);
}

// The three forms of the same question, so what is lost is named rather than argued about.
//   argNoBar   a [[threadgroup(N)]] ARGUMENT, one thread, write then read with NO barrier
//   argBarrier the same argument, one thread, write, barrier, read
//   localArray a threadgroup array INSIDE the kernel - no argument, no attribute, no index - write,
//              barrier, read
// If the argument form loses the write and the local array does not, then what differs is the
// argument's declaration and not the memory.
kernel void argNoBar(device atomic_uint *out [[buffer(0)]],
                      threadgroup atomic_uint *block [[threadgroup(1)]])
{
    atomic_store_explicit(&block[0], 7u, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_store_explicit(&out[0], atomic_load_explicit(&block[0], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
}

kernel void argBarrier(device atomic_uint *out [[buffer(0)]],
                        threadgroup atomic_uint *block [[threadgroup(1)]])
{
    atomic_store_explicit(&block[0], 7u, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    atomic_store_explicit(&out[0], atomic_load_explicit(&block[0], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
}

kernel void localArray(device atomic_uint *out [[buffer(0)]])
{
    threadgroup atomic_uint block[16];
    atomic_store_explicit(&block[0], 7u, memory_order_relaxed, mem_flags::mem_threadgroup);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    atomic_store_explicit(&out[0], atomic_load_explicit(&block[0], memory_order_relaxed, mem_flags::mem_threadgroup), memory_order_relaxed);
}
