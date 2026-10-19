#ifndef CHARON_MEMSET_S_H
#define CHARON_MEMSET_S_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ISO/IEC 9899:2011 K.3.7.4.1, which arrived in Apple's Libc with iOS 7. The shim is Apple's own answers, in
   packages/a/apple-compat/src/memset_s.c; a Swift module cannot see a force-included header, so it reaches this
   name through the CharonCompat module apple-compat installs beside this one. */
int charon_memset_s(void *bytes, size_t capacity, int value, size_t count);

#ifdef __cplusplus
}
#endif

#define memset_s charon_memset_s

#endif
