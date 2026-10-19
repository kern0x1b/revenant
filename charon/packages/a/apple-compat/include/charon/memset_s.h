#ifndef CHARON_MEMSET_S_H
#define CHARON_MEMSET_S_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int charon_memset_s(void *bytes, size_t capacity, int value, size_t count);

#ifdef __cplusplus
}
#endif

#define memset_s charon_memset_s

#endif
