#import <Foundation/Foundation.h>

#include "xl_bridge.h"

State *xl_current_state(void);

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unwind.h>

_Static_assert(sizeof(va_list) == sizeof(char *), "host va_list must be a pointer");

#include <fcntl.h>
#include <errno.h>
#include <sys/syslimits.h>
#include <sys/event.h>
#include <zlib.h>
#include <sqlite3.h>
#include <unistd.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <dirent.h>
#include <time.h>
#include <dlfcn.h>
#include <netdb.h>
#include <stddef.h>
#include <mach-o/loader.h>

struct xl_gkevent {
    uint64_t ident;
    int16_t filter;
    uint16_t flags;
    uint32_t fflags;
    int64_t data;
    uint64_t udata;
} __attribute__((packed));

struct xl_gtimespec {
    int64_t tv_sec;
    int64_t tv_nsec;
} __attribute__((packed));

void xl_manual_kevent(void *pack)
{
    struct __attribute__((packed)) { uint64_t a0, a1, a2, a3, a4, a5, r; } *p = pack;
    int kq = (int)p->a0;
    const struct xl_gkevent *gch = (const struct xl_gkevent *)(uintptr_t)p->a1;
    int nch = (int)p->a2;
    struct xl_gkevent *gev = (struct xl_gkevent *)(uintptr_t)p->a3;
    int nev = (int)p->a4;
    const struct xl_gtimespec *gts = (const struct xl_gtimespec *)(uintptr_t)p->a5;

    struct kevent *ch = NULL, *ev = NULL;
    if (gch && nch > 0) {
        ch = malloc((size_t)nch * sizeof *ch);
        for (int i = 0; i < nch; i++) {
            EV_SET(&ch[i], (uintptr_t)gch[i].ident, gch[i].filter, gch[i].flags,
                   gch[i].fflags, (intptr_t)gch[i].data, (void *)(uintptr_t)gch[i].udata);
        }
    }
    if (gev && nev > 0)
        ev = malloc((size_t)nev * sizeof *ev);
    struct timespec ts, *tsp = NULL;
    if (gts) {
        ts.tv_sec = (time_t)gts->tv_sec;
        ts.tv_nsec = (long)gts->tv_nsec;
        tsp = &ts;
    }

    int r = kevent(kq, ch, nch, ev, nev, tsp);

    if (ev && r > 0) {
        for (int i = 0; i < r && i < nev; i++) {
            gev[i].ident = (uint64_t)ev[i].ident;
            gev[i].filter = ev[i].filter;
            gev[i].flags = ev[i].flags;
            gev[i].fflags = ev[i].fflags;
            gev[i].data = (int64_t)ev[i].data;
            gev[i].udata = (uint64_t)(uintptr_t)ev[i].udata;
        }
    }
    free(ch);
    free(ev);
    p->r = (uint64_t)(int64_t)r;
}
static void xl_diag(const char *line)
{
    int fd = open("/private/var/revenant/xlate-crash.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd >= 0) { dprintf(fd, "%s", line); close(fd); }
}

void _dyld_register_func_for_add_image(void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
#ifndef XL_TEST_NO_DYLD_IMAGE_BRIDGE
    for (unsigned i = 0; i < xl_guest_image_count; i++) {
        func((const struct mach_header *)xl_guest_images[i].header, xl_guest_images[i].slide);
    }
#endif
#ifndef XL_LIBRARY
    void (*real)(void (*)(const struct mach_header *, intptr_t)) =
        (void (*)(void (*)(const struct mach_header *, intptr_t)))
        dlsym(RTLD_NEXT, "_dyld_register_func_for_add_image");
    if (real) {
        real(func);
    }
#endif
}

int xl_shim_openat(int dirfd, const char *path, int flags, int mode)
{
    static int trace = -1;
    if (trace < 0)
        trace = access("/private/var/revenant/xl-trace-errno", F_OK) == 0;
    if (trace && (flags & O_CREAT)) {
        int fd = open("/private/var/revenant/xl-errno.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
        if (fd >= 0) { dprintf(fd, "openat O_CREAT dirfd=%d [%s] flags=0x%x mode=0%o\n", dirfd, path ? path : "(null)", flags, mode); close(fd); }
    }
    if (!path)
        return open(path, flags, mode);
    if (path[0] == '/' || dirfd == AT_FDCWD)
        return open(path, flags, mode);
    char dir[PATH_MAX];
    if (fcntl(dirfd, F_GETPATH, dir) == -1)
        return -1;
    char full[PATH_MAX];
    if ((int)snprintf(full, sizeof full, "%s/%s", dir, path) >= (int)sizeof full) {
        errno = ENAMETOOLONG;
        return -1;
    }
    return open(full, flags, mode);
}

static int xl_at_path(int dirfd, const char *path, char *out)
{
    if (!path) {
        errno = EFAULT;
        return -1;
    }
    if (path[0] == '/' || dirfd == AT_FDCWD) {
        if (strlen(path) >= PATH_MAX) { errno = ENAMETOOLONG; return -1; }
        strcpy(out, path);
        return 0;
    }
    char dir[PATH_MAX];
    if (fcntl(dirfd, F_GETPATH, dir) == -1)
        return -1;
    if ((int)snprintf(out, PATH_MAX, "%s/%s", dir, path) >= PATH_MAX) {
        errno = ENAMETOOLONG;
        return -1;
    }
    return 0;
}

#define XL_AT(fd, path, body) do { char full_[PATH_MAX]; if (xl_at_path((fd), (path), full_) == -1) return -1; return (body); } while (0)

int xl_shim_mkdirat(int fd, const char *path, mode_t mode) { XL_AT(fd, path, mkdir(full_, mode)); }
int xl_shim_unlinkat(int fd, const char *path, int flag) { XL_AT(fd, path, (flag & 0x0080 ) ? rmdir(full_) : unlink(full_)); }
int xl_shim_fstatat(int fd, const char *path, struct stat *st, int flag) { XL_AT(fd, path, (flag & 0x0020 ) ? lstat(full_, st) : stat(full_, st)); }
ssize_t xl_shim_readlinkat(int fd, const char *path, char *buf, size_t size) { char full_[PATH_MAX]; if (xl_at_path(fd, path, full_) == -1) return -1; return readlink(full_, buf, size); }
int xl_shim_fchmodat(int fd, const char *path, mode_t mode, int flag) { XL_AT(fd, path, (flag & 0x0020) ? lchmod(full_, mode) : chmod(full_, mode)); }
int xl_shim_fchownat(int fd, const char *path, uid_t uid, gid_t gid, int flag) { XL_AT(fd, path, (flag & 0x0020) ? lchown(full_, uid, gid) : chown(full_, uid, gid)); }
int xl_shim_faccessat(int fd, const char *path, int mode, int flag) { XL_AT(fd, path, access(full_, mode)); }

int xl_shim_renameat(int ofd, const char *opath, int nfd, const char *npath)
{
    char a[PATH_MAX], b[PATH_MAX];
    if (xl_at_path(ofd, opath, a) == -1 || xl_at_path(nfd, npath, b) == -1)
        return -1;
    return rename(a, b);
}

int xl_shim_linkat(int ofd, const char *opath, int nfd, const char *npath, int flag)
{
    char a[PATH_MAX], b[PATH_MAX];
    if (xl_at_path(ofd, opath, a) == -1 || xl_at_path(nfd, npath, b) == -1)
        return -1;
    return link(a, b);
}

int xl_shim_symlinkat(const char *target, int fd, const char *linkpath)
{
    char full_[PATH_MAX];
    if (xl_at_path(fd, linkpath, full_) == -1)
        return -1;
    return symlink(target, full_);
}

DIR *xl_shim_fdopendir(int fd)
{
    char dir[PATH_MAX];
    if (fcntl(fd, F_GETPATH, dir) == -1)
        return NULL;
    DIR *d = opendir(dir);
    if (d)
        close(fd);
    return d;
}

void xl_manual_utimensat(void *pack)
{
    struct __attribute__((packed)) { uint64_t fd, path, times, flag, r; } *p = pack;
    char full_[PATH_MAX];
    struct timeval tv[2];
    struct stat st;
    p->r = (uint64_t)(int64_t)-1;
    if (xl_at_path((int)p->fd, (const char *)xl_narrow_pointer(p->path, "utimensat", 1), full_) == -1)
        return;
    struct { int64_t sec, nsec; } *gt = (void *)(uintptr_t)p->times;
    struct timeval now;
    gettimeofday(&now, NULL);
    int need_stat = 0;
    for (int i = 0; i < 2; i++)
        if (gt && gt[i].nsec == -2)
            need_stat = 1;
    if (need_stat && stat(full_, &st) == -1)
        return;
    for (int i = 0; i < 2; i++) {
        if (!gt || gt[i].nsec == -1)
            tv[i] = now;
        else if (gt[i].nsec == -2) {
            tv[i].tv_sec = i == 0 ? st.st_atime : st.st_mtime;
            tv[i].tv_usec = 0;
        } else {
            tv[i].tv_sec = (time_t)gt[i].sec;
            tv[i].tv_usec = (int)(gt[i].nsec / 1000);
        }
    }
    p->r = (uint64_t)(int64_t)((p->flag & 0x0020) ? lutimes(full_, tv) : utimes(full_, tv));
}

struct xl_gdirent {
    uint64_t d_ino;
    uint64_t d_seekoff;
    uint16_t d_reclen;
    uint16_t d_namlen;
    uint8_t d_type;
    char d_name[1024];
};

static pthread_key_t xl_dirent_key;
static pthread_once_t xl_dirent_once = PTHREAD_ONCE_INIT;
static void xl_dirent_setup(void) { pthread_key_create(&xl_dirent_key, free); }

void xl_manual_readdir(void *pack)
{
    struct __attribute__((packed)) { uint64_t dir, r; } *p = pack;
    pthread_once(&xl_dirent_once, xl_dirent_setup);
    struct dirent *e = readdir((DIR *)xl_narrow_pointer(p->dir, "readdir", 0));
    if (!e) {
        p->r = 0;
        return;
    }
    struct xl_gdirent *g = pthread_getspecific(xl_dirent_key);
    if (!g) {
        g = calloc(1, sizeof *g);
        pthread_setspecific(xl_dirent_key, g);
    }
    g->d_ino = e->d_ino;
    g->d_seekoff = 0;
    g->d_namlen = e->d_namlen;
    g->d_reclen = sizeof *g;
    g->d_type = e->d_type;
    memcpy(g->d_name, e->d_name, e->d_namlen + 1u < sizeof g->d_name ? e->d_namlen + 1u : sizeof g->d_name);
    p->r = (uint64_t)(uintptr_t)g;
}

void xl_manual_signal(void *pack)
{
    struct __attribute__((packed)) { uint64_t sig, handler, r; } *p = pack;
    void (*h)(int) = SIG_DFL;
    if (p->handler == 1)
        h = SIG_IGN;
    else if (p->handler != 0) {
        char line[96];
        snprintf(line, sizeof line, "xlate: signal(%d, guest handler 0x%llx) not installed\n", (int)p->sig, (unsigned long long)p->handler);
        xl_diag(line);
        p->r = 0;
        return;
    }
    void (*old)(int) = signal((int)p->sig, h);
    p->r = old == SIG_ERR ? (uint64_t)-1 : old == SIG_IGN ? 1 : 0;
}

static char **xl_narrow_vector(uint64_t guest, const char *symbol, unsigned index)
{
    if (!guest)
        return NULL;
    const uint64_t *slots = (const uint64_t *)xl_narrow_pointer(guest, symbol, index);
    size_t count = 0;
    while (slots[count])
        count++;
    char **host = malloc((count + 1) * sizeof *host);
    if (!host)
        return (char **)-1;
    for (size_t i = 0; i < count; i++)
        host[i] = (char *)xl_narrow_pointer(slots[i], symbol, index);
    host[count] = NULL;
    return host;
}

void xl_manual_execv(void *pack)
{
    struct __attribute__((packed)) { uint64_t path, argv, r; } *p = pack;
    char **argv = xl_narrow_vector(p->argv, "execv", 1);
    p->r = (uint64_t)(int64_t)-1;
    if (argv == (char **)-1) {
        errno = ENOMEM;
        return;
    }
    execv((const char *)xl_narrow_pointer(p->path, "execv", 0), argv);
    int saved = errno;
    free(argv);
    errno = saved;
}

void xl_manual_execvp(void *pack)
{
    struct __attribute__((packed)) { uint64_t file, argv, r; } *p = pack;
    char **argv = xl_narrow_vector(p->argv, "execvp", 1);
    p->r = (uint64_t)(int64_t)-1;
    if (argv == (char **)-1) {
        errno = ENOMEM;
        return;
    }
    execvp((const char *)xl_narrow_pointer(p->file, "execvp", 0), argv);
    int saved = errno;
    free(argv);
    errno = saved;
}

void xl_manual_execvP(void *pack)
{
    struct __attribute__((packed)) { uint64_t file, search, argv, r; } *p = pack;
    char **argv = xl_narrow_vector(p->argv, "execvP", 2);
    p->r = (uint64_t)(int64_t)-1;
    if (argv == (char **)-1) {
        errno = ENOMEM;
        return;
    }
    execvP((const char *)xl_narrow_pointer(p->file, "execvP", 0), (const char *)xl_narrow_pointer(p->search, "execvP", 1), argv);
    int saved = errno;
    free(argv);
    errno = saved;
}

void xl_manual_execve(void *pack)
{
    struct __attribute__((packed)) { uint64_t path, argv, envp, r; } *p = pack;
    char **argv = xl_narrow_vector(p->argv, "execve", 1);
    char **envp = xl_narrow_vector(p->envp, "execve", 2);
    p->r = (uint64_t)(int64_t)-1;
    if (argv == (char **)-1 || envp == (char **)-1) {
        if (argv != (char **)-1)
            free(argv);
        if (envp != (char **)-1)
            free(envp);
        errno = ENOMEM;
        return;
    }
    execve((const char *)xl_narrow_pointer(p->path, "execve", 0), argv, envp);
    int saved = errno;
    free(argv);
    free(envp);
    errno = saved;
}

int xl_shim_sqlite3_bind_blob64(struct sqlite3_stmt *stmt, int index, const void *data, unsigned long long n, void (*destructor)(void *))
{
    if (n > 0x7fffffffULL) {
        if (destructor && destructor != SQLITE_STATIC && destructor != SQLITE_TRANSIENT)
            destructor((void *)data);
        return SQLITE_TOOBIG;
    }
    return sqlite3_bind_blob(stmt, index, data, (int)n, destructor);
}

int xl_shim_sqlite3_bind_text64(struct sqlite3_stmt *stmt, int index, const char *data, unsigned long long n, void (*destructor)(void *), unsigned char encoding)
{
    if (n > 0x7fffffffULL) {
        if (destructor && destructor != SQLITE_STATIC && destructor != SQLITE_TRANSIENT)
            destructor((void *)data);
        return SQLITE_TOOBIG;
    }
    if (encoding == SQLITE_UTF16 || encoding == 3  || encoding == 4 )
        return sqlite3_bind_text16(stmt, index, data, (int)n, destructor);
    return sqlite3_bind_text(stmt, index, data, (int)n, destructor);
}

void *xl_shim_sqlite3_malloc64(unsigned long long n) { return n > 0x7fffffffULL ? NULL : sqlite3_malloc((int)n); }
void *xl_shim_sqlite3_realloc64(void *p, unsigned long long n) { return n > 0x7fffffffULL ? NULL : sqlite3_realloc(p, (int)n); }

void xl_errno_trace(const char *name, int64_t result, uint64_t first_argument, uint64_t second_argument)
{
    if (result != -1)
        return;
    int saved = errno;
    static int enabled = -1;
    if (enabled < 0)
        enabled = access("/private/var/revenant/xl-trace-errno", F_OK) == 0;
    if (enabled) {
        static int devnull = -1;
        if (devnull < 0)
            devnull = open("/dev/null", O_WRONLY);
        char text[2][120];
        uint64_t args[2] = {first_argument, second_argument};
        for (int k = 0; k < 2; k++) {
            text[k][0] = 0;
            if (args[k] > 0x1000 && args[k] < 0x40000000u && devnull >= 0 && write(devnull, (const void *)(uintptr_t)args[k], 1) == 1) {
                const char *p = (const char *)(uintptr_t)args[k];
                size_t n = 0;
                for (; n < sizeof text[k] - 1 && p[n] >= 32 && p[n] < 127; n++)
                    text[k][n] = p[n];
                text[k][n] = 0;
            }
        }
        int fd = open("/private/var/revenant/xl-errno.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
        if (fd >= 0) {
            dprintf(fd, "%s errno=%d a0=0x%llx [%s] a1=0x%llx [%s]\n", name, saved, (unsigned long long)first_argument, text[0],
                    (unsigned long long)second_argument, text[1]);
            close(fd);
        }
    }
    errno = saved;
}

int xl_shim_CCRandomGenerateBytes(void *bytes, size_t count)
{
    if (!bytes && count)
        return -4300;
    arc4random_buf(bytes, count);
    return 0;
}

#include <mach/mach_time.h>
#include <sys/resource.h>
int xl_shim_clock_gettime(int clock_id, struct timespec *ts)
{
    if (!ts) { errno = EFAULT; return -1; }
    switch (clock_id) {
    case 0: {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        ts->tv_sec = tv.tv_sec;
        ts->tv_nsec = (long)tv.tv_usec * 1000;
        return 0;
    }
    case 4:
    case 6:
    case 8:
    case 5:
    case 9:  {
        static mach_timebase_info_data_t base;
        if (!base.denom)
            mach_timebase_info(&base);
        uint64_t ns = mach_absolute_time() * base.numer / base.denom;
        ts->tv_sec = (time_t)(ns / 1000000000ULL);
        ts->tv_nsec = (long)(ns % 1000000000ULL);
        return 0;
    }
    case 12:
    case 16:  {
        struct rusage ru;
        getrusage(RUSAGE_SELF, &ru);
        ts->tv_sec = ru.ru_utime.tv_sec + ru.ru_stime.tv_sec;
        ts->tv_nsec = ((long)ru.ru_utime.tv_usec + (long)ru.ru_stime.tv_usec) * 1000;
        if (ts->tv_nsec >= 1000000000L) { ts->tv_sec++; ts->tv_nsec -= 1000000000L; }
        return 0;
    }
    default:
        errno = EINVAL;
        return -1;
    }
}

int xl_shim_clock_getres(int clock_id, struct timespec *ts)
{
    if (clock_id != 0 && clock_id != 4 && clock_id != 5 && clock_id != 6 && clock_id != 8 && clock_id != 9 && clock_id != 12 && clock_id != 16) {
        errno = EINVAL;
        return -1;
    }
    if (ts) { ts->tv_sec = 0; ts->tv_nsec = 1000; }
    return 0;
}

#include <math.h>
double xl_shim_exp10(double x) { return pow(10.0, x); }
int xl_shim_sqlite3_prepare_v3(sqlite3 *db, const char *sql, int n, unsigned int flags, sqlite3_stmt **stmt, const char **tail)
{
    (void)flags;
    return sqlite3_prepare_v2(db, sql, n, stmt, tail);
}
const void *xl_shim_CGImageGetUTType(void *image) { (void)image; return NULL; }
void xl_shim_CGImageSourceRemoveCacheAtIndex(void *source, size_t index) { (void)source; (void)index; }

void *xl_shim_malloc_type_malloc(size_t size, unsigned long long type_id)
{
    (void)type_id;
    return malloc(size);
}

void *xl_shim_malloc_type_calloc(size_t count, size_t size, unsigned long long type_id)
{
    (void)type_id;
    return calloc(count, size);
}

void *xl_shim_malloc_type_realloc(void *ptr, size_t size, unsigned long long type_id)
{
    (void)type_id;
    return realloc(ptr, size);
}

void *xl_shim_malloc_type_aligned_alloc(size_t alignment, size_t size, unsigned long long type_id)
{
    (void)type_id;
    void *p = NULL;
    if (posix_memalign(&p, alignment, size) != 0)
        return NULL;
    return p;
}

struct xl_gzstream {
    uint64_t next_in;
    uint32_t avail_in, pad0;
    uint64_t total_in;
    uint64_t next_out;
    uint32_t avail_out, pad1;
    uint64_t total_out;
    uint64_t msg;
    uint64_t state;
    uint64_t zalloc, zfree, opaque;
    int32_t data_type, pad2;
    uint64_t adler;
    uint64_t reserved;
};
_Static_assert(sizeof(struct xl_gzstream) == 112, "arm64 z_stream is 112 bytes");

static z_streamp xl_z_host(struct xl_gzstream *g)
{
    return (z_streamp)(uintptr_t)g->state;
}

static void xl_z_in(struct xl_gzstream *g, z_streamp z)
{
    z->next_in = (Bytef *)xl_narrow_pointer(g->next_in, "zlib", 0);
    z->avail_in = g->avail_in;
    z->next_out = (Bytef *)xl_narrow_pointer(g->next_out, "zlib", 1);
    z->avail_out = g->avail_out;
}

static void xl_z_out(struct xl_gzstream *g, z_streamp z)
{
    g->next_in = xl_widen_pointer((uintptr_t)z->next_in);
    g->avail_in = z->avail_in;
    g->total_in = z->total_in;
    g->next_out = xl_widen_pointer((uintptr_t)z->next_out);
    g->avail_out = z->avail_out;
    g->total_out = z->total_out;
    g->msg = xl_widen_pointer((uintptr_t)z->msg);
    g->data_type = z->data_type;
    g->adler = z->adler;
}

static int xl_z_init(struct xl_gzstream *g, int (^init)(z_streamp))
{
    z_streamp z = calloc(1, sizeof *z);
    if (!z)
        return Z_MEM_ERROR;
    xl_z_in(g, z);
    int rc = init(z);
    if (rc != Z_OK) {
        free(z);
        g->state = 0;
        return rc;
    }
    g->state = (uint64_t)(uintptr_t)z;
    xl_z_out(g, z);
    return rc;
}

#define XL_Z_PACK(n) struct __attribute__((packed)) { uint64_t a[n]; uint64_t r; } *p = pack
#define XL_Z_G(i) ((struct xl_gzstream *)(uintptr_t)p->a[i])

void xl_manual_inflateInit_(void *pack) { XL_Z_PACK(3); p->r = (uint64_t)(int64_t)xl_z_init(XL_Z_G(0), ^int(z_streamp z) { return inflateInit_(z, ZLIB_VERSION, (int)sizeof(z_stream)); }); }
void xl_manual_inflateInit2_(void *pack) { XL_Z_PACK(4); int wb = (int)p->a[1]; p->r = (uint64_t)(int64_t)xl_z_init(XL_Z_G(0), ^int(z_streamp z) { return inflateInit2_(z, wb, ZLIB_VERSION, (int)sizeof(z_stream)); }); }
void xl_manual_deflateInit_(void *pack) { XL_Z_PACK(4); int lv = (int)p->a[1]; p->r = (uint64_t)(int64_t)xl_z_init(XL_Z_G(0), ^int(z_streamp z) { return deflateInit_(z, lv, ZLIB_VERSION, (int)sizeof(z_stream)); }); }
void xl_manual_deflateInit2_(void *pack)
{
    XL_Z_PACK(8);
    int lv = (int)p->a[1], method = (int)p->a[2], wb = (int)p->a[3], mem = (int)p->a[4], strat = (int)p->a[5];
    p->r = (uint64_t)(int64_t)xl_z_init(XL_Z_G(0), ^int(z_streamp z) { return deflateInit2_(z, lv, method, wb, mem, strat, ZLIB_VERSION, (int)sizeof(z_stream)); });
}

#define XL_Z_CALL(name, argc, body) \
    void xl_manual_##name(void *pack) { XL_Z_PACK(argc); struct xl_gzstream *g = XL_Z_G(0); z_streamp z = xl_z_host(g); \
        if (!z) { p->r = (uint64_t)(int64_t)Z_STREAM_ERROR; return; } xl_z_in(g, z); int rc = body; xl_z_out(g, z); p->r = (uint64_t)(int64_t)rc; }

XL_Z_CALL(inflate, 2, inflate(z, (int)p->a[1]))
XL_Z_CALL(deflate, 2, deflate(z, (int)p->a[1]))
XL_Z_CALL(inflateReset, 1, inflateReset(z))
XL_Z_CALL(deflateReset, 1, deflateReset(z))

#define XL_Z_END(name) \
    void xl_manual_##name(void *pack) { XL_Z_PACK(1); struct xl_gzstream *g = XL_Z_G(0); z_streamp z = xl_z_host(g); \
        if (!z) { p->r = (uint64_t)(int64_t)Z_STREAM_ERROR; return; } xl_z_in(g, z); int rc = name(z); xl_z_out(g, z); free(z); g->state = 0; p->r = (uint64_t)(int64_t)rc; }

XL_Z_END(inflateEnd)
XL_Z_END(deflateEnd)

void xl_manual___assert_rtn(void *pack)
{
    struct __attribute__((packed)) { uint64_t func, file, line, expr, r; } *p = pack;
    char line[600];
    snprintf(line, sizeof line, "xlate: assertion failed: (%s), function %s, file %s, line %d\n",
             (const char *)xl_narrow_pointer(p->expr, "__assert_rtn", 3), (const char *)xl_narrow_pointer(p->func, "__assert_rtn", 0),
             (const char *)xl_narrow_pointer(p->file, "__assert_rtn", 1), (int)p->line);
    fputs(line, stderr);
    xl_diag(line);
    State *state = xl_current_state();
    uint64_t sp = XL_REG(state, SP);
    if (sp && sp < 0x40000000u) {
        char dump[0x180 + 1];
        const unsigned char *b = (const unsigned char *)(uintptr_t)sp;
        for (unsigned i = 0; i < 0x180; i++)
            dump[i] = (b[i] >= 32 && b[i] < 127) ? (char)b[i] : '.';
        dump[0x180] = 0;
        char out[0x180 + 40];
        snprintf(out, sizeof out, "xlate:   guest stack at sp: %s\n", dump);
        xl_diag(out);
    }
    abort();
}

void xl_log_guest_frames(const char *why);
void xl_manual_exit(void *pack)
{
    struct __attribute__((packed)) { uint64_t status, r; } *p = pack;
    char why[64];
    snprintf(why, sizeof why, "guest called exit(%d)", (int)p->status);
    xl_log_guest_frames(why);
    exit((int)p->status);
}
void xl_manual__exit(void *pack)
{
    struct __attribute__((packed)) { uint64_t status, r; } *p = pack;
    char why[64];
    snprintf(why, sizeof why, "guest called _exit(%d)", (int)p->status);
    xl_log_guest_frames(why);
    _exit((int)p->status);
}

void xl_unsupported(const char *message)
{
    char buf[256];
    snprintf(buf, sizeof buf, "xlate: unsupported: %s\n", message);
    fprintf(stderr, "%s", buf);
    xl_diag(buf);
    abort();
}

void xl_report_guest_frame(void);

void xl_narrowing_fault(const char *symbol, unsigned index, uint64_t value)
{
    char buf[256];
    snprintf(buf, sizeof buf, "xlate: %s argument %u value 0x%llx does not fit the host type\n", symbol, index, value);
    fprintf(stderr, "%s", buf);
    xl_diag(buf);
    xl_report_guest_frame();
    abort();
}

static pthread_mutex_t xl_cxa_lock = PTHREAD_MUTEX_INITIALIZER;
static struct xl_cxa_entry { uint64_t func, arg; } *xl_cxa_list;
static unsigned xl_cxa_count, xl_cxa_cap, xl_cxa_armed;

static void xl_run_cxa_dtors(void)
{
    pthread_mutex_lock(&xl_cxa_lock);
    unsigned n = xl_cxa_count;
    pthread_mutex_unlock(&xl_cxa_lock);
    for (unsigned i = n; i-- > 0;)
        xl_invoke(xl_cxa_list[i].func, xl_cxa_list[i].arg);
}

void xl_manual___cxa_atexit(void *pack)
{
    struct __attribute__((packed)) { uint64_t a0, a1, a2, r; } *p = pack;
    pthread_mutex_lock(&xl_cxa_lock);
    if (xl_cxa_count == xl_cxa_cap) {
        xl_cxa_cap = xl_cxa_cap ? xl_cxa_cap * 2 : 128;
        xl_cxa_list = realloc(xl_cxa_list, xl_cxa_cap * sizeof *xl_cxa_list);
    }
    xl_cxa_list[xl_cxa_count].func = p->a0;
    xl_cxa_list[xl_cxa_count].arg = p->a1;
    xl_cxa_count++;
    if (!xl_cxa_armed) { xl_cxa_armed = 1; atexit(xl_run_cxa_dtors); }
    pthread_mutex_unlock(&xl_cxa_lock);
    p->r = 0;
}

struct xl_alloc_pack { uint64_t a0, r; } __attribute__((packed));
void xl_manual__Znwm(void *pack) { struct xl_alloc_pack *p = pack; p->r = (uint64_t)(uintptr_t)malloc((size_t)p->a0); }
void xl_manual__Znam(void *pack) { struct xl_alloc_pack *p = pack; p->r = (uint64_t)(uintptr_t)malloc((size_t)p->a0); }
void xl_manual__ZdlPv(void *pack) { struct xl_alloc_pack *p = pack; free((void *)(uintptr_t)p->a0); }
void xl_manual__ZdaPv(void *pack) { struct xl_alloc_pack *p = pack; free((void *)(uintptr_t)p->a0); }

void xl_manual_NSGetUncaughtExceptionHandler(void *pack) { struct { uint64_t r; } *p = pack; p->r = 0; }

extern void _Unwind_SjLj_Resume(struct _Unwind_Exception *exception);
extern void *__cxa_begin_catch(void *exception);
extern void __cxa_end_catch(void);
extern void __cxa_rethrow(void) __attribute__((noreturn));

void xl_manual___cxa_begin_catch(void *pack)
{
    struct __attribute__((packed)) { uint64_t a0, r; } *p = pack;
    p->r = (uint64_t)(uintptr_t)__cxa_begin_catch((void *)(uintptr_t)p->a0);
}

void xl_manual___cxa_end_catch(void *pack)
{
    (void)pack;
    __cxa_end_catch();
}

void xl_manual___cxa_rethrow(void *pack)
{
    (void)pack;
    __cxa_rethrow();
}

void xl_manual__Unwind_Resume(void *pack)
{
    struct __attribute__((packed)) { uint64_t a0, r; } *p = pack;
    _Unwind_SjLj_Resume((struct _Unwind_Exception *)(uintptr_t)p->a0);
}

struct xl_tlv_region {
    uint32_t vars_start;
    uint32_t vars_end;
    uint32_t data_start;
    uint32_t data_size;
    uint32_t total_size;
};
extern const struct xl_tlv_region xl_tlv_regions[];
extern const uint32_t xl_tlv_region_count;

static pthread_key_t *xl_tlv_keys;
static pthread_once_t xl_tlv_once = PTHREAD_ONCE_INIT;

static void xl_tlv_init(void)
{
    xl_tlv_keys = calloc(xl_tlv_region_count ? xl_tlv_region_count : 1, sizeof(pthread_key_t));
    for (uint32_t i = 0; i < xl_tlv_region_count; i++)
        pthread_key_create(&xl_tlv_keys[i], free);
}

void *xl_tlv_get(void *descriptor)
{
    pthread_once(&xl_tlv_once, xl_tlv_init);
    uintptr_t d = (uintptr_t)descriptor;
    for (uint32_t i = 0; i < xl_tlv_region_count; i++) {
        const struct xl_tlv_region *r = &xl_tlv_regions[i];
        if (d < r->vars_start || d >= r->vars_end)
            continue;
        void *block = pthread_getspecific(xl_tlv_keys[i]);
        if (!block) {
            block = malloc(r->total_size);
            if (!block)
                return 0;
            if (r->data_size)
                memcpy(block, (const void *)(uintptr_t)r->data_start, r->data_size);
            memset((char *)block + r->data_size, 0, r->total_size - r->data_size);
            pthread_setspecific(xl_tlv_keys[i], block);
        }
        uint64_t offset = *(const uint64_t *)((const char *)descriptor + 16);
        return (char *)block + offset;
    }
    xl_diag("xlate: tlv descriptor outside any region\n");
    return 0;
}

void xl_manual__tlv_bootstrap(void *pack)
{
    struct __attribute__((packed)) { uint64_t a0, r; } *p = pack;
    p->r = (uint64_t)(uintptr_t)xl_tlv_get((void *)(uintptr_t)p->a0);
}

static pthread_mutex_t xl_callback_lock = PTHREAD_MUTEX_INITIALIZER;

unsigned xl_callback_slot(unsigned signature, uint64_t target)
{
    pthread_mutex_lock(&xl_callback_lock);
    unsigned slot = 0;
    for (; slot < 32; slot++) {
        if (xl_callback_targets[signature][slot] == target || !xl_callback_targets[signature][slot])
            break;
    }
    if (slot == 32) {
        fprintf(stderr, "xlate: callback pool %u exhausted\n", signature);
        abort();
    }
    xl_callback_targets[signature][slot] = target;
    pthread_mutex_unlock(&xl_callback_lock);
    return slot;
}

struct xl_buffer {
    char *data;
    size_t size;
    size_t capacity;
};

static void xl_append(struct xl_buffer *buffer, const void *data, size_t size)
{
    if (buffer->size + size + 1 > buffer->capacity) {
        buffer->capacity = (buffer->size + size + 1) * 2;
        buffer->data = realloc(buffer->data, buffer->capacity);
    }
    memcpy(buffer->data + buffer->size, data, size);
    buffer->size += size;
    buffer->data[buffer->size] = 0;
}

void xl_format_marshal(struct xl_format *format, const char *text, void *object, const uint64_t *arguments, const char *symbol)
{
    int object_format = object != NULL;
    if (object_format)
        text = [(NSString *)object UTF8String];
    int sqlite_dialect = symbol && !strncmp(symbol, "sqlite3_", 8);
    struct xl_buffer out = {0}, args = {0};
    size_t next = 0;
    xl_append(&out, "", 0);
    for (const char *c = text; *c;) {
        if (*c != '%') {
            xl_append(&out, c++, 1);
            continue;
        }
        const char *start = c++;
        if (*c == '%') {
            xl_append(&out, "%%", 2);
            c++;
            continue;
        }
        xl_append(&out, "%", 1);
        while (*c && strchr("-+ #0'", *c))
            xl_append(&out, c++, 1);
        for (int part = 0; part < 2; part++) {
            if (part == 1) {
                if (*c != '.')
                    break;
                xl_append(&out, c++, 1);
            }
            if (*c == '*') {
                int32_t value = (int32_t)arguments[next++];
                xl_append(&args, &value, sizeof value);
                xl_append(&out, c++, 1);
            } else {
                while (*c >= '0' && *c <= '9')
                    xl_append(&out, c++, 1);
            }
            if (*c == '$') {
                fprintf(stderr, "xlate: %s: positional format arguments are not supported: %s\n", symbol, start);
                abort();
            }
        }
        int wide = 0, is_long_double = 0;
        for (;;) {
            if (*c == 'h') {
                c++;
            } else if (*c == 'l' || (!sqlite_dialect && (*c == 'q' || *c == 'z')) || *c == 'j' || *c == 't') {
                wide = 1;
                c++;
            } else if (*c == 'L') {
                is_long_double = 1;
                c++;
            } else {
                break;
            }
        }
        char conversion = *c ? *c++ : 0;
        switch (conversion) {
        case 'd': case 'i': case 'o': case 'u': case 'x': case 'X': case 'D': case 'O': case 'U': {
            if (wide) {
                int64_t value = (int64_t)arguments[next++];
                xl_append(&args, &value, sizeof value);
                xl_append(&out, "ll", 2);
            } else {
                int32_t value = (int32_t)arguments[next++];
                xl_append(&args, &value, sizeof value);
            }
            xl_append(&out, &conversion, 1);
            break;
        }
        case 'c': case 'C': {
            int32_t value = (int32_t)arguments[next++];
            xl_append(&args, &value, sizeof value);
            if (wide)
                xl_append(&out, "l", 1);
            xl_append(&out, &conversion, 1);
            break;
        }
        case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A': {
            double value;
            memcpy(&value, &arguments[next++], sizeof value);
            xl_append(&args, &value, sizeof value);
            (void)is_long_double;
            xl_append(&out, &conversion, 1);
            break;
        }
        case 'q': case 'Q': case 'w': case 'z':
            if (!sqlite_dialect) {
                fprintf(stderr, "xlate: %s: unsupported conversion in format \"%s\"\n", symbol, text);
                abort();
            }
        case 's': case 'S': case 'p': case '@': {
            if (conversion == '@' && !object_format) {
                fprintf(stderr, "xlate: %s: %%@ outside an object format\n", symbol);
                abort();
            }
            uint64_t value = arguments[next++];
            if (value >> 32) {
                fprintf(stderr, "xlate: %s: pointer argument 0x%llx above 4 GiB\n", symbol, value);
                abort();
            }
            uint32_t pointer = conversion == '@' ? (uint32_t)xl_object_in(value, symbol, next - 1) : (uint32_t)value;
            if (!pointer && (conversion == 's' || conversion == 'S')) {
                static const char null_utf8[] = "(null)";
                static const unsigned short null_utf16[] = {'(', 'n', 'u', 'l', 'l', ')', 0};
                static const unsigned int null_wide[] = {'(', 'n', 'u', 'l', 'l', ')', 0};
                pointer = (uint32_t)(uintptr_t)(conversion == 'S' ? (const void *)null_utf16
                                                : wide ? (const void *)null_wide : (const void *)null_utf8);
            }
            xl_append(&args, &pointer, sizeof pointer);
            if (wide && conversion == 's')
                xl_append(&out, "l", 1);
            xl_append(&out, &conversion, 1);
            break;
        }
        case 'm':
            xl_append(&out, "m", 1);
            break;
        default:
            fprintf(stderr, "xlate: %s: unsupported conversion in format \"%s\"\n", symbol, text);
            abort();
        }
    }
    xl_append(&args, "", 0);
    format->text = out.data;
    format->arguments = args.data;
    format->wide = NULL;
    format->object = object_format ? [[NSString alloc] initWithUTF8String:out.data] : NULL;
}

