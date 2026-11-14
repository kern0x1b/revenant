.text
.subsections_via_symbols
.p2align 2
.globl _reads_flags
_reads_flags:
    cset w0, eq
    ret
.p2align 2
.globl _caller
_caller:
    stp x29, x30, [sp, #-16]!
    cmp w0, w1
    bl _reads_flags
    ldp x29, x30, [sp], #16
    ret
