    .text
    .align 2
    .globl _xl_inline
_xl_inline:
    cmp w0, #3
    b.hi Lxl_inline_default
    adrp x8, lJTI_inline@PAGE
    add x8, x8, lJTI_inline@PAGEOFF
Ltmp_inline:
    adr x9, Ltmp_inline
    ldrsw x10, [x8, x0, lsl #2]
    add x9, x9, x10
    br x9
Lxl_inline_0:
    mov w0, #10
    ret
Lxl_inline_1:
    mov w0, #20
    ret
Lxl_inline_2:
    mov w0, #30
    ret
Lxl_inline_3:
    mov w0, #40
    ret
Lxl_inline_default:
    mov w0, #-1
    ret
    brk #1
    .align 2
lJTI_inline:
    .long Lxl_inline_0-Ltmp_inline
    .long Lxl_inline_1-Ltmp_inline
    .long Lxl_inline_2-Ltmp_inline
    .long Lxl_inline_3-Ltmp_inline
    .globl _xl_inline_after
    .align 2
_xl_inline_after:
    mov w0, #7
    ret
.subsections_via_symbols