static char *xl_utf8_from_wide(const wchar_t *wide)
{
    size_t length = 0;
    while (wide[length])
        length++;
    char *out = malloc(length * 4 + 1), *at = out;
    for (size_t i = 0; i < length; i++) {
        uint32_t c = (uint32_t)wide[i];
        if (c < 0x80) {
            *at++ = (char)c;
        } else if (c < 0x800) {
            *at++ = (char)(0xC0 | c >> 6);
            *at++ = (char)(0x80 | (c & 0x3F));
        } else if (c < 0x10000) {
            *at++ = (char)(0xE0 | c >> 12);
            *at++ = (char)(0x80 | (c >> 6 & 0x3F));
            *at++ = (char)(0x80 | (c & 0x3F));
        } else {
            *at++ = (char)(0xF0 | c >> 18);
            *at++ = (char)(0x80 | (c >> 12 & 0x3F));
            *at++ = (char)(0x80 | (c >> 6 & 0x3F));
            *at++ = (char)(0x80 | (c & 0x3F));
        }
    }
    *at = 0;
    return out;
}

static wchar_t *xl_wide_from_utf8(const char *text)
{
    wchar_t *out = malloc((strlen(text) + 1) * sizeof *out), *at = out;
    for (const unsigned char *c = (const unsigned char *)text; *c;) {
        uint32_t value;
        unsigned extra;
        if (*c < 0x80) {
            value = *c;
            extra = 0;
        } else if (*c >= 0xF0) {
            value = *c & 0x07;
            extra = 3;
        } else if (*c >= 0xE0) {
            value = *c & 0x0F;
            extra = 2;
        } else {
            value = *c & 0x1F;
            extra = 1;
        }
        c++;
        while (extra-- && *c)
            value = value << 6 | (*c++ & 0x3F);
        *at++ = (wchar_t)value;
    }
    *at = 0;
    return out;
}

