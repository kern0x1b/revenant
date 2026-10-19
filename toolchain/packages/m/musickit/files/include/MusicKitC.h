#ifndef MUSICKIT_C_H
#define MUSICKIT_C_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int CharonMusicKitSignES256(const unsigned char *keyDer,
                            size_t keyDerLength,
                            const unsigned char *message,
                            size_t messageLength,
                            unsigned char *raw,
                            size_t capacity);

#ifdef __cplusplus
}
#endif

#endif
