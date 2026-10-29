#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stddef.h>

static void *RevenantVTSystemHandle(void)
{
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox", RTLD_LAZY);
        if (!handle)
            handle = dlopen("/System/Library/PrivateFrameworks/VideoToolbox.framework/VideoToolbox", RTLD_LAZY);
    });
    return handle;
}

__attribute__((visibility("hidden"))) void *RevenantVTSystemSymbol(const char *name)
{
    void *handle = RevenantVTSystemHandle();
    return handle ? dlsym(handle, name) : NULL;
}