void xl_format_marshal_wide(struct xl_format *format, const wchar_t *text, void *object, const uint64_t *arguments, const char *symbol)
{
    char *narrow = xl_utf8_from_wide(text);
    xl_format_marshal(format, narrow, object, arguments, symbol);
    free(narrow);
    format->wide = xl_wide_from_utf8(format->text);
}

void xl_format_marshal_valist(struct xl_format *format, const char *text, void *object, uint64_t guest_valist, const char *symbol)
{
    xl_format_marshal(format, text, object, (const uint64_t *)(uintptr_t)guest_valist, symbol);
}

void xl_format_release(struct xl_format *format)
{
    [(NSString *)format->object release];
    free(format->text);
    free(format->arguments);
    free(format->wide);
}

enum { XL_SCANF_SIGNED, XL_SCANF_UNSIGNED, XL_SCANF_COUNT };

struct xl_scanf_fix {
    uint64_t guest;
    uint32_t value;
    unsigned index;
    unsigned kind;
};

static const uint32_t xl_scanf_untouched = 0xFFFFFFFFu;

void xl_scanf_marshal(struct xl_scanf *scan, const char *text, const uint64_t *arguments, const char *symbol)
{
    size_t conversions = 0;
    for (const char *c = text; *c; c++)
        conversions += *c == '%';
    uint32_t *words = calloc(conversions + 1, sizeof *words);
    struct xl_scanf_fix *fixes = calloc(conversions + 1, sizeof *fixes);
    unsigned used = 0, assigned = 0, fixed = 0;
    for (const char *c = text; *c;) {
        if (*c++ != '%')
            continue;
        if (*c == '%') {
            c++;
            continue;
        }
        int suppress = *c == '*';
        c += suppress;
        while (*c >= '0' && *c <= '9')
            c++;
        int narrow = 0, wide = 0, longs = 0;
        for (;; c++) {
            if (*c == 'h')
                narrow = 1;
            else if (*c == 'l')
                longs++;
            else if (*c == 'z' || *c == 't')
                wide = 1;
            else if (*c == 'j' || *c == 'q')
                wide = 2;
            else if (*c != 'L')
                break;
        }
        wide = longs > 1 ? 2 : (longs == 1 && !wide) ? 1 : wide;
        char conversion = *c ? *c++ : 0;
        if (conversion == '[') {
            c += *c == '^';
            c += *c == ']';
            while (*c && *c != ']')
                c++;
            c += *c == ']';
        }
        if (suppress)
            continue;
        int counted = conversion != 'n';
        unsigned kind = XL_SCANF_SIGNED;
        int integer = 0;
        switch (conversion) {
        case 'D': case 'O': case 'U':
            wide = 1;
        case 'd': case 'i': case 'u': case 'o': case 'x': case 'X': case 'n':
            integer = 1;
            kind = conversion == 'n' ? XL_SCANF_COUNT : (conversion == 'd' || conversion == 'i' || conversion == 'D') ? XL_SCANF_SIGNED : XL_SCANF_UNSIGNED;
            break;
        case 'p':
            integer = 1;
            wide = 1;
            kind = XL_SCANF_UNSIGNED;
            break;
        case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A':
        case 's': case 'S': case 'c': case 'C': case '[':
            break;
        default:
            fprintf(stderr, "xlate: %s: unsupported conversion in format \"%s\"\n", symbol, text);
            abort();
        }
        unsigned slot = used++;
        uint64_t guest = arguments[slot];
        if (wide == 1 && integer && !narrow) {
            struct xl_scanf_fix *fix = &fixes[fixed++];
            fix->guest = guest;
            fix->index = assigned;
            fix->kind = kind;
            fix->value = kind == XL_SCANF_COUNT ? xl_scanf_untouched : 0;
            words[slot] = (uint32_t)(uintptr_t)&fix->value;
        } else {
            words[slot] = (uint32_t)xl_narrow_pointer(guest, symbol, slot);
        }
        assigned += counted;
    }
    scan->arguments = (char *)words;
    scan->fixes = fixes;
    scan->count = fixed;
}

