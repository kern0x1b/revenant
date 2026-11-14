.text
.subsections_via_symbols
.p2align 2
.globl _outlined_compare
_outlined_compare:
    cmp w0, #0x3f
    ret
.p2align 2
.globl _caller
_caller:
    stp x29, x30, [sp, #-16]!
    bl _outlined_compare
    cset w0, hi
    ldp x29, x30, [sp], #16
    ret
