#include "../revenant_impl.h"
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdint.h>
#include <sys/mman.h>
#include <unistd.h>

#define REVENANT_LIBSYSTEM_EXPORT __attribute__((visibility("default")))
#define REVENANT_LIBSYSTEM_PATH "/usr/lib/libSystem.B.dylib"

typedef dispatch_data_t (*revenant_data_create)(const void *, size_t, dispatch_queue_t, dispatch_block_t);

dispatch_block_t BACKPORT_IMPL(_dispatch_data_destructor_munmap) = ^{
};

BACKPORT_OVERRIDES(dispatch_data_create);

static revenant_data_create system_create;
static dispatch_once_t system_once;

static void resolve_system_create(void *unused)
{
    void *system = dlopen(REVENANT_LIBSYSTEM_PATH, RTLD_LAZY | RTLD_NOLOAD);
    if (system != NULL) {
        system_create = (revenant_data_create)dlsym(system, "dispatch_data_create");
    }
}

REVENANT_LIBSYSTEM_EXPORT dispatch_data_t dispatch_data_create(const void *buffer, size_t size, dispatch_queue_t queue,
                                                                dispatch_block_t destructor)
{
    dispatch_once_f(&system_once, NULL, resolve_system_create);
    if (destructor == BACKPORT_IMPL(_dispatch_data_destructor_munmap)) {
        size_t page = (size_t)getpagesize();
        size_t length = (size + page - 1) & ~(page - 1);
        return system_create(buffer, size, queue, ^{
            if (buffer != NULL && length != 0) {
                munmap((void *)buffer, length);
            }
        });
    }
    return system_create(buffer, size, queue, destructor);
}
