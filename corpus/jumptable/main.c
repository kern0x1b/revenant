// corpus/jumptable: reproduces the byte-indexed branch-table dispatch pattern found in
// libswiftCore's demangler (swift::Demangle::__runtime::getUnspecialized), traced from the
// _DictionaryStorage.allocate crash's successor fault (counts.sorted{} deep in the remangler):
//
//   cmp/b.hi                      ; outer bound check
//   sub/cmp/b.ls                  ; an earlier special case excludes a middle sub-range (the gap)
//   adrp/add   x11, TABLE         ; byte table base
//   adr        x8, slots          ; case-body region base (PC-relative, right after this block)
//   ldrb       w10, [x11, x0]     ; w10 = TABLE[kind]  (a small slot index, not a full address)
//   add        x8, x8, x10, lsl #2
//   br         x8
//
// This is a "compressed" switch lowering: many case VALUES (kind, wide range) share a handful of
// DISTINCT case BODIES, so the table stores a small per-case slot index rather than one absolute
// address per case, and the slot address is computed at run time as base + index*4. The one
// detail that matters here: the domain of kind values that actually REACH the table read is not
// contiguous -- an earlier special case (dispatch.s's kind-in-{2,3} branch) diverts a middle
// sub-range away before the table is ever read, so the admitted domain is {0, 1} u {4, 5}, a gap
// in the middle. xlate's JumpTables (xlate/src/xlate.cpp) must read every kind value the domain
// admits, not stop at the first excluded one after accepting a run -- kind 4 and 5 are reachable
// ONLY on the far side of the gap, and if their addresses are never added to program.functions,
// a run that dispatches through them crashes with "jump to an address that does not start a
// translated function" -- exactly the shape of the counts.sorted{} fault.
#include <stdint.h>
#include <stdio.h>

extern int32_t xl_dispatch(int32_t kind);

int main(void) {
    static const int32_t expect[] = {100, 200, 999, 999, 300, 400};
    int fail = 0;
    for (int32_t k = 0; k < 6; k++) {
        int32_t got = xl_dispatch(k);
        printf("kind %d -> %d\n", k, got);
        if (got != expect[k]) {
            fprintf(stderr, "FAIL: kind %d: wanted %d, got %d\n", k, expect[k], got);
            fail = 1;
        }
    }
    int32_t out_of_range = xl_dispatch(6);
    printf("kind 6 (out of range) -> %d\n", out_of_range);
    if (out_of_range != -1) {
        fprintf(stderr, "FAIL: out-of-range kind: wanted -1, got %d\n", out_of_range);
        fail = 1;
    }
    if (fail)
        return 1;
    printf("ok\n");
    return 0;
}
