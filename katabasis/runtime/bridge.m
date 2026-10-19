#import <Foundation/Foundation.h>

#include "xl_bridge.h"

State *xl_current_state(void);

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
#include <mach-o/loader.h>

// kevent's changelist and eventlist are arrays of struct kevent sized by nchanges/nevents, and
// struct kevent's layout differs between the arm64 guest (8-byte ident/data/udata, 32 bytes total)
// and the armv7 host (4-byte, 20 bytes). The generated bridge marshals only the first element, so a
// call registering more than one change (Realm's commit listener adds two EVFILT_READ filters at
// once) passes garbage for the rest and the registration fails. Marshal every element by hand.
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
// Mirror fatal diagnostics into the crash-log file too: under SpringBoard stderr goes to a
// console we cannot fetch, so a trap's message (which symbol) would otherwise be lost.
static void xl_diag(const char *line)
{
    int fd = open("/private/var/charon/xlate-crash.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd >= 0) { dprintf(fd, "%s", line); close(fd); }
}

// libswiftCore's own initializer (ImageInspectionMachO.cpp's swift::initializeProtocolLookup,
// initializeTypeMetadataRecordLookup, ...) registers a dyld add-image callback to learn every
// loaded image's __swift5_proto/__swift5_types/__swift5_protos sections -- how Swift resolves a
// generic type's conditional conformances (Dictionary<Key, Value> needing Key: Hashable) and
// dynamic casts (`as? SomeProtocol`) at run time. _dyld_register_func_for_add_image is not
// something xlgen bridges (a lifted call to it resolves straight through to the real host
// libSystem symbol, an ordinary import); measured live on device (a temporary logging override,
// since reverted) that the callback DOES fire once per HOST image -- the translated executable
// itself, then every real armv7 dylib it links -- and NEVER for any of the four guest images
// (app, libswiftCore, libc++, libc++abi), which this recompiler merges into that one host
// executable ahead of time and never "loads" the way dyld loads a dylib. So the __swift5_*
// sections that exist -- in the ORIGINAL guest dylibs, copied byte for byte into the translated
// binary by EmitGuestData (xlate/src/xlate.cpp) -- are never seen by anything that walks them by
// asking dyld what is loaded: Swift's own conformance/type-metadata tables come up empty, and any
// runtime instantiation needing one (e.g. _DictionaryStorage<String, Int>.allocate, which needs
// String's Hashable witness) returns null.
//
// This overrides the real _dyld_register_func_for_add_image (a strong definition of the exact
// same external name wins over libSystem's for every caller linked into this executable: ordinary
// Mach-O local-symbol-first resolution, not an interposition trick) to hand the registered
// callback each guest image's REAL Mach-O header -- xlate/src/xlate.cpp's WriteStateHeader
// generates xl_guest_images[] from the exact host addresses EmitGuestData placed each image's
// __TEXT (header included) at, with the slide (Image::slide()) that relates it back to the
// addresses its own load commands were written against -- exactly as dyld would for an image
// already loaded when the registration call is made (which, for this recompiler, is always: every
// guest image exists from process start). getsectiondata (xlgen.cpp's manual bridge for it)
// already recognizes a 64-bit (guest) mach_header and walks ITS OWN load commands rather than the
// host's, so once Swift's callback is handed one of these, its usual getsectiondata(mh, "__TEXT",
// "__swift5_types", &size) calls resolve to the real guest section data, translated-address slide
// and all -- no further change needed there.
//
// Host images still go through the real host dyld (forwarded via dlsym(RTLD_NEXT, ...)): measured
// that Swift's callback DOES get called for those today (unchanged, harmless -- none of this
// target's host frameworks carry __swift5_* sections, the same as any non-Swift dylib on a real
// device), and forwarding keeps that path exactly as a real app's would behave, including for
// anything dlopen'd later. _dyld_register_func_for_remove_image is not bridged: measured
// (nm -u libswiftCore.dylib) that libswiftCore never imports it, so there is nothing to feed.
void _dyld_register_func_for_add_image(void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
#ifndef XL_TEST_NO_DYLD_IMAGE_BRIDGE
    // XL_TEST_NO_DYLD_IMAGE_BRIDGE: corpus/swiftconformance's own control build defines this to
    // compile a variant with exactly this loop compiled out, everything else unchanged, so its
    // check.sh can compare a build with the bridge against one without it -- not a runtime
    // feature flag, nothing sets this outside that one fixture's own scripts/translate.sh
    // invocation (XL_EXTRA_CFLAGS).
    for (unsigned i = 0; i < xl_guest_image_count; i++) {
        func((const struct mach_header *)xl_guest_images[i].header, xl_guest_images[i].slide);
    }
#endif
    void (*real)(void (*)(const struct mach_header *, intptr_t)) =
        (void (*)(void (*)(const struct mach_header *, intptr_t)))
        dlsym(RTLD_NEXT, "_dyld_register_func_for_add_image");
    if (real) {
        real(func);
    }
}

// openat and the rest of the *at family arrived after iOS 6, so emulate openat: an absolute path
// (or AT_FDCWD) is a plain open; a relative path is resolved against the directory fd's own path,
// recovered with F_GETPATH. This covers what a translated app's file I/O needs without the syscall.
int xl_shim_openat(int dirfd, const char *path, int flags, int mode)
{
    static int trace = -1;
    if (trace < 0)
        trace = access("/private/var/charon/xl-trace-errno", F_OK) == 0;
    if (trace && (flags & O_CREAT)) {
        int fd = open("/private/var/charon/xl-errno.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
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

// The *at family (mkdirat, unlinkat, fstatat, renameat, symlinkat, readlinkat, fchmodat, fchownat, linkat,
// faccessat, fdopendir) arrived in iOS 8, so on iOS 6 the symbols do not exist and an app that calls one (iSH's
// filesystem layer uses all of them) halts in dyld at the first call. Emulate each the way xl_shim_openat does:
// an absolute path, or AT_FDCWD, is the plain call; a relative path is resolved against the directory fd's own
// path (F_GETPATH) first.
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
int xl_shim_unlinkat(int fd, const char *path, int flag) { XL_AT(fd, path, (flag & 0x0080 /* AT_REMOVEDIR */) ? rmdir(full_) : unlink(full_)); }
int xl_shim_fstatat(int fd, const char *path, struct stat *st, int flag) { XL_AT(fd, path, (flag & 0x0020 /* AT_SYMLINK_NOFOLLOW */) ? lstat(full_, st) : stat(full_, st)); }
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

// fdopendir: a DIR from an open directory fd -- reopen the fd's own path (F_GETPATH) and give the original fd back
// to the caller's ownership rules by closing it, as fdopendir would consume it.
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

// utimensat(fd, path, const struct timespec times[2], flag): the times are an ARRAY of two guest timespecs
// (16 bytes each), which the generic bridge would marshal one element of. UTIME_NOW = -1, UTIME_OMIT = -2 in
// tv_nsec; an omitted time keeps the file's current one.
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

// readdir: iOS 6's struct dirent has a 32-bit inode (d_ino, d_reclen, d_type, d_namlen, d_name[256]), the arm64
// one the 64-bit form (d_ino, d_seekoff, d_reclen, d_namlen, d_type, d_name[1024]) -- the layouts genuinely
// differ, so convert each entry into a per-thread guest-layout buffer (valid until the next readdir, which is all
// POSIX promises). The DIR* itself is an opaque host handle passed through unchanged.
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

// signal(): returns the previous handler -- a function pointer, which the generic bridge cannot represent.
// SIG_DFL (0), SIG_IGN (1) and SIG_ERR (-1) pass straight through. A real guest handler cannot run as a host
// signal handler (it is translated guest code), so it is not installed and the request is logged; the previous
// disposition is reported as SIG_DFL.
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

// The exec family: argv and envp are arrays of the guest's 8-byte pointers where the host's are 4 bytes wide, so each
// vector is narrowed into a host array. exec returns only when it fails, with errno set; the arrays are freed with errno
// kept. The list forms (execl, execle, execlp) collect their arguments in guest code (xlgen) and arrive here as vectors.
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

// SQLite's 64-bit entry points (bind_blob64/bind_text64/malloc64/realloc64, SQLite 3.8.7+) are absent from iOS 6's
// libsqlite3, so a call halts in dyld. Each is the 32-bit function with a wider length: forward, and refuse a length
// beyond INT_MAX as the real one does (SQLITE_TOOBIG) -- running a destructor the caller handed over, as SQLite does.
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
    if (encoding == SQLITE_UTF16 || encoding == 3 /* SQLITE_UTF16LE */ || encoding == 4 /* SQLITE_UTF16BE */)
        return sqlite3_bind_text16(stmt, index, data, (int)n, destructor);
    return sqlite3_bind_text(stmt, index, data, (int)n, destructor);
}

void *xl_shim_sqlite3_malloc64(unsigned long long n) { return n > 0x7fffffffULL ? NULL : sqlite3_malloc((int)n); }
void *xl_shim_sqlite3_realloc64(void *p, unsigned long long n) { return n > 0x7fffffffULL ? NULL : sqlite3_realloc(p, (int)n); }

// Failure trace for bridged libc calls (flag file /private/var/charon/xl-trace-errno; called from every generated
// signed-integer-returning bridge): when the call returned -1, log "name errno=N first-arg [path]" to xl-errno.log.
void xl_errno_trace(const char *name, int64_t result, uint64_t first_argument, uint64_t second_argument)
{
    if (result != -1)
        return;
    int saved = errno;
    static int enabled = -1;
    if (enabled < 0)
        enabled = access("/private/var/charon/xl-trace-errno", F_OK) == 0;
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
        int fd = open("/private/var/charon/xl-errno.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
        if (fd >= 0) {
            dprintf(fd, "%s errno=%d a0=0x%llx [%s] a1=0x%llx [%s]\n", name, saved, (unsigned long long)first_argument, text[0],
                    (unsigned long long)second_argument, text[1]);
            close(fd);
        }
    }
    errno = saved;
}

// CCRandomGenerateBytes (CommonCrypto, iOS 8+) is absent from iOS 6 -- the first call halts dyld. arc4random_buf is
// the same thing (a cryptographically strong generator) and exists on iOS 6; kCCSuccess is 0.
int xl_shim_CCRandomGenerateBytes(void *bytes, size_t count)
{
    if (!bytes && count)
        return -4300; /* kCCRNGFailure */
    arc4random_buf(bytes, count);
    return 0;
}

// clock_gettime / clock_getres (POSIX clocks) arrived in iOS 10; on iOS 6 the symbols do not exist and the first call halts
// dyld. Map the Darwin clock ids onto what iOS 6 has: wall clock from gettimeofday, the monotonic/uptime clocks from
// mach_absolute_time, CPU-time clocks from getrusage.
#include <mach/mach_time.h>
#include <sys/resource.h>
int xl_shim_clock_gettime(int clock_id, struct timespec *ts)
{
    if (!ts) { errno = EFAULT; return -1; }
    switch (clock_id) {
    case 0: { /* CLOCK_REALTIME */
        struct timeval tv;
        gettimeofday(&tv, NULL);
        ts->tv_sec = tv.tv_sec;
        ts->tv_nsec = (long)tv.tv_usec * 1000;
        return 0;
    }
    case 4: /* CLOCK_MONOTONIC_RAW */
    case 6: /* CLOCK_MONOTONIC */
    case 8: /* CLOCK_UPTIME_RAW */
    case 5: /* CLOCK_MONOTONIC_RAW_APPROX */
    case 9: /* CLOCK_UPTIME_RAW_APPROX */ {
        static mach_timebase_info_data_t base;
        if (!base.denom)
            mach_timebase_info(&base);
        uint64_t ns = mach_absolute_time() * base.numer / base.denom;
        ts->tv_sec = (time_t)(ns / 1000000000ULL);
        ts->tv_nsec = (long)(ns % 1000000000ULL);
        return 0;
    }
    case 12: /* CLOCK_PROCESS_CPUTIME_ID */
    case 16: /* CLOCK_THREAD_CPUTIME_ID */ {
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
    if (ts) { ts->tv_sec = 0; ts->tv_nsec = 1000; } /* microsecond granularity at worst */
    return 0;
}

// Functions newer than iOS 6 that Zebra's dependencies reference (found with the device-side symbol probe):
// __exp10 is 10^x; sqlite3_prepare_v3 is prepare_v2 plus flags (hints only); CGImageGetUTType (iOS 9) has no iOS 6
// equivalent, so an unknown type (NULL) is the honest answer; CGImageSourceRemoveCacheAtIndex only drops a cache.
#include <math.h>
double xl_shim_exp10(double x) { return pow(10.0, x); }
int xl_shim_sqlite3_prepare_v3(sqlite3 *db, const char *sql, int n, unsigned int flags, sqlite3_stmt **stmt, const char **tail)
{
    (void)flags;
    return sqlite3_prepare_v2(db, sql, n, stmt, tail);
}
const void *xl_shim_CGImageGetUTType(void *image) { (void)image; return NULL; }
void xl_shim_CGImageSourceRemoveCacheAtIndex(void *source, size_t index) { (void)source; (void)index; }

// Typed memory operations (iOS 16 / macOS 13): the type-id is only an allocator hint for
// heap partitioning, so dropping it and calling the plain allocator is always correct.
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

// zlib. A guest z_stream (arm64: 112 bytes, 8-byte pointers and uLong) cannot be handed to the host's armv7
// zlib (56 bytes), and zlib keeps a back-pointer to the stream inside its internal state, so marshalling the
// struct by copy (a fresh temporary per call) makes every inflate/deflate after init fail its state check.
// Instead each guest stream owns ONE persistent host z_stream (its address kept in the guest struct's own
// `state` field, which the guest never touches); every call copies the guest's in/out fields to it, calls the
// real zlib, and copies the results back. The guest's zalloc/zfree/opaque are ignored (host allocators).
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

// Allocate the mirror, run the host init (given as a callback), and publish it through g->state.
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

// __assert_rtn: every failed assert() in a guest lands here. Under SpringBoard stderr goes nowhere we can fetch, so
// write the assertion (expression, function, file, line) to the crash log before aborting -- otherwise an app's own
// consistency check fails with no explanation.
void xl_manual___assert_rtn(void *pack)
{
    struct __attribute__((packed)) { uint64_t func, file, line, expr, r; } *p = pack;
    char line[600];
    snprintf(line, sizeof line, "xlate: assertion failed: (%s), function %s, file %s, line %d\n",
             (const char *)xl_narrow_pointer(p->expr, "__assert_rtn", 3), (const char *)xl_narrow_pointer(p->func, "__assert_rtn", 0),
             (const char *)xl_narrow_pointer(p->file, "__assert_rtn", 1), (int)p->line);
    fputs(line, stderr);
    xl_diag(line);
    // The values an assertion tested are usually in the caller's frame: dump the printable bytes just above the
    // guest stack pointer (non-printables as '.') so a failing string check shows the string.
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

// exit()/_exit(): an app that gives up (an unrecoverable startup error) leaves no crash and no message, so a run that
// simply vanishes is undiagnosable. Log the status and the guest call chain to the crash log first.
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

// __cxa_atexit(func, arg, dso): a translated app's C++ static initializers register their
// destructors here. The destructor is guest code, so we cannot hand its address to the
// host C++ runtime (which would call it with the host ABI); we record (func, arg) and run
// them ourselves, newest first, through xl_invoke at process exit. On iOS the app is
// usually killed rather than exited cleanly, so these seldom run -- matching the platform.
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

// C++ ABI operator new/delete -> host allocator. The returned host-heap pointer is within
// the process, so guest code uses it directly; new[]/delete[] share the same allocation.
struct xl_alloc_pack { uint64_t a0, r; } __attribute__((packed));
void xl_manual__Znwm(void *pack) { struct xl_alloc_pack *p = pack; p->r = (uint64_t)(uintptr_t)malloc((size_t)p->a0); }
void xl_manual__Znam(void *pack) { struct xl_alloc_pack *p = pack; p->r = (uint64_t)(uintptr_t)malloc((size_t)p->a0); }
void xl_manual__ZdlPv(void *pack) { struct xl_alloc_pack *p = pack; free((void *)(uintptr_t)p->a0); }
void xl_manual__ZdaPv(void *pack) { struct xl_alloc_pack *p = pack; free((void *)(uintptr_t)p->a0); }

// NSGetUncaughtExceptionHandler returns a function pointer (unbridgeable result). A fresh
// process has no guest-installed handler, so return NULL; the runtime's own uncaught handler
// remains in effect.
void xl_manual_NSGetUncaughtExceptionHandler(void *pack) { struct { uint64_t r; } *p = pack; p->r = 0; }

// Thread-local storage. xlate emits xl_tlv_regions (one per guest image with __thread_vars): the
// address range of that image's TLV descriptors and its per-thread template (the __thread_data
// initial bytes at data_start for data_size, followed by data_size..total_size zero-filled). A
// TLV access calls _tlv_bootstrap(descriptor); we find the owning region, lazily allocate this
// thread's block for that region (a pthread_key per region frees it at thread exit), and return
// block + the descriptor's offset (its 3rd 64-bit word). The block is host-heap memory, usable by
// guest code directly. This is the recompiler's stand-in for the arm64 TLV support dyld lacks here.
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
    // SQLite's printf is its own dialect: %q/%Q/%w/%z are string conversions (quote-escaped, NULL-as-NULL,
    // identifier-escaped, freed-after), NOT the C length modifiers 'q'/'z'.
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
            /* fall through: a SQLite string conversion is a pointer argument */
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
            uint32_t pointer = (uint32_t)value;
            // Modern Foundation/libc print "(null)" for a NULL %s/%S argument; iOS 6's CoreFoundation dereferences
            // it (a null-pointer SIGSEGV inside strlen), and the guest was written against the modern behaviour.
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
    format->object = object_format ? [[NSString alloc] initWithUTF8String:out.data] : NULL;
}

// On Apple's arm64 ABI every variadic argument is passed on the stack and va_list is a plain
// pointer to those contiguous 8-byte slots — the same shape the variadic bridge already spills
// — so a guest va_list marshals exactly like the flat argument array. (This differs from the
// AAPCS64 register-save-area va_list used on other platforms.)
void xl_format_marshal_valist(struct xl_format *format, const char *text, void *object, uint64_t guest_valist, const char *symbol)
{
    xl_format_marshal(format, text, object, (const uint64_t *)(uintptr_t)guest_valist, symbol);
}

void xl_format_release(struct xl_format *format)
{
    [(NSString *)format->object release];
    free(format->text);
    free(format->arguments);
}
