// air2cpu-abi.h — the call convention of a translated kernel, in one place.
//
// tools/air2cpu EMITS a kernel with this signature and the port's encoder CALLS one with it, so the
// two are written from the same declaration rather than from each other's memory: a kernel that
// takes three sixteen-byte charon_v4i by value and a caller that passes three uint32 reads its
// arguments out of the wrong registers, and nothing in the build sees it, because an Objective-C
// method is not a link symbol and neither form is a C prototype. One typedef, included by both, is
// what makes a mismatch a compile error.
//
// The thread position, the threadgroup position and the group size are always four components wide,
// so a kernel of one dimension and a kernel of three call the same way.
#ifndef CHARON_AIR2CPU_ABI_H
#define CHARON_AIR2CPU_ABI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct charon_v4i {
    int32_t x, y, z, w;
} charon_v4i;

/* A barrier is a rendezvous of the threads of a workgroup, and the dispatch is what knows how its
   threads meet, so the barrier is a function the dispatch hands in. A group run on one thread has
   nothing to order and is handed a null one. */
typedef void (*air2cpu_barrier_fn)(void *context, uint32_t tid, uint32_t threads);

typedef void (*air2cpu_kernel_fn)(void *const *buffers, charon_v4i thread, charon_v4i group,
                                  charon_v4i size, char *block, uint32_t blockBytes,
                                  air2cpu_barrier_fn barrier, void *barrierContext);

/* The table the generated file emits and the pipeline looks the kernel up in. bufferCount is how
   many of the buffers a kernel names, and block is the length of its threadgroup block - zero where
   the AIR does not say, which the port reads as "nobody has stated one". */
typedef struct {
    const char *name;
    air2cpu_kernel_fn function;
    uint32_t bufferCount;
    uint32_t block;
    uint32_t reserved;
} air2cpu_kernel;

extern const air2cpu_kernel air2cpu_kernels[];
extern const unsigned air2cpu_kernel_count;

#ifdef __cplusplus
}
#endif

#endif