void xl_scanf_finish(struct xl_scanf *scan, int result)
{
    for (unsigned i = 0; i < scan->count; i++) {
        struct xl_scanf_fix *fix = &scan->fixes[i];
        int reached = fix->kind == XL_SCANF_COUNT ? fix->value != xl_scanf_untouched : result > (int)fix->index;
        if (!reached)
            continue;
        uint64_t *guest = (uint64_t *)(uintptr_t)fix->guest;
        *guest = fix->kind == XL_SCANF_UNSIGNED ? (uint64_t)fix->value : (uint64_t)(int64_t)(int32_t)fix->value;
    }
    free(scan->arguments);
    free(scan->fixes);
}

struct xl_guest_addrinfo {
    int32_t ai_flags;
    int32_t ai_family;
    int32_t ai_socktype;
    int32_t ai_protocol;
    uint32_t ai_addrlen;
    uint32_t reserved;
    uint64_t ai_canonname;
    uint64_t ai_addr;
    uint64_t ai_next;
};

struct xl_addrinfo_list {
    struct addrinfo *host;
    uint64_t magic;
    struct xl_guest_addrinfo nodes[];
};

static const uint64_t xl_addrinfo_magic = 0x6164647269696e66ull;

void xl_manual_getaddrinfo(void *pack)
{
    struct __attribute__((packed)) { uint64_t node, service, hints, result, r; } *p = pack;
    const struct xl_guest_addrinfo *guest_hints = (const struct xl_guest_addrinfo *)xl_narrow_pointer(p->hints, "getaddrinfo", 2);
    struct addrinfo hints, *request = NULL;
    if (guest_hints) {
        memset(&hints, 0, sizeof hints);
        hints.ai_flags = guest_hints->ai_flags;
        hints.ai_family = guest_hints->ai_family;
        hints.ai_socktype = guest_hints->ai_socktype;
        hints.ai_protocol = guest_hints->ai_protocol;
        request = &hints;
    }
    struct addrinfo *host = NULL;
    int status = getaddrinfo((const char *)xl_narrow_pointer(p->node, "getaddrinfo", 0),
                             (const char *)xl_narrow_pointer(p->service, "getaddrinfo", 1), request, &host);
    p->r = (uint64_t)(int64_t)status;
    if (status)
        return;
    size_t count = 0;
    for (struct addrinfo *node = host; node; node = node->ai_next)
        count++;
    struct xl_addrinfo_list *list = calloc(1, sizeof *list + count * sizeof list->nodes[0]);
    if (!list) {
        freeaddrinfo(host);
        p->r = (uint64_t)(int64_t)EAI_MEMORY;
        return;
    }
    list->host = host;
    list->magic = xl_addrinfo_magic;
    size_t at = 0;
    for (struct addrinfo *node = host; node; node = node->ai_next, at++) {
        struct xl_guest_addrinfo *guest = &list->nodes[at];
        guest->ai_flags = node->ai_flags;
        guest->ai_family = node->ai_family;
        guest->ai_socktype = node->ai_socktype;
        guest->ai_protocol = node->ai_protocol;
        guest->ai_addrlen = node->ai_addrlen;
        guest->ai_canonname = (uintptr_t)node->ai_canonname;
        guest->ai_addr = (uintptr_t)node->ai_addr;
        guest->ai_next = node->ai_next ? (uintptr_t)&list->nodes[at + 1] : 0;
    }
    *(uint64_t *)xl_narrow_pointer(p->result, "getaddrinfo", 3) = (uintptr_t)list->nodes;
}

