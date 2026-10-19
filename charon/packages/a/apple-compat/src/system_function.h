#ifndef CHARON_SYSTEM_FUNCTION_H
#define CHARON_SYSTEM_FUNCTION_H

#include <dlfcn.h>
#include <stdatomic.h>
#include <stdint.h>

#ifndef CHARON_COMPAT_SYSTEM
#define CHARON_COMPAT_SYSTEM 1
#endif

enum { CHARON_SYSTEM_UNRESOLVED = 0, CHARON_SYSTEM_ABSENT = 1 };

static inline void *charon_system_function(_Atomic(uintptr_t) *slot, const char *library, const char *name)
{
    uintptr_t found = atomic_load_explicit(slot, memory_order_relaxed);
    if (found == CHARON_SYSTEM_UNRESOLVED) {
        void *symbol = NULL;
        void *image = CHARON_COMPAT_SYSTEM ? dlopen(library, RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD) : NULL;
        if (image)
            symbol = dlsym(image, name);
        found = symbol ? (uintptr_t)symbol : CHARON_SYSTEM_ABSENT;
        atomic_store_explicit(slot, found, memory_order_relaxed);
    }
    return found == CHARON_SYSTEM_ABSENT ? NULL : (void *)found;
}

#define CHARON_LIBSYSTEM "/usr/lib/libSystem.B.dylib"
#define CHARON_LIBSYSTEM_PLATFORM "/usr/lib/system/libsystem_platform.dylib"
#define CHARON_LIBDISPATCH "/usr/lib/system/libdispatch.dylib"
#define CHARON_LIBSYSTEM_PTHREAD "/usr/lib/system/libsystem_pthread.dylib"

#endif
