#ifndef REVENANT_FDOPENDIR_H
#define REVENANT_FDOPENDIR_H

#include <dirent.h>

#ifdef __cplusplus
extern "C" {
#endif

DIR *revenant_fdopendir(int descriptor);

#ifdef __cplusplus
}
#endif

#define fdopendir revenant_fdopendir

#endif
