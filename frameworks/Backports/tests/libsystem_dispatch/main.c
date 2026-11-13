#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <unistd.h>

#if defined(REVENANT_DEVICE)
#define CREATE dispatch_data_create
#define OURS _dispatch_data_destructor_munmap
#else
#define CREATE revenant_test_dispatch_data_create
#define OURS __revenant_fb__dispatch_data_destructor_munmap
extern dispatch_block_t __revenant_fb__dispatch_data_destructor_munmap;
dispatch_data_t revenant_test_dispatch_data_create(const void *, size_t, dispatch_queue_t, dispatch_block_t);
#endif

int __revenant_fb_memset_s(void *, size_t, int, size_t);

static unsigned checks;

static void require(int value, const char *label)
{
    if (!value) {
        fprintf(stderr, "FAIL %s (errno %d)\n", label, errno);
        exit(1);
    }
    checks++;
    printf("PASS %s\n", label);
}

static const struct {
    size_t capacity, count;
    int null, error;
    size_t written;
} MEMSET_CASES[] = {
    {16, 8, 0, 0, 8}, {16, 16, 0, 0, 16}, {16, 17, 0, EOVERFLOW, 16}, {16, SIZE_MAX, 0, E2BIG, 16},
    {SIZE_MAX, 4, 0, E2BIG, 0}, {16, 8, 1, EINVAL, 0}, {0, 0, 0, 0, 0},
};

static void check_memset(void)
{
#if !defined(REVENANT_DEVICE)
    int (*darwin)(void *, size_t, int, size_t) = (int (*)(void *, size_t, int, size_t))dlsym(RTLD_DEFAULT, "memset_s");
    require(darwin != NULL, "the system memset_s is there to compare with");
#endif
    for (size_t index = 0; index < sizeof MEMSET_CASES / sizeof MEMSET_CASES[0]; index++) {
        unsigned char mine[24];
        memset(mine, 0xaa, sizeof mine);
        int got = __revenant_fb_memset_s(MEMSET_CASES[index].null ? NULL : mine, MEMSET_CASES[index].capacity, 0x5c, MEMSET_CASES[index].count);
        int exact = got == MEMSET_CASES[index].error;
        for (size_t at = 0; at < sizeof mine; at++) {
            exact = exact && mine[at] == (at < MEMSET_CASES[index].written ? 0x5c : 0xaa);
        }
#if !defined(REVENANT_DEVICE)
        unsigned char theirs[24];
        memset(theirs, 0xaa, sizeof theirs);
        int wanted = darwin(MEMSET_CASES[index].null ? NULL : theirs, MEMSET_CASES[index].capacity, 0x5c, MEMSET_CASES[index].count);
        exact = exact && got == wanted && memcmp(mine, theirs, sizeof mine) == 0;
#endif
        char label[96];
        snprintf(label, sizeof label, "memset_s capacity %zu count %zu%s", MEMSET_CASES[index].capacity, MEMSET_CASES[index].count,
                 MEMSET_CASES[index].null ? " null" : "");
        require(exact, label);
    }
}

static size_t page_size(void)
{
    return (size_t)getpagesize();
}

