#ifndef REVENANT_FSTATAT_H
#define REVENANT_FSTATAT_H

#include <sys/stat.h>

#ifdef __cplusplus
extern "C" {
#endif

int revenant_fstatat(int directory, const char *path, struct stat *buffer, int flags);

#ifdef __cplusplus
}
#endif

#define fstatat revenant_fstatat

#endif