void xl_manual_freeaddrinfo(void *pack)
{
    struct __attribute__((packed)) { uint64_t head; } *p = pack;
    if (!p->head)
        return;
    struct xl_addrinfo_list *list = (struct xl_addrinfo_list *)((char *)xl_narrow_pointer(p->head, "freeaddrinfo", 0) - offsetof(struct xl_addrinfo_list, nodes));
    if (list->magic != xl_addrinfo_magic)
        xl_unsupported("xlate: freeaddrinfo of a list that getaddrinfo did not return");
    freeaddrinfo(list->host);
    free(list);
}

#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_var.h>
#include <xlocale.h>
#include <locale.h>
#include <crt_externs.h>
#include <sys/mman.h>
#include <mach/mach.h>
#include <objc/runtime.h>
#include <CoreGraphics/CoreGraphics.h>

Class xl_class_in(uint64_t guest);

struct xl_keyed {
    pthread_mutex_t lock;
    CFMutableDictionaryRef blocks;
};

static void *xl_keyed_block(struct xl_keyed *keyed, const void *key, size_t size)
{
    pthread_mutex_lock(&keyed->lock);
    if (!keyed->blocks)
        keyed->blocks = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    uint64_t *block = (uint64_t *)CFDictionaryGetValue(keyed->blocks, key);
    if (!block || block[0] < size) {
        block = realloc(block, 16 + size);
        if (block) {
            block[0] = size;
            CFDictionarySetValue(keyed->blocks, key, block);
        }
    }
    pthread_mutex_unlock(&keyed->lock);
    return block ? (char *)block + 16 : NULL;
}

