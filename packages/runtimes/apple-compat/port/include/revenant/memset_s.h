#ifndef REVENANT_MEMSET_S_H
#define REVENANT_MEMSET_S_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int revenant_memset_s(void *bytes, size_t capacity, int value, size_t count);

#ifdef __cplusplus
}
#endif

#define memset_s revenant_memset_s

#endif
