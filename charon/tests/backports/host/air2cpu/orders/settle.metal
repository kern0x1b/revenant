// Settling the two fields: which one is the scope, and which is the order.
//
// Both kernels hold everything else fixed and change ONE thing - the mem_flags argument - so the
// field that moves with it is the scope, and the field that does not is the order. A threadgroup
// atomic given mem_device keeps the threadgroup family's argument POSITIONS and takes the device's
// numbers; a device atomic given a mem_flags argument does the reverse. If both moves land on the
// same position, that position is the scope and the other one is the order.
#include <metal_stdlib>
using namespace metal;

// A threadgroup atomic, and the same one reached through a DEVICE scope.
kernel void threadgroupScoped(threadgroup atomic_uint *t [[threadgroup(0)]])
{
    atomic_fetch_add_explicit(&t[0], 1u, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_fetch_add_explicit(&t[1], 1u, memory_order_relaxed, mem_flags::mem_device);
    atomic_load_explicit(&t[2], memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_load_explicit(&t[3], memory_order_relaxed, mem_flags::mem_device);
    atomic_store_explicit(&t[4], 1u, memory_order_relaxed, mem_flags::mem_threadgroup);
    atomic_store_explicit(&t[5], 1u, memory_order_relaxed, mem_flags::mem_device);
}

// A device atomic, and the same one given a mem_flags argument, which the DEVICE family takes.
kernel void deviceScoped(device atomic_uint *d [[buffer(0)]])
{
    atomic_fetch_add_explicit(&d[0], 1u, memory_order_relaxed, mem_flags::mem_device);
    atomic_fetch_add_explicit(&d[1], 1u, memory_order_relaxed, mem_flags::mem_none);
    atomic_load_explicit(&d[2], memory_order_relaxed, mem_flags::mem_device);
    atomic_store_explicit(&d[3], 1u, memory_order_relaxed, mem_flags::mem_device);
}