static char *map_pages(size_t pages)
{
    void *base = mmap(NULL, pages * page_size(), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    require(base != MAP_FAILED, "map anonymous pages");
    memset(base, 0x41, pages * page_size());
    return base;
}

static int last_error;

static int mapped(const void *address)
{
    int answer = msync((void *)address, page_size(), MS_ASYNC);
    last_error = errno;
    return answer == 0;
}

static void drain(dispatch_queue_t queue)
{
    dispatch_sync(queue, ^{
    });
}

static void check_unmaps(dispatch_block_t destructor, const char *name)
{
    size_t page = page_size();
    dispatch_queue_t queue = dispatch_queue_create("revenant.libsystem.dispatch", NULL);
    char *base = map_pages(3);
    size_t length = page - 100;
    dispatch_data_t data = CREATE(base + page, length, queue, destructor);
    require(data != NULL, name);
    require(dispatch_data_get_size(data) == length, "the data holds the bytes it was made over");
    drain(queue);
    require(mapped(base + page), "the range is still mapped while the data lives");
    dispatch_release(data);
    drain(queue);
    require(mapped(base), "the page before the range stays mapped");
    int gone = !mapped(base + page);
    int gone_error = last_error;
    require(gone, "the range is unmapped once the data is released");
    require(gone_error == ENOMEM, "the unmapped range answers ENOMEM");
    require(mapped(base + 2 * page), "the page after the range stays mapped");
    munmap(base, page);
    munmap(base + 2 * page, page);
    dispatch_release(queue);
}

static void check_empty(dispatch_block_t destructor)
{
    dispatch_queue_t queue = dispatch_queue_create("revenant.libsystem.dispatch.empty", NULL);
    char *base = map_pages(1);
    const void *volatile absent = NULL;
    dispatch_data_t none = CREATE(absent, 0, queue, destructor);
    require(none != NULL && dispatch_data_get_size(none) == 0, "no buffer and no size make the empty data");
    dispatch_data_t zero = CREATE(base, 0, queue, destructor);
    require(zero != NULL && dispatch_data_get_size(zero) == 0, "a buffer of no size makes the empty data");
    drain(queue);
    munmap(base, page_size());
    dispatch_release(queue);
}

static void check_other_destructors(void)
{
    dispatch_queue_t queue = dispatch_queue_create("revenant.libsystem.dispatch.other", NULL);
    __block int runs = 0;
    char *bytes = malloc(32);
    memset(bytes, 0x42, 32);
    dispatch_data_t custom = CREATE(bytes, 32, queue, ^{
        runs++;
        free(bytes);
    });
    require(custom != NULL && dispatch_data_get_size(custom) == 32, "a custom destructor makes the data");
    dispatch_release(custom);
    drain(queue);
    require(runs == 1, "a custom destructor runs exactly once");
    char *owned = malloc(16);
    memset(owned, 0x43, 16);
    dispatch_data_t freed = CREATE(owned, 16, queue, DISPATCH_DATA_DESTRUCTOR_FREE);
    require(freed != NULL && dispatch_data_get_size(freed) == 16, "the free destructor passes through");
    dispatch_release(freed);
    char stack[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    dispatch_data_t copied = CREATE(stack, sizeof stack, queue, NULL);
    memset(stack, 0, sizeof stack);
    const void *held;
    size_t held_size;
    dispatch_data_t mapped_data = dispatch_data_create_map(copied, &held, &held_size);
    require(held_size == sizeof stack && ((const char *)held)[7] == 8, "no destructor copies the bytes");
    dispatch_release(mapped_data);
    dispatch_release(copied);
    drain(queue);
    dispatch_release(queue);
}

#if defined(REVENANT_DEVICE)
static void check_public_symbol(void)
{
    require(&_dispatch_data_destructor_munmap != NULL, "the destructor symbol is bound and is not NULL");
    require(_dispatch_data_destructor_munmap != NULL, "the destructor symbol holds a block");
    check_unmaps(_dispatch_data_destructor_munmap, "the exported sentinel makes data through the wrapper");
}
#else
static void check_public_symbol(void)
{
    require(DISPATCH_DATA_DESTRUCTOR_MUNMAP != OURS, "the system's sentinel is not the fallback block");
    check_unmaps(DISPATCH_DATA_DESTRUCTOR_MUNMAP, "the system's sentinel passes through the wrapper");
}
#endif

typedef dispatch_data_t (*data_create)(const void *, size_t, dispatch_queue_t, dispatch_block_t);

static double nanoseconds_per_call(data_create create)
{
    enum { CALLS = 100000 };
    static const char bytes[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    struct timeval start, end;
    gettimeofday(&start, NULL);
    for (int call = 0; call < CALLS; call++) {
        dispatch_release(create(bytes, sizeof bytes, NULL, NULL));
    }
    gettimeofday(&end, NULL);
    return ((end.tv_sec - start.tv_sec) * 1e6 + (end.tv_usec - start.tv_usec)) * 1e3 / CALLS;
}

static void measure_cost(void)
{
    void *system = dlopen("/usr/lib/libSystem.B.dylib", RTLD_LAZY | RTLD_NOLOAD);
    data_create direct = system != NULL ? (data_create)dlsym(system, "dispatch_data_create") : NULL;
    require(direct != NULL, "the system dispatch_data_create is there to measure against");
    double system_best = 1e18, wrapper_best = 1e18;
    for (int round = 0; round < 5; round++) {
        double own = nanoseconds_per_call(direct);
        double wrapped = nanoseconds_per_call(CREATE);
        system_best = own < system_best ? own : system_best;
        wrapper_best = wrapped < wrapper_best ? wrapped : wrapper_best;
    }
    printf("INFO dispatch_data_create copying 16 bytes: system %.0f ns, wrapper %.0f ns per call and release\n", system_best, wrapper_best);
}

int main(void)
{
    check_memset();
    check_unmaps(OURS, "the fallback sentinel makes data through the wrapper");
    check_empty(OURS);
    check_other_destructors();
    check_public_symbol();
    measure_cost();
    printf("%u checks passed\n", checks);
    return 0;
}
