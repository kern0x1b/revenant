// The two things the order table needs, separated so each can be read on its own.
//
// SCOPE: the same operation, the same order, in DEVICE memory and in THREADGROUP memory. Whatever
// field differs between these two is the scope, not the order.
//
// ORDER: the four orders the language allows on a THREADGROUP atomic, each with the mem_flags argument
// the threadgroup family takes and a device atomic does not. Each is on its own operation so the
// calls can be told apart in the AIR.
#include <metal_stdlib>
using namespace metal;

kernel void scopes(device atomic_uint *d [[buffer(0)]],
                   threadgroup atomic_uint *t [[threadgroup(0)]])
{
    // the same order, the same operation, two memories
    atomic_fetch_add_explicit(&d[0], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&t[0], 1u, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_load_explicit(&d[1], memory_order_relaxed);
    atomic_load_explicit(&t[1], memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_store_explicit(&d[2], 1u, memory_order_relaxed);
    atomic_store_explicit(&t[2], 1u, memory_order_relaxed, mem_flags::mem_threadgroup);
}

kernel void threadgroupOrders(threadgroup atomic_uint *t [[threadgroup(0)]])
{
    atomic_fetch_add_explicit(&t[0], 1u, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_add_explicit(&t[1], 1u, memory_order_acquire, mem_flags::mem_threadgroup);
    atomic_fetch_add_explicit(&t[2], 1u, memory_order_release, mem_flags::mem_threadgroup);
    atomic_fetch_add_explicit(&t[3], 1u, memory_order_acq_rel, mem_flags::mem_threadgroup);
    atomic_fetch_add_explicit(&t[4], 1u, memory_order_seq_cst, mem_flags::mem_threadgroup);
    atomic_fetch_or_explicit(&t[5], 1u, memory_order_acq_rel, mem_flags::mem_threadgroup);
    atomic_fetch_max_explicit(&t[6], 1u, memory_order_seq_cst, mem_flags::mem_threadgroup);
    atomic_exchange_explicit(&t[7], 1u, memory_order_release, mem_flags::mem_threadgroup);
    atomic_load_explicit(&t[8], memory_order_acquire, mem_flags::mem_threadgroup);
    atomic_store_explicit(&t[9], 1u, memory_order_release, mem_flags::mem_threadgroup);
}
