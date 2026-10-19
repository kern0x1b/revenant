// One atomic per order the Metal Shading Language allows on it, so the code the compiler emits for
// each is measured rather than guessed. The names say which order and which operation.
#include <metal_stdlib>
using namespace metal;

kernel void orders(device atomic_uint *g [[buffer(0)]],
                   threadgroup atomic_uint *l [[threadgroup(0)]])
{
    // read-modify-write: all six orders are legal on a fetch_add
    atomic_fetch_add_explicit(&g[0], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&g[1], 1u, memory_order_acquire);
    atomic_fetch_add_explicit(&g[2], 1u, memory_order_release);
    atomic_fetch_add_explicit(&g[3], 1u, memory_order_acq_rel);
    atomic_fetch_add_explicit(&g[4], 1u, memory_order_seq_cst);
    // the other operations at two orders each, so an operation is not assumed to share one's code
    atomic_fetch_max_explicit(&g[5], 1u, memory_order_relaxed);
    atomic_fetch_max_explicit(&g[6], 1u, memory_order_acq_rel);
    atomic_fetch_or_explicit(&g[7], 1u, memory_order_relaxed);
    atomic_fetch_or_explicit(&g[8], 1u, memory_order_seq_cst);
    atomic_exchange_explicit(&g[9], 1u, memory_order_relaxed);
    atomic_exchange_explicit(&g[10], 1u, memory_order_acq_rel);
    // a load takes any of them
    atomic_load_explicit(&g[11], memory_order_relaxed);
    atomic_load_explicit(&g[12], memory_order_acquire);
    atomic_load_explicit(&g[13], memory_order_seq_cst);
    // a STORE: the language allows only relaxed here, and whatever code that compiles to is the one
    // the tool has to read
    atomic_store_explicit(&g[20], 1u, memory_order_relaxed);
    // and the threadgroup family, whose address space differs and whose codes might too
    atomic_fetch_add_explicit(&l[0], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&l[1], 1u, memory_order_acq_rel);
    atomic_load_explicit(&l[2], memory_order_acquire);
    atomic_store_explicit(&l[3], 1u, memory_order_relaxed);
}
