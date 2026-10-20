#ifndef REVENANT_FCHMODAT_H
#define REVENANT_FCHMODAT_H

#include <fcntl.h>
#include <sys/stat.h>

#ifdef __cplusplus
extern "C" {
#endif

int revenant_fchmodat(int directory, const char *path, mode_t mode, int flags);

#ifdef __cplusplus
}
#endif

#define fchmodat revenant_fchmodat

#endif
