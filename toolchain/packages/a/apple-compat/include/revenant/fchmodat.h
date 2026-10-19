#ifndef CHARON_FCHMODAT_H
#define CHARON_FCHMODAT_H

#include <fcntl.h>
#include <sys/stat.h>

#ifdef __cplusplus
extern "C" {
#endif

int charon_fchmodat(int directory, const char *path, mode_t mode, int flags);

#ifdef __cplusplus
}
#endif

#define fchmodat charon_fchmodat

#endif
