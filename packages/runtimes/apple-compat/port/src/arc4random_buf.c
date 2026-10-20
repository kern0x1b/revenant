#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "system_function.h"

static _Atomic(uintptr_t) revenant_system_arc4random_buf;

__attribute__((constructor))
static void revenant_resolve_arc4random_buf(void)
{
    revenant_system_function(&revenant_system_arc4random_buf, REVENANT_LIBSYSTEM, "arc4random_buf");
}

__attribute__((visibility("hidden")))
void revenant_arc4random_buf(void *buffer, size_t length)
{
    void (*system)(void *, size_t) = revenant_system_function(&revenant_system_arc4random_buf, REVENANT_LIBSYSTEM, "arc4random_buf");
    if (system) {
        system(buffer, length);
        return;
    }
    unsigned char *bytes = (unsigned char *)buffer;
    while (length >= sizeof(uint32_t)) {
        uint32_t word = arc4random();
        memcpy(bytes, &word, sizeof(word));
        bytes += sizeof(uint32_t);
        length -= sizeof(uint32_t);
    }
    if (length > 0) {
        uint32_t word = arc4random();
        memcpy(bytes, &word, length);
    }
}

__attribute__((visibility("hidden")))
void arc4random_buf(void *buffer, size_t length)
{
    revenant_arc4random_buf(buffer, length);
}
