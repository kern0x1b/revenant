#ifndef CHARON_UNLINKAT_H
#define CHARON_UNLINKAT_H

#include <fcntl.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

int charon_unlinkat(int directory, const char *path, int flags);

#ifdef __cplusplus
}
#endif

#define unlinkat charon_unlinkat

#endif
