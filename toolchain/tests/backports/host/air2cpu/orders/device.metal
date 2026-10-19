// The DEVICE family's argument list: one relaxed operation of every form on a device buffer, so each
// form's own layout is read rather than assumed from the threadgroup one, and - to settle whether the
// device family can carry an order at all - the same fetch_add written with each of the five orders
// Metal's language has.
#include <metal_stdlib>
using namespace metal;

// One relaxed operation of every form, in DEVICE memory.
kernel void deviceForms(device atomic_uint *d [[buffer(0)]],
                        device atomic_int *s [[buffer(1)]])
{
    atomic_fetch_add_explicit(&d[0], 1u, memory_order_relaxed);
    atomic_fetch_sub_explicit(&d[1], 1u, memory_order_relaxed);
    atomic_fetch_max_explicit(&d[2], 1u, memory_order_relaxed);
    atomic_fetch_min_explicit(&d[3], 1u, memory_order_relaxed);
    atomic_fetch_and_explicit(&d[4], 1u, memory_order_relaxed);
    atomic_fetch_or_explicit(&d[5], 1u, memory_order_relaxed);
    atomic_fetch_xor_explicit(&d[6], 1u, memory_order_relaxed);
    atomic_exchange_explicit(&d[7], 1u, memory_order_relaxed);
    atomic_load_explicit(&d[8], memory_order_relaxed);
    atomic_store_explicit(&d[9], 1u, memory_order_relaxed);
    uint expected = 0;
    atomic_compare_exchange_weak(&d[10], &expected, 1u);
    atomic_fetch_add_explicit(&s[0], 1, memory_order_relaxed);
    atomic_fetch_min_explicit(&s[1], -1, memory_order_relaxed);
}

// What orders a DEVICE fetch_add can carry, which is one.
kernel void deviceOrders(device atomic_uint *d [[buffer(0)]])
{
    atomic_fetch_add_explicit(&d[0], 1u, memory_order_relaxed);
    // The next four do not compile, and that is the measurement: a DEVICE atomic takes only relaxed
    // without a mem_flags argument, which the compiler's own diagnostic says -
    // "candidate disabled: 'order' argument must be 'metal::memory_order_relaxed' if no 'mem_flags'
    // argument is provided". The threadgroup family, which does take mem_flags, carries all five.
    // atomic_fetch_add_explicit(&d[1], 1u, memory_order_acquire);
    // atomic_fetch_add_explicit(&d[2], 1u, memory_order_release);
    // atomic_fetch_add_explicit(&d[3], 1u, memory_order_acq_rel);
    // atomic_fetch_add_explicit(&d[4], 1u, memory_order_seq_cst);
}
