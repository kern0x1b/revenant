#include <dlfcn.h>
#include <pthread.h>
#include <sys/select.h>
#include "RevenantFDSet.h"

#define REVENANT_LIBSYSTEM_EXPORT __attribute__((visibility("default")))
#define REVENANT_LIBSYSTEM_PATH "/usr/lib/libSystem.B.dylib"

typedef int (*fd_set_check)(int, const void *, int);

static fd_set_check system_check;
static pthread_once_t system_once = PTHREAD_ONCE_INIT;

static void resolve_system_check(void)
{
    void *system = dlopen(REVENANT_LIBSYSTEM_PATH, RTLD_LAZY | RTLD_NOLOAD);
    if (system != NULL) {
        system_check = (fd_set_check)dlsym(system, "__darwin_check_fd_set_overflow");
    }
}

int revenant_fd_set_in_range(int fd)
{
    return fd >= 0 && fd < FD_SETSIZE;
}

REVENANT_LIBSYSTEM_EXPORT int __darwin_check_fd_set_overflow(int fd, const void *set, int strict)
{
    pthread_once(&system_once, resolve_system_check);
    if (system_check != NULL) {
        return system_check(fd, set, strict);
    }
    return revenant_fd_set_in_range(fd);
}
