#pragma once
// The TPIDRRO_EL0 backing allocator, shared between runtime.c (the translated binary's actual
// per-thread setup) and corpus/tsdguard's host-only test: mmap/mprotect are POSIX, so proving the
// page-protection scheme itself needs no target device, only a host that can mmap two pages and
// take a SIGSEGV -- it's exercising guest code that touches an unaudited offset that needs one
// (corpus/tsdscan's build-time scan, and the live demo, cover that side). One implementation
// here, `#include`d by both, so there is exactly one thing to keep correct.
//
// coordination/crutches.md, "TPIDRRO_EL0 backed by a mostly-zero block": round 10's build-time
// scan (xlate/src/tsd_scan.cpp) tries to prove no guest code reads a slot besides 107 ahead of
// time, but its round-10 review (coordination/reviews/2026-09-27-katabasis-7ecd76e.md) reproduced
// two real false negatives in that static sweep (no basic-block CFG, no interprocedural
// tracking). A static scan over guest code cannot be the whole proof by itself -- this backs it
// with something a scan bug cannot silently pass: real page protection, checked by the CPU on
// every access, not by re-disassembling guest code and hoping nothing was missed.
//
// Page size, disclosed (round 11's review, coordination/reviews/2026-09-27-katabasis-2afe24d.md,
// found this unstated): every call here goes through `sysconf(_SC_PAGESIZE)`, not a compile-time
// constant, so the arithmetic is genuinely page-size-generic -- checked by hand for both 4 KiB and
// 16 KiB, neither breaks it. corpus/tsdguard's *host* run (Apple Silicon Mac, `sysconf`/`sysctl
// hw.pagesize` = 16384) is not itself proof at the target's own granularity: the armv7 iOS 6
// device this recompiler ships on uses 4 KiB pages. Round 12 additionally builds and runs
// corpus/tsdguard for armv7 on the actual device (same capture as the demo run) so the 4 KiB case
// is measured, not only reasoned about.
#include <stdint.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

// The one offset runtime/runtime.c's fake TSD block is measured and audited for: Swift's
// __PTK_FRAMEWORK_SWIFT_KEY7 (slot 107 = 0x358/8, tsd_private.h). Must match xlate/src/
// tsd_scan.h's kAllowedTSDOffsets entry -- no shared header links the two (xlate is a build-time
// host tool; this is guest-runtime code linked into the translated binary), so a comment
// cross-reference in each is what keeps them in sync, not the compiler.
#define XL_TSD_AUDITED_OFFSET 0x358u

// Two pages: base+XL_TSD_AUDITED_OFFSET (xl_tsd_base, below) lands exactly at the start of the
// second one, mapped PROT_READ|PROT_WRITE; the first is PROT_NONE. Every real Darwin TSD slot
// below 107 (pthread_self, errno, mig_reply, libdispatch's, libobjc's, ...) lives at some offset
// less than 0x358 from base, so a guest read at any of them lands in the guard page and faults
// for real (SIGSEGV, a genuine fault address) instead of silently returning zero. What this does
// NOT cover, named plainly: offsets from 0x358 up to one page further (roughly slots 108-618 on a
// 4 KiB page -- the real boundary is sysconf(_SC_PAGESIZE) at run time, not assumed) still fall
// in the RW page and are unprotected, exactly as before a read there silently returns zero.
// Guarding those too would mean placing slot 107 at the END of its page instead of the start,
// trading which side stays open; nothing here measures that a guest never reads those, so
// tsd_scan.cpp's build-time sweep -- an honest, cheap heuristic with known gaps, not proof -- is
// what watches that side, until it, too, is measured and narrowed the way slot 107 was.
static inline void *xl_tsd_alloc(void)
{
    long pagesize = sysconf(_SC_PAGESIZE);
    if (pagesize < 0 || (unsigned long)pagesize < XL_TSD_AUDITED_OFFSET + 8u)
        abort(); // the RW page must hold the whole audited slot; no real page size is this small
    void *pages = mmap(NULL, (size_t)pagesize * 2, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (pages == MAP_FAILED)
        abort();
    if (mprotect(pages, (size_t)pagesize, PROT_NONE))
        abort();
    return pages;
}

// base itself falls inside the guard (PROT_NONE) page -- never dereferenced on its own, only ever
// as (base + offset) once a real load/store instruction adds a slot's byte offset to it.
static inline uintptr_t xl_tsd_base(void *pages)
{
    return (uintptr_t)pages + (uintptr_t)sysconf(_SC_PAGESIZE) - XL_TSD_AUDITED_OFFSET;
}

static inline void xl_tsd_free(void *pages)
{
    munmap(pages, (size_t)sysconf(_SC_PAGESIZE) * 2);
}
