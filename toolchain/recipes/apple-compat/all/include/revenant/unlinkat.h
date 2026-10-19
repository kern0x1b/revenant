#ifndef REVENANT_UNLINKAT_H
#define REVENANT_UNLINKAT_H

#include <fcntl.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

int revenant_unlinkat(int directory, const char *path, int flags);

#ifdef __cplusplus
}
#endif

#define unlinkat revenant_unlinkat

#endif
