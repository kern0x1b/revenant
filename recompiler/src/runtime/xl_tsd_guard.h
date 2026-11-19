#pragma once
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include "../../include/xl_tsd_offset.h"

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

static inline size_t xl_stack_length(size_t thread_stack, size_t page)
{
    return (thread_stack + page - 1) / page * page + page;
}

static inline void *xl_stack_map(size_t length, void *(*mapper)(size_t), size_t *guard)
{
    void *stack = mapper(length);
    if (stack == MAP_FAILED)
        return MAP_FAILED;
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
    if (mprotect(stack, page, PROT_NONE)) {
        int error = errno;
        munmap(stack, length);
        errno = error;
        return MAP_FAILED;
    }
    *guard = page;
    return stack;
}

static inline int xl_stack_used(void *stack, size_t length, size_t page, size_t *used)
{
    char seen[256];
    size_t pages = length / page;
    for (size_t first = 0; first < pages; first += sizeof seen) {
        size_t count = pages - first < sizeof seen ? pages - first : sizeof seen;
        if (mincore((char *)stack + first * page, count * page, seen))
            return 0;
        for (size_t i = 0; i < count; i++) {
            if (seen[i] & MINCORE_INCORE) {
                *used = length - (first + i) * page;
                return 1;
            }
        }
    }
    *used = 0;
    return 1;
}

static inline uintptr_t xl_tsd_base(void *pages)
{
    return (uintptr_t)pages + (uintptr_t)sysconf(_SC_PAGESIZE) - XL_TSD_AUDITED_OFFSET;
}

static inline void xl_tsd_free(void *pages)
{
    munmap(pages, (size_t)sysconf(_SC_PAGESIZE) * 2);
}
