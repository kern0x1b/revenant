#ifndef CHARON_ALIGNED_ALLOC_H
#define CHARON_ALIGNED_ALLOC_H

#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

void *charon_aligned_alloc(size_t alignment, size_t size);

#ifdef __cplusplus
}
#endif

#define aligned_alloc charon_aligned_alloc

#endif
