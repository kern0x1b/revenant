// Records the size of each allocation made while charon_tracing is set, and fails the k-th one when charon_fail_at = k
// (1-based). charon_fail_at = 0 fails every allocation; -1 only records them. Interposed on malloc, calloc, realloc,
// valloc, aligned_alloc, posix_memalign and the malloc_zone_ calls, through DYLD_INSERT_LIBRARIES (see run.sh).
#include <errno.h>
#include <malloc/malloc.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

volatile int charon_tracing = 0;
volatile long charon_fail_at = 0;
volatile long charon_seen = 0;
volatile long charon_failed_calls = 0;
size_t charon_sizes[64];
const char *charon_kinds[64];

static int hit(size_t size, const char *kind) {
    if (!charon_tracing) return 0;
    long i = charon_seen++;
    if (i < 64) { charon_sizes[i] = size; charon_kinds[i] = kind; }
    if (charon_fail_at == 0 || charon_seen == charon_fail_at) { charon_failed_calls++; return 1; }
    return 0;
}
static void *fm_malloc(size_t n) { if (hit(n, "malloc")) return NULL; return malloc(n); }
static void *fm_calloc(size_t a, size_t b) { if (hit(a * b, "calloc")) return NULL; return calloc(a, b); }
static void *fm_realloc(void *p, size_t n) { if (hit(n, "realloc")) return NULL; return realloc(p, n); }
static void *fm_valloc(size_t n) { if (hit(n, "valloc")) return NULL; return valloc(n); }
static void *fm_aligned_alloc(size_t al, size_t n) { if (hit(n, "aligned_alloc")) return NULL; return aligned_alloc(al, n); }
static int fm_posix_memalign(void **p, size_t al, size_t n) { if (hit(n, "posix_memalign")) return ENOMEM; return posix_memalign(p, al, n); }
static void *fm_malloc_zone_malloc(malloc_zone_t *z, size_t n) { if (hit(n, "zone_malloc")) return NULL; return malloc_zone_malloc(z, n); }
static void *fm_malloc_zone_calloc(malloc_zone_t *z, size_t a, size_t b) { if (hit(a * b, "zone_calloc")) return NULL; return malloc_zone_calloc(z, a, b); }
static void *fm_malloc_zone_realloc(malloc_zone_t *z, void *p, size_t n) { if (hit(n, "zone_realloc")) return NULL; return malloc_zone_realloc(z, p, n); }

typedef struct { const void *replacement; const void *original; } interpose_t;
#define INTERPOSE(rep, orig) __attribute__((used)) static const interpose_t interpose_##orig \
    __attribute__((section("__DATA,__interpose"))) = { (const void *)(unsigned long)&rep, (const void *)(unsigned long)&orig }
INTERPOSE(fm_malloc, malloc);
INTERPOSE(fm_calloc, calloc);
INTERPOSE(fm_realloc, realloc);
INTERPOSE(fm_valloc, valloc);
INTERPOSE(fm_aligned_alloc, aligned_alloc);
INTERPOSE(fm_posix_memalign, posix_memalign);
INTERPOSE(fm_malloc_zone_malloc, malloc_zone_malloc);
INTERPOSE(fm_malloc_zone_calloc, malloc_zone_calloc);
INTERPOSE(fm_malloc_zone_realloc, malloc_zone_realloc);
