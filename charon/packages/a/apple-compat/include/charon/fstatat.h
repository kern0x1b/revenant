#ifndef CHARON_FSTATAT_H
#define CHARON_FSTATAT_H

#include <sys/stat.h>

#ifdef __cplusplus
extern "C" {
#endif

int charon_fstatat(int directory, const char *path, struct stat *buffer, int flags);

#ifdef __cplusplus
}
#endif

#define fstatat charon_fstatat

#endif
