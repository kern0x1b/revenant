// dispatch.s -- hand-written to guarantee the exact instruction sequence under test (a C switch
// is not reliably lowered to this shape on demand; see main.c). Matches libswiftCore's
// getUnspecialized byte-indexed branch table in structure, including the one detail that matters:
// a NON-CONTIGUOUS admitted domain. getUnspecialized guards its table dispatch with
// `(kind - 13) unsigned >= 6` (kind outside [13, 18], a range handled by an earlier special case)
// *and then* `kind <= 0x10f` before the table load -- so the domain reaching the table is
// {0..12} u {19..271}, a gap in the middle. Here: kind in {2, 3} is diverted to a special case
// before the table read at all, so the domain reaching THIS table is {0, 1} u {4, 5} -- kind 4
// and 5 are only reachable on the far side of that gap, the same shape as the real bug (a slot
// reachable only through a kind value past a gap, silently dropped by the old code, which broke
// out of its domain scan the instant it saw the first excluded index after having accepted one).
    .text
    .align 2
    .globl _xl_dispatch
_xl_dispatch:
    cmp w0, #5
    b.hi Lxl_dispatch_default
    sub w9, w0, #2
    cmp w9, #1
    b.ls Lxl_dispatch_special      // kind in {2, 3}: the gap
    adrp x11, Lxl_dispatch_table@PAGE
    add x11, x11, Lxl_dispatch_table@PAGEOFF
    adr x8, Lxl_dispatch_slots
    ldrb w10, [x11, x0]
    add x8, x8, x10, lsl #2
    br x8
Lxl_dispatch_special:
    mov w0, #999
    ret
Lxl_dispatch_slots:
    mov w0, #100          // slot 0 (base+0)  -- kind 0
    ret
    mov w0, #200          // slot 1 (base+8)  -- kind 1
    ret
    mov w0, #300          // slot 2 (base+16) -- kind 4, reachable only past the gap
    ret
    mov w0, #400          // slot 3 (base+24) -- kind 5, reachable only past the gap
    ret
Lxl_dispatch_default:
    mov w0, #-1
    ret

    .section __TEXT,__const
    .align 1
Lxl_dispatch_table:
    // kind:   0  1  2  3  4  5     (indices 2, 3 are never read: diverted before the table load)
    .byte    0, 2, 0, 0, 4, 6
