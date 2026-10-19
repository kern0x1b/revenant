#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "system_function.h"

static _Atomic(uintptr_t) charon_system_arc4random_buf;

/* The library that defines this call moved: iOS 4.3, which brought it, has it in libinfo, and iOS 5 in libSystem itself.
   So the umbrella is what the lookup asks (CHARON_LIBSYSTEM). */

__attribute__((constructor))
static void charon_resolve_arc4random_buf(void)
{
    charon_system_function(&charon_system_arc4random_buf, CHARON_LIBSYSTEM, "arc4random_buf");
}

/* iOS 4.3 brought arc4random_buf; every release before it has arc4random, which reads the same stream a word at a time,
   and that is what the buffer is filled from - the answer of the system's own implementation (Libc, gen/FreeBSD/arc4random.c),
   whose words are the stream's words in the order it hands them out. The tail is the low bytes of the last word. */
__attribute__((visibility("hidden")))
void charon_arc4random_buf(void *buffer, size_t length)
{
    void (*system)(void *, size_t) = charon_system_function(&charon_system_arc4random_buf, CHARON_LIBSYSTEM, "arc4random_buf");
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

/* The call answers to its own name as well, because a caller may name the symbol rather than write the call: the
   standard library of Embedded Swift declares it with @_extern(c, "arc4random_buf"), and a reference like that is not
   weak and passes no rename by. Darwin has no aliases, so the name is a call away; where the release has the call,
   neither name is built at all. */
__attribute__((visibility("hidden")))
void arc4random_buf(void *buffer, size_t length)
{
    charon_arc4random_buf(buffer, length);
}
