#ifndef REVENANT_SYSTEM_FUNCTION_H
#define REVENANT_SYSTEM_FUNCTION_H

#include <dlfcn.h>
#include <stdatomic.h>
#include <stdint.h>

#ifndef REVENANT_COMPAT_SYSTEM
#define REVENANT_COMPAT_SYSTEM 1
#endif

enum { REVENANT_SYSTEM_UNRESOLVED = 0, REVENANT_SYSTEM_ABSENT = 1 };

static inline void *revenant_system_function(_Atomic(uintptr_t) *slot, const char *library, const char *name)
{
    uintptr_t found = atomic_load_explicit(slot, memory_order_relaxed);
    if (found == REVENANT_SYSTEM_UNRESOLVED) {
        void *symbol = NULL;
        void *image = REVENANT_COMPAT_SYSTEM ? dlopen(library, RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD) : NULL;
        if (image)
            symbol = dlsym(image, name);
        found = symbol ? (uintptr_t)symbol : REVENANT_SYSTEM_ABSENT;
        atomic_store_explicit(slot, found, memory_order_relaxed);
    }
    return found == REVENANT_SYSTEM_ABSENT ? NULL : (void *)found;
}

#define REVENANT_LIBSYSTEM "/usr/lib/libSystem.B.dylib"
#define REVENANT_LIBSYSTEM_PLATFORM "/usr/lib/system/libsystem_platform.dylib"
#define REVENANT_LIBDISPATCH "/usr/lib/system/libdispatch.dylib"
#define REVENANT_LIBSYSTEM_PTHREAD "/usr/lib/system/libsystem_pthread.dylib"

#endif
