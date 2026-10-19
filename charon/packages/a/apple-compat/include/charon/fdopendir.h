#ifndef CHARON_FDOPENDIR_H
#define CHARON_FDOPENDIR_H

#include <dirent.h>

#ifdef __cplusplus
extern "C" {
#endif

DIR *charon_fdopendir(int descriptor);

#ifdef __cplusplus
}
#endif

#define fdopendir charon_fdopendir

#endif