static struct xl_keyed xl_color_components = {PTHREAD_MUTEX_INITIALIZER, NULL};
static struct xl_keyed xl_locale_conventions = {PTHREAD_MUTEX_INITIALIZER, NULL};

static void xl_guest_doubles(CGFloat *host, const void *guest, size_t count)
{
    for (size_t i = 0; i < count; i++) {
        double value;
        memcpy(&value, (const char *)guest + i * sizeof value, sizeof value);
        host[i] = (CGFloat)value;
    }
}

void xl_manual_CGColorCreate(void *pack)
{
    struct __attribute__((packed)) { uint64_t space, components, r; } *p = pack;
    CGColorSpaceRef space = (CGColorSpaceRef)xl_narrow_pointer(p->space, "CGColorCreate", 0);
    const void *guest = (const void *)xl_narrow_pointer(p->components, "CGColorCreate", 1);
    size_t count = space ? CGColorSpaceGetNumberOfComponents(space) + 1 : 0;
    CGFloat host[count ? count : 1];
    if (guest)
        xl_guest_doubles(host, guest, count);
    p->r = xl_widen_pointer((uintptr_t)CGColorCreate(space, guest && count ? host : NULL));
}

void xl_manual_CGColorGetComponents(void *pack)
{
    struct __attribute__((packed)) { uint64_t color, r; } *p = pack;
    CGColorRef color = (CGColorRef)xl_narrow_pointer(p->color, "CGColorGetComponents", 0);
    const CGFloat *host = color ? CGColorGetComponents(color) : NULL;
    p->r = 0;
    if (!host)
        return;
    size_t count = CGColorGetNumberOfComponents(color);
    double *guest = xl_keyed_block(&xl_color_components, color, count * sizeof *guest);
    if (!guest)
        xl_unsupported("xlate: CGColorGetComponents: out of memory");
    for (size_t i = 0; i < count; i++)
        guest[i] = host[i];
    p->r = xl_widen_pointer((uintptr_t)guest);
}

