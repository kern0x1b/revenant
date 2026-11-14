.text
.subsections_via_symbols
.p2align 2
.globl _target
_target:
    cmp w0, #1
    ret
.p2align 2
.globl _caller
_caller:
    stp x29, x30, [sp, #-16]!
    adrp x8, _target@PAGE
    add x8, x8, _target@PAGEOFF
    blr x8
    cset w0, ls
    ldp x29, x30, [sp], #16
    ret
