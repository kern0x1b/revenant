#ifndef CHARON_SYSTEM_FUNCTION_H
#define CHARON_SYSTEM_FUNCTION_H

#include <dlfcn.h>
#include <stdatomic.h>
#include <stdint.h>

/* The system's own definition, once a release has it, looked up in the system library that defines it. A shim with the
   system's name binds its image's calls to itself, and a shim exported once for the process (the locks in libc++abi) is also
   what a search of every loaded image finds first, since libc++ loads before libSystem's parts; so the lookup opens the
   defining library by path, only if it is already loaded, and asks it alone. A call that shares state with other images (a
   lock another image also takes) has to use the system's when there is one, or the two sides wait on different things.
   CHARON_COMPAT_SYSTEM=0 compiles the shim alone, for a test on a system that has the call. */
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

/* The umbrella, which re-exports the rest of the C library: the lookup for a call whose defining library moved between
   releases (arc4random_buf, libinfo in 4.3 and libSystem from 5; os_system_version_get_current_version, liblaunch on the
   32-bit slices and libxpc on the 64-bit ones). */
#define CHARON_LIBSYSTEM "/usr/lib/libSystem.B.dylib"
#define CHARON_LIBSYSTEM_PLATFORM "/usr/lib/system/libsystem_platform.dylib"
#define CHARON_LIBDISPATCH "/usr/lib/system/libdispatch.dylib"
#define CHARON_LIBSYSTEM_PTHREAD "/usr/lib/system/libsystem_pthread.dylib"

#endif
