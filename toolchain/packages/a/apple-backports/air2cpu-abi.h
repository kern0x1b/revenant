#ifndef CHARON_AIR2CPU_ABI_H
#define CHARON_AIR2CPU_ABI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct charon_v4i {
    int32_t x, y, z, w;
} charon_v4i;

typedef void (*air2cpu_barrier_fn)(void *context, uint32_t tid, uint32_t threads);

typedef void (*air2cpu_kernel_fn)(void *const *buffers, charon_v4i thread, charon_v4i group,
                                  charon_v4i size, char *block, uint32_t blockBytes,
                                  air2cpu_barrier_fn barrier, void *barrierContext);

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
