#ifndef REVENANT_OPENAT_H
#define REVENANT_OPENAT_H

#include <fcntl.h>
#include <fcntl.h>

#ifdef __cplusplus
extern "C" {
#endif

int revenant_openat(int directory, const char *path, int flags, ...);

#ifdef __cplusplus
}
#endif

#define openat revenant_openat

#endif
