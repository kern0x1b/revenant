#ifndef REVENANT_DIRSTAT_NP_H
#define REVENANT_DIRSTAT_NP_H

#include <stddef.h>

struct darwin_dirstat;

#ifdef __cplusplus
extern "C" {
#endif

int revenant_dirstat_np(const char *path, int flags, struct darwin_dirstat *ds, size_t dirstat_size);

#ifdef __cplusplus
}
#endif

#define dirstat_np revenant_dirstat_np

#endif
