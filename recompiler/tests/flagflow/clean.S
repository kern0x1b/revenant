.text
.subsections_via_symbols
.p2align 2
.globl _sets_flags
_sets_flags:
    cmp w0, #0x3f
    ret
.p2align 2
.globl _fatal
_fatal:
    brk #1
.p2align 2
.globl _caller
_caller:
    stp x29, x30, [sp, #-16]!
    bl _sets_flags
    cmp w0, #1
    cset w0, hi
    cbz w0, 1f
    bl _fatal
    b.hi 2f
1:
    mov w0, #0
2:
    ldp x29, x30, [sp], #16
    ret
