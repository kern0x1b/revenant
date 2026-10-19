// common-includes.h -- the libSystem / standard C surface every app's own includes header should
// pull in. xlgen can only bridge a C function it has seen a declaration for; without these an app
// that calls, say, readdir or crc32 leaves it unbridged (a trap at runtime) purely because its
// header was missing. All of these are present on iOS 6 (or resolve at link against libSystem/libz/
// libsqlite3), so bridging them is safe -- absence is handled separately by the weaken/shim paths.
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <errno.h>
#include <time.h>
#include <ctype.h>
#include <pthread.h>
#include <semaphore.h>
#include <termios.h>
#include <syslog.h>
#include <poll.h>
#include <dirent.h>
#include <libgen.h>
#include <spawn.h>
#include <wchar.h>
#include <wctype.h>
#include <langinfo.h>
#include <iconv.h>
#include <zlib.h>
#include <sqlite3.h>
#include <resolv.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <sys/event.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonRandom.h>
#include <objc/runtime.h>
#include <objc/objc-sync.h>

// The _FORTIFY_SOURCE object-size checkers. Code compiled with fortify (most App Store binaries)
// emits calls to these, but their prototypes live in <secure/*.h> behind _FORTIFY_SOURCE > 0, and
// the bridge is generated with fortify off -- so without explicit declarations they are unbridged.
// The non-variadic ones bridge directly; the v*printf_chk variants still need a va_list bridge.
#include <stdarg.h>
extern void *__memcpy_chk(void *, const void *, __SIZE_TYPE__, __SIZE_TYPE__);
extern void *__memmove_chk(void *, const void *, __SIZE_TYPE__, __SIZE_TYPE__);
extern void *__memset_chk(void *, int, __SIZE_TYPE__, __SIZE_TYPE__);
extern char *__strcpy_chk(char *, const char *, __SIZE_TYPE__);
extern char *__strcat_chk(char *, const char *, __SIZE_TYPE__);
extern __SIZE_TYPE__ __strlcpy_chk(char *, const char *, __SIZE_TYPE__, __SIZE_TYPE__);
extern __SIZE_TYPE__ __strlcat_chk(char *, const char *, __SIZE_TYPE__, __SIZE_TYPE__);
extern char *__strncpy_chk(char *, const char *, __SIZE_TYPE__, __SIZE_TYPE__);
extern char *__strncat_chk(char *, const char *, __SIZE_TYPE__, __SIZE_TYPE__);

// Typed memory operations (TMO): iOS 16 / macOS 13 libmalloc entry points that a recent
// toolchain emits with -ftyped-memory-operations (the default, paired with the typed
// operator new in libc++abi). They are absent on iOS 6, so declaring them here only gives
// xlgen a signature to bridge -- translate.sh's shim_callee then routes each to a runtime
// xl_shim_* that drops the type-id hint and calls the plain allocator, which IS on iOS 6.
typedef unsigned long long malloc_type_id_t;
extern void *malloc_type_malloc(__SIZE_TYPE__ size, malloc_type_id_t type_id);
extern void *malloc_type_calloc(__SIZE_TYPE__ count, __SIZE_TYPE__ size, malloc_type_id_t type_id);
extern void *malloc_type_realloc(void *ptr, __SIZE_TYPE__ size, malloc_type_id_t type_id);
extern void *malloc_type_aligned_alloc(__SIZE_TYPE__ alignment, __SIZE_TYPE__ size, malloc_type_id_t type_id);

// libMobileGestalt (private, but every jailbreak-era app -- Zebra, device-info tools -- calls it, and it is present
// on iOS 6 in /usr/lib/libMobileGestalt.dylib): no public header, so declare it for xlgen to bridge.
#include <CoreFoundation/CoreFoundation.h>
extern CFTypeRef MGCopyAnswer(CFStringRef question);