void xl_manual_CGImageCreateWithMaskingColors(void *pack)
{
    struct __attribute__((packed)) { uint64_t image, components, r; } *p = pack;
    CGImageRef image = (CGImageRef)xl_narrow_pointer(p->image, "CGImageCreateWithMaskingColors", 0);
    const void *guest = (const void *)xl_narrow_pointer(p->components, "CGImageCreateWithMaskingColors", 1);
    CGColorSpaceRef space = image ? CGImageGetColorSpace(image) : NULL;
    size_t count = space ? CGColorSpaceGetNumberOfComponents(space) * 2 : 0;
    CGFloat host[count ? count : 1];
    if (guest)
        xl_guest_doubles(host, guest, count);
    p->r = xl_widen_pointer((uintptr_t)CGImageCreateWithMaskingColors(image, guest && count ? host : NULL));
}

static pthread_once_t xl_argv_once = PTHREAD_ONCE_INIT;
static uint64_t *xl_guest_argv_slot;

static void xl_build_guest_argv(void)
{
    int argc = *_NSGetArgc();
    char **argv = *_NSGetArgv();
    uint64_t *table = calloc((size_t)argc + 1, sizeof *table);
    for (int i = 0; i < argc; i++)
        table[i] = xl_widen_pointer((uintptr_t)argv[i]);
    xl_guest_argv_slot = calloc(1, sizeof *xl_guest_argv_slot);
    *xl_guest_argv_slot = (uintptr_t)table;
}

void xl_manual__NSGetArgv(void *pack)
{
    struct __attribute__((packed)) { uint64_t r; } *p = pack;
    pthread_once(&xl_argv_once, xl_build_guest_argv);
    p->r = (uintptr_t)xl_guest_argv_slot;
}

struct xl_guest_ifaddrs {
    uint64_t ifa_next;
    uint64_t ifa_name;
    uint32_t ifa_flags;
    uint32_t reserved;
    uint64_t ifa_addr;
    uint64_t ifa_netmask;
    uint64_t ifa_dstaddr;
    uint64_t ifa_data;
};

struct xl_guest_if_data {
    uint8_t head[72];
    int64_t tv_sec;
    int32_t tv_usec;
    int32_t padding;
    uint32_t tail[4];
};

_Static_assert(offsetof(struct xl_guest_ifaddrs, ifa_flags) == 16 && offsetof(struct xl_guest_ifaddrs, ifa_addr) == 24 &&
               offsetof(struct xl_guest_ifaddrs, ifa_data) == 48, "arm64 struct ifaddrs");
_Static_assert(offsetof(struct if_data, ifi_lastchange) == 72 && sizeof(struct timeval) == 8 &&
               offsetof(struct if_data, ifi_unused2) == 80 && sizeof(struct if_data) == 96, "armv7 struct if_data");
_Static_assert(offsetof(struct xl_guest_if_data, tail) == 88 && offsetof(struct xl_guest_if_data, tv_sec) == 72, "arm64 struct if_data");

