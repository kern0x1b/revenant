#ifndef CHARON_OPENAT_H
#define CHARON_OPENAT_H

#include <fcntl.h>
#include <fcntl.h>

#ifdef __cplusplus
extern "C" {
#endif

int charon_openat(int directory, const char *path, int flags, ...);

#ifdef __cplusplus
}
#endif

#define openat charon_openat

#endif
