#pragma once

#include "xl_state.h"
#include "xl_proxy.h"

#include <stdarg.h>
#include <stddef.h>
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

struct xl_swift_method {
    uint32_t guest;
    void *host;
    const char *types;
};

struct xl_variadic_shim {
    const char *selector;
    void (*handler)(State *);
};

struct xl_selector_variant {
    const char *selector;
    const char *encoding;
    uint32_t guest;
};

void xl_bridge_init(void);
void *xl_take_super_class(State *state);
void *xl_take_forced_imp(State *state);
uintptr_t xl_protocol(uint64_t guest);
_Noreturn void xl_unsupported(const char *message);
_Noreturn void xl_narrowing_fault(const char *symbol, unsigned index, uint64_t value);
uint64_t xl_invoke(uint64_t address, uint64_t argument);
uint64_t xl_invoke_n(uint64_t address, const uint64_t *arguments, unsigned count);
uintptr_t xl_object_in(uint64_t guest, const char *symbol, unsigned index);
uintptr_t xl_object_in_raw(uint64_t guest, const char *symbol, unsigned index);
uint64_t xl_object_out(uintptr_t host);
uintptr_t xl_receiver_in(uint64_t guest);
void *xl_fast_items(uint64_t items, uint64_t count);
extern uintptr_t xl_alias_low, xl_alias_span;
uintptr_t xl_alias_resolve(uintptr_t pointer);
uint64_t xl_alias_pointer(uintptr_t host);
uint64_t xl_alias_object(uintptr_t host);
uint64_t xl_protocol_out(uintptr_t host);
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

static inline uintptr_t xl_narrow_pointer(uint64_t value, const char *symbol, unsigned index)
{
    if (value >> 32) {
        if (value >= 0xFFFFFFFFFFFFFF00ull)
            return (uintptr_t)(uint32_t)value;
        xl_narrowing_fault(symbol, index, value);
    }
    uintptr_t pointer = (uintptr_t)value;
    if (pointer - xl_alias_low < xl_alias_span)
        return xl_alias_resolve(pointer);
    return pointer;
}

static inline uint64_t xl_widen_plain(uintptr_t value)
{
    if (value >= 0xFFFFFF00u)
        return (uint64_t)(int64_t)(int32_t)value;
    return (uint64_t)value;
}

static inline uint64_t xl_widen_pointer(uintptr_t value)
{
    if ((value & 7) == 4)
        return xl_alias_pointer(value);
    return xl_widen_plain(value);
}

static inline uint64_t xl_kind_out(char kind, uintptr_t host)
{
    switch (kind) {
    case 'O': case 'K': return xl_object_out(host);
    case 'P': return xl_widen_pointer(host);
    default: return (uint64_t)host;
    }
}

static inline uintptr_t xl_kind_in(char kind, uint64_t guest, const char *symbol)
{
    switch (kind) {
    case 'O': case 'K': return xl_object_in(guest, symbol, 0);
    case 'P': return xl_narrow_pointer(guest, symbol, 0);
    default: return (uintptr_t)guest;
    }
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
    void *wide;
};

void xl_format_marshal(struct xl_format *format, const char *text, void *object, const uint64_t *arguments, const char *symbol);
void xl_format_marshal_wide(struct xl_format *format, const wchar_t *text, void *object, const uint64_t *arguments, const char *symbol);
struct xl_scanf_fix;

struct xl_scanf {
    char *arguments;
    struct xl_scanf_fix *fixes;
    unsigned count;
};

void xl_scanf_marshal(struct xl_scanf *scan, const char *text, const uint64_t *arguments, const char *symbol);
void xl_scanf_finish(struct xl_scanf *scan, int result);
void xl_format_marshal_valist(struct xl_format *format, const char *text, void *object, uint64_t guest_valist, const char *symbol);
void xl_format_release(struct xl_format *format);

int xl_shim_openat(int dirfd, const char *path, int flags, int mode);

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
