// A kernel that uses a simdgroup function, which a CPU has none of. The tool must refuse it by name
// rather than answer it wrongly, and that is what is measured: three refusal lines naming the kernel
// and the intrinsic, and no table written at all.
#include <metal_stdlib>
using namespace metal;
kernel void simdKernel(device uint *out [[buffer(0)]],
                       uint tid [[thread_position_in_grid]],
                       uint gid [[threadgroup_position_in_grid]],
                       uint tg [[threads_per_threadgroup]])
{
    simdgroup_barrier(mem_flags::mem_threadgroup);
    simd_max(tid);
    out[tid] = simd_broadcast(tid, 0u);
}
