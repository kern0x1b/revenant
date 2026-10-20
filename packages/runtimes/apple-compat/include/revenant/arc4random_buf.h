#ifndef REVENANT_ARC4RANDOM_BUF_H
#define REVENANT_ARC4RANDOM_BUF_H

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

void revenant_arc4random_buf(void *buffer, size_t length);

#ifdef __cplusplus
}
#endif

#define arc4random_buf revenant_arc4random_buf

#endif
