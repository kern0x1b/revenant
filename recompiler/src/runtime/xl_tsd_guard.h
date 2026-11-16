#pragma once
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#define XL_TSD_AUDITED_OFFSET 0x358u

static inline void xl_tsd_failed(const char *what)
{
    fprintf(stderr, "xlate: cannot set up the thread-specific page of a thread for translated code: %s failed, errno %d\n", what, errno);
    abort();
}

static inline void *xl_tsd_alloc(void)
{
    long pagesize = sysconf(_SC_PAGESIZE);
    if (pagesize < 0 || (unsigned long)pagesize < XL_TSD_AUDITED_OFFSET + 8u)
        xl_tsd_failed("the page size is too small for the audited offset (sysconf)");
    void *pages = mmap(NULL, (size_t)pagesize * 2, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (pages == MAP_FAILED)
        xl_tsd_failed("the mapping of two pages");
    if (mprotect(pages, (size_t)pagesize, PROT_NONE))
        xl_tsd_failed("the protection of the guard page");
    return pages;
}

static inline void *xl_map_anonymous(size_t length)
{
    return mmap(NULL, length, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
}

static inline void *xl_stack_map(size_t first, size_t floor, void *(*mapper)(size_t), size_t *size, size_t *guard)
{
    size_t length = first;
    for (;;) {
        void *stack = mapper(length);
        if (stack != MAP_FAILED) {
            size_t page = (size_t)sysconf(_SC_PAGESIZE);
            *size = length;
            *guard = mprotect(stack, page, PROT_NONE) == 0 ? page : 0;
            return stack;
        }
        if (length <= floor)
            return MAP_FAILED;
        fprintf(stderr, "xlate: the guest stack of a thread could not be mapped with %lu bytes (errno %d), trying half\n", (unsigned long)length, errno);
        length >>= 1;
    }
}

static inline uintptr_t xl_tsd_base(void *pages)
{
    return (uintptr_t)pages + (uintptr_t)sysconf(_SC_PAGESIZE) - XL_TSD_AUDITED_OFFSET;
}

static inline void xl_tsd_free(void *pages)
{
    munmap(pages, (size_t)sysconf(_SC_PAGESIZE) * 2);
}
