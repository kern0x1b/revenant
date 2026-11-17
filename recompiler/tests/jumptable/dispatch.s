    .text
    .align 2
    .globl _xl_dispatch
_xl_dispatch:
    cmp w0, #5
    b.hi Lxl_dispatch_default
    sub w9, w0, #2
    cmp w9, #1
    b.ls Lxl_dispatch_special
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
    mov w0, #100
    ret
    mov w0, #200
    ret
    mov w0, #300
    ret
    mov w0, #400
    ret
Lxl_dispatch_default:
    mov w0, #-1
    ret

    .section __TEXT,__const
    .align 1
Lxl_dispatch_table:
    .byte    0, 2, 0, 0, 4, 6