struct xl_ifaddrs_list {
    struct ifaddrs *host;
    uint64_t magic;
    size_t count;
    struct xl_guest_ifaddrs nodes[];
};

static const uint64_t xl_ifaddrs_magic = 0x6966616464727321ull;

void xl_manual_getifaddrs(void *pack)
{
    struct __attribute__((packed)) { uint64_t result, r; } *p = pack;
    struct ifaddrs *host = NULL;
    int status = getifaddrs(&host);
    p->r = (uint64_t)(int64_t)status;
    if (status)
        return;
    size_t count = 0;
    for (struct ifaddrs *node = host; node; node = node->ifa_next)
        count++;
    struct xl_ifaddrs_list *list = calloc(1, sizeof *list + count * (sizeof(struct xl_guest_ifaddrs) + sizeof(struct xl_guest_if_data)));
    if (!list) {
        freeifaddrs(host);
        errno = ENOMEM;
        p->r = (uint64_t)(int64_t)-1;
        return;
    }
    list->host = host;
    list->magic = xl_ifaddrs_magic;
    list->count = count;
    struct xl_guest_if_data *data = (struct xl_guest_if_data *)&list->nodes[count];
    size_t at = 0;
    for (struct ifaddrs *node = host; node; node = node->ifa_next, at++) {
        struct xl_guest_ifaddrs *guest = &list->nodes[at];
        guest->ifa_next = node->ifa_next ? (uintptr_t)&list->nodes[at + 1] : 0;
        guest->ifa_name = xl_widen_pointer((uintptr_t)node->ifa_name);
        guest->ifa_flags = node->ifa_flags;
        guest->ifa_addr = xl_widen_pointer((uintptr_t)node->ifa_addr);
        guest->ifa_netmask = xl_widen_pointer((uintptr_t)node->ifa_netmask);
        guest->ifa_dstaddr = xl_widen_pointer((uintptr_t)node->ifa_dstaddr);
        if (node->ifa_data && node->ifa_addr && node->ifa_addr->sa_family == AF_LINK) {
            const struct if_data *source = node->ifa_data;
            struct xl_guest_if_data *copy = &data[at];
            memcpy(copy->head, source, offsetof(struct if_data, ifi_lastchange));
            copy->tv_sec = source->ifi_lastchange.tv_sec;
            copy->tv_usec = source->ifi_lastchange.tv_usec;
            memcpy(copy->tail, &source->ifi_unused2, sizeof copy->tail);
            guest->ifa_data = (uintptr_t)copy;
        } else {
            guest->ifa_data = xl_widen_pointer((uintptr_t)node->ifa_data);
        }
    }
    *(uint64_t *)xl_narrow_pointer(p->result, "getifaddrs", 0) = (uintptr_t)list->nodes;
}

void xl_manual_freeifaddrs(void *pack)
{
    struct __attribute__((packed)) { uint64_t head; } *p = pack;
    if (!p->head)
        return;
    struct xl_ifaddrs_list *list = (struct xl_ifaddrs_list *)((char *)xl_narrow_pointer(p->head, "freeifaddrs", 0) - offsetof(struct xl_ifaddrs_list, nodes));
    if (list->magic != xl_ifaddrs_magic)
        xl_unsupported("xlate: freeifaddrs of a list that getifaddrs did not return");
    freeifaddrs(list->host);
    free(list);
}

struct xl_guest_servent {
    uint64_t s_name;
    uint64_t s_aliases;
    int32_t s_port;
    int32_t padding;
    uint64_t s_proto;
};

_Static_assert(offsetof(struct xl_guest_servent, s_port) == 16 && offsetof(struct xl_guest_servent, s_proto) == 24, "arm64 struct servent");

static pthread_once_t xl_servent_once = PTHREAD_ONCE_INIT;
static pthread_key_t xl_servent_key;

static void xl_servent_make_key(void)
{
    pthread_key_create(&xl_servent_key, free);
}

void xl_manual_getservbyname(void *pack)
{
    struct __attribute__((packed)) { uint64_t name, protocol, r; } *p = pack;
    struct servent *host = getservbyname((const char *)xl_narrow_pointer(p->name, "getservbyname", 0),
                                         (const char *)xl_narrow_pointer(p->protocol, "getservbyname", 1));
    p->r = 0;
    if (!host)
        return;
    size_t aliases = 0;
    while (host->s_aliases && host->s_aliases[aliases])
        aliases++;
    pthread_once(&xl_servent_once, xl_servent_make_key);
    free(pthread_getspecific(xl_servent_key));
    struct xl_guest_servent *guest = calloc(1, sizeof *guest + (aliases + 1) * sizeof(uint64_t));
    if (!guest)
        xl_unsupported("xlate: getservbyname: out of memory");
    pthread_setspecific(xl_servent_key, guest);
    uint64_t *list = (uint64_t *)(guest + 1);
    for (size_t i = 0; i < aliases; i++)
        list[i] = xl_widen_pointer((uintptr_t)host->s_aliases[i]);
    guest->s_name = xl_widen_pointer((uintptr_t)host->s_name);
    guest->s_aliases = (uintptr_t)list;
    guest->s_port = host->s_port;
    guest->s_proto = xl_widen_pointer((uintptr_t)host->s_proto);
    p->r = (uintptr_t)guest;
}

struct xl_guest_lconv {
    uint64_t strings[10];
    char numbers[14];
};

_Static_assert(offsetof(struct lconv, int_n_sign_posn) - offsetof(struct lconv, int_frac_digits) == 13, "struct lconv numbers");

void xl_manual_localeconv_l(void *pack)
{
    struct __attribute__((packed)) { uint64_t locale, r; } *p = pack;
    locale_t locale = (locale_t)xl_narrow_pointer(p->locale, "localeconv_l", 0);
    struct lconv *host = localeconv_l(locale);
    p->r = 0;
    if (!host)
        return;
    struct xl_guest_lconv *guest = xl_keyed_block(&xl_locale_conventions, locale, sizeof *guest);
    if (!guest)
        xl_unsupported("xlate: localeconv_l: out of memory");
    char *const *strings = &host->decimal_point;
    for (unsigned i = 0; i < 10; i++)
        guest->strings[i] = xl_widen_pointer((uintptr_t)strings[i]);
    memcpy(guest->numbers, &host->int_frac_digits, sizeof guest->numbers);
    p->r = (uintptr_t)guest;
}

void xl_manual_class_copyIvarList(void *pack)
{
    struct __attribute__((packed)) { uint64_t cls, count, r; } *p = pack;
    unsigned count = 0;
    Ivar *ivars = class_copyIvarList(xl_class_in(xl_narrow_pointer(p->cls, "class_copyIvarList", 0)), &count);
    uint64_t *guest = NULL;
    if (ivars) {
        guest = malloc(((size_t)count + 1) * sizeof *guest);
        if (!guest)
            xl_unsupported("xlate: class_copyIvarList: out of memory");
        for (unsigned i = 0; i < count; i++)
            guest[i] = xl_widen_pointer((uintptr_t)ivars[i]);
        guest[count] = 0;
        free(ivars);
    }
    p->r = (uintptr_t)guest;
    if (p->count)
        *(unsigned *)xl_narrow_pointer(p->count, "class_copyIvarList", 1) = count;
}

void xl_manual_data_deallocator(void *pack)
{
    struct __attribute__((packed)) { uint64_t kind, bytes, length; } *p = pack;
    void *bytes = (void *)xl_narrow_pointer(p->bytes, "NSDataDeallocator", 1);
    if (p->length >> 32)
        xl_unsupported("xlate: NSDataDeallocator: a length above 4 GiB");
    switch (p->kind) {
    case 0:
        free(bytes);
        break;
    case 1:
        munmap(bytes, (size_t)p->length);
        break;
    default:
        vm_deallocate(mach_task_self(), (vm_address_t)bytes, (vm_size_t)p->length);
        break;
    }
}
