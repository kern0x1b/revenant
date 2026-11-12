#include <mach-o/loader.h>
#include <pthread.h>
#include <stdint.h>

extern const struct mach_header _mh_dylib_header;
extern void xl_run_initializers(void);
extern void xl_install_diagnostics(void);
_Noreturn void xl_unsupported(const char *message);

enum { XL_LIBRARY_IDLE, XL_LIBRARY_READY };

static pthread_mutex_t xl_library_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_t xl_library_owner;
static int xl_library_state;

static int xl_library_placed(void)
{
    return (uintptr_t)&_mh_dylib_header == XL_LIBRARY_BASE;
}

void xl_library_ensure(void)
{
    if (__atomic_load_n(&xl_library_state, __ATOMIC_ACQUIRE) == XL_LIBRARY_READY)
        return;
    if (pthread_equal(__atomic_load_n(&xl_library_owner, __ATOMIC_RELAXED), pthread_self()))
        return;
    pthread_mutex_lock(&xl_library_lock);
    if (xl_library_state == XL_LIBRARY_IDLE) {
        if (!xl_library_placed())
            xl_unsupported("the translated library was not loaded at its link address");
        __atomic_store_n(&xl_library_owner, pthread_self(), __ATOMIC_RELAXED);
        xl_run_initializers();
        __atomic_store_n(&xl_library_state, XL_LIBRARY_READY, __ATOMIC_RELEASE);
        __atomic_store_n(&xl_library_owner, NULL, __ATOMIC_RELAXED);
    }
    pthread_mutex_unlock(&xl_library_lock);
}

int xl_library_init(void)
{
    if (!xl_library_placed())
        return 1;
    xl_library_ensure();
    return 0;
}

void xl_library_diagnostics(void)
{
    xl_install_diagnostics();
}
