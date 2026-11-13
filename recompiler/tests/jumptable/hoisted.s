// hoisted.s -- the table base sits in a callee-saved register that is set before a call and read
// after it, as libswiftCore's getUnspecialized does with x22 across its calls to isSpecialized.
// The lifter reloads every register from the state after a call, so the base is only known when the
// analysis treats the callee-saved registers as kept by the call.
    .text
    .align 2
    .globl _xl_hoisted
_xl_hoisted:
    stp x22, x21, [sp, #-32]!
    stp x29, x30, [sp, #16]
    add x29, sp, #16
    mov w21, w0
    adrp x22, Lxl_hoisted_table@PAGE
    add x22, x22, Lxl_hoisted_table@PAGEOFF
    bl _xl_hoisted_noop
    cmp w21, #3
    b.hi Lxl_hoisted_default
    uxtw x1, w21
    adr x8, Lxl_hoisted_slots
    ldrb w9, [x22, x1]
    add x8, x8, x9, lsl #2
    br x8
Lxl_hoisted_slots:
    mov w0, #11
    b Lxl_hoisted_done
    mov w0, #22
    b Lxl_hoisted_done
    mov w0, #33
    b Lxl_hoisted_done
    mov w0, #44
    b Lxl_hoisted_done
Lxl_hoisted_default:
    mov w0, #-1
Lxl_hoisted_done:
    ldp x29, x30, [sp, #16]
    ldp x22, x21, [sp], #32
    ret

    .globl _xl_hoisted_noop
    .align 2
_xl_hoisted_noop:
    ret

    .section __TEXT,__const
    .align 1
Lxl_hoisted_table:
    .byte 0, 2, 4, 6
