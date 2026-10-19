#pragma once

#include "xl_state.h"

#include <stdarg.h>
#include <stdint.h>
#include <dirent.h>
#include <sqlite3.h>
#include <time.h>
#include <sys/stat.h>
#include <stdlib.h>

typedef struct State State;
typedef struct Memory Memory;

#define XL_REG(state, name) (*(uint64_t *)((char *)(state) + XL_OFFSET_##name))

static inline void xl_return(State *state)
{
    XL_REG(state, PC) = XL_REG(state, X30);
}

static inline void *xl_argument(State *state)
{
    return (void *)(uintptr_t)XL_REG(state, X0);
}

struct xl_selector_shim {
    const char *selector;
    uint32_t guest;
};

struct xl_imp_entry {
    void *imp;
    uint32_t guest;
};

struct xl_variadic_shim {
    const char *selector;
    void (*handler)(State *);
};

// A selector whose SDK declarations disagree on signature across classes (e.g. -timestamp is
// NSDate* on CLLocation but NSTimeInterval on UIEvent). Each distinct signature gets its own
// bridge; the runtime dispatches on the receiver's actual method type encoding.
struct xl_selector_variant {
    const char *selector;
    const char *encoding;  // ObjC type encoding, digits (offsets) stripped
    uint32_t guest;
};

void xl_bridge_init(void);
void *xl_take_super_class(State *state);
uintptr_t xl_protocol(uint64_t guest);
_Noreturn void xl_unsupported(const char *message);
_Noreturn void xl_narrowing_fault(const char *symbol, unsigned index, uint64_t value);
uint64_t xl_invoke(uint64_t address, uint64_t argument);
uint64_t xl_invoke_n(uint64_t address, const uint64_t *arguments, unsigned count);
uintptr_t xl_object_in(uint64_t guest, const char *symbol, unsigned index);
uint64_t xl_object_out(uintptr_t host);
unsigned xl_callback_slot(unsigned signature, uint64_t target);
extern uint64_t xl_callback_targets[][32];

static inline int64_t xl_narrow_signed(int64_t value, int64_t host_min, int64_t host_max, int64_t guest_min, int64_t guest_max, const char *symbol, unsigned index)
{
    if (value == guest_max)
        return host_max;
    if (value == guest_min)
        return host_min;
    if (value < host_min || value > host_max)
        xl_narrowing_fault(symbol, index, (uint64_t)value);
    return value;
}

static inline uint64_t xl_narrow_unsigned(uint64_t value, uint64_t host_max, uint64_t guest_max, const char *symbol, unsigned index)
{
    if (value == guest_max)
        return host_max;
    if (value > host_max)
        xl_narrowing_fault(symbol, index, value);
    return value;
}

// A guest pointer is 64-bit and a host pointer 32-bit, but C code also passes small negative
// sentinel "pointers" -- (void *)-1 (MAP_FAILED, SIG_ERR, RTLD_NEXT), RTLD_DEFAULT (-2), SEM_FAILED,
// ... -- which are sign-extended to 0xffff...ffNN on arm64 and are 0xffffffNN on armv7. Treat the
// top 256 values as sentinels in both directions so they keep their identity across the bridge;
// no real 32-bit user address lives there, so this cannot mask a genuine truncation.
static inline uintptr_t xl_narrow_pointer(uint64_t value, const char *symbol, unsigned index)
{
    if (value >> 32) {
        if (value >= 0xFFFFFFFFFFFFFF00ull)
            return (uintptr_t)(uint32_t)value;
        xl_narrowing_fault(symbol, index, value);
    }
    return (uintptr_t)value;
}

static inline uint64_t xl_widen_pointer(uintptr_t value)
{
    if (value >= 0xFFFFFF00u)
        return (uint64_t)(int64_t)(int32_t)value;
    return (uint64_t)value;
}

static inline int64_t xl_widen_signed(int64_t value, int64_t host_min, int64_t host_max, int64_t guest_min, int64_t guest_max)
{
    if (value == host_max)
        return guest_max;
    if (value == host_min)
        return guest_min;
    return value;
}

static inline uint64_t xl_widen_unsigned(uint64_t value, uint64_t host_max, uint64_t guest_max)
{
    return value == host_max ? guest_max : value;
}

struct xl_format {
    char *text;
    void *object;
    char *arguments;
};

void xl_format_marshal(struct xl_format *format, const char *text, void *object, const uint64_t *arguments, const char *symbol);
void xl_format_marshal_valist(struct xl_format *format, const char *text, void *object, uint64_t guest_valist, const char *symbol);
void xl_format_release(struct xl_format *format);

// Shims for libc functions absent on the target release (the *at family is not on iOS 6). The
// bridge generator routes the guest call here instead of the missing libSystem symbol.
int xl_shim_openat(int dirfd, const char *path, int flags, int mode);

// Typed memory operations (iOS 16+): drop the type-id hint and call the plain allocator.
void xl_errno_trace(const char *name, int64_t result, uint64_t first_argument, uint64_t second_argument);
double xl_shim_exp10(double x);
int xl_shim_sqlite3_prepare_v3(sqlite3 *db, const char *sql, int n, unsigned int flags, sqlite3_stmt **stmt, const char **tail);
const void *xl_shim_CGImageGetUTType(void *image);
void xl_shim_CGImageSourceRemoveCacheAtIndex(void *source, size_t index);
int xl_shim_clock_gettime(int clock_id, struct timespec *ts);
int xl_shim_clock_getres(int clock_id, struct timespec *ts);
int xl_shim_CCRandomGenerateBytes(void *bytes, size_t count);
int xl_shim_mkdirat(int fd, const char *path, mode_t mode);
int xl_shim_unlinkat(int fd, const char *path, int flag);
int xl_shim_fstatat(int fd, const char *path, struct stat *st, int flag);
ssize_t xl_shim_readlinkat(int fd, const char *path, char *buf, size_t size);
int xl_shim_fchmodat(int fd, const char *path, mode_t mode, int flag);
int xl_shim_fchownat(int fd, const char *path, uid_t uid, gid_t gid, int flag);
int xl_shim_faccessat(int fd, const char *path, int mode, int flag);
int xl_shim_renameat(int ofd, const char *opath, int nfd, const char *npath);
int xl_shim_linkat(int ofd, const char *opath, int nfd, const char *npath, int flag);
int xl_shim_symlinkat(const char *target, int fd, const char *linkpath);
DIR *xl_shim_fdopendir(int fd);
struct sqlite3_stmt;
int xl_shim_sqlite3_bind_blob64(struct sqlite3_stmt *stmt, int index, const void *data, unsigned long long n, void (*destructor)(void *));
int xl_shim_sqlite3_bind_text64(struct sqlite3_stmt *stmt, int index, const char *data, unsigned long long n, void (*destructor)(void *), unsigned char encoding);
void *xl_shim_sqlite3_malloc64(unsigned long long n);
void *xl_shim_sqlite3_realloc64(void *p, unsigned long long n);
void *xl_shim_malloc_type_malloc(size_t size, unsigned long long type_id);
void *xl_shim_malloc_type_calloc(size_t count, size_t size, unsigned long long type_id);
void *xl_shim_malloc_type_realloc(void *ptr, size_t size, unsigned long long type_id);
void *xl_shim_malloc_type_aligned_alloc(size_t alignment, size_t size, unsigned long long type_id);
