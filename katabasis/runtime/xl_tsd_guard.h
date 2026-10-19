#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#define XL_TSD_AUDITED_OFFSET 0x358u

static inline void *xl_tsd_alloc(void)
{
    long pagesize = sysconf(_SC_PAGESIZE);
    if (pagesize < 0 || (unsigned long)pagesize < XL_TSD_AUDITED_OFFSET + 8u)
        abort();
    void *pages = mmap(NULL, (size_t)pagesize * 2, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (pages == MAP_FAILED)
        abort();
    if (mprotect(pages, (size_t)pagesize, PROT_NONE))
        abort();
    return pages;
}

static inline uintptr_t xl_tsd_base(void *pages)
{
    return (uintptr_t)pages + (uintptr_t)sysconf(_SC_PAGESIZE) - XL_TSD_AUDITED_OFFSET;
}

static inline void xl_tsd_free(void *pages)
{
    munmap(pages, (size_t)sysconf(_SC_PAGESIZE) * 2);
}
