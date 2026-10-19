// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Provide ARMv6 executable startup and lazy-binding glue for guest
// integration probes.

// Minimal ARMv6 Darwin dynamic-linker glue for guest integration probes.
//
// The iPhoneOS 1.0 dyld expects lazy stubs to push the lazy-pointer address
// and the main Mach-O header before entering the binder published through the
// __DATA,__dyld vector.  This is the same ABI used by the firmware's crt1.o;
// it deliberately contains no process startup policy.

.syntax unified

.section __TEXT,__text,regular,pure_instructions
.align 2
.globl _start
_start:
    ldr r0, [sp]
    add r1, sp, #4
    add r2, r0, #1
    add r2, r1, r2, lsl #2
    bic sp, sp, #7
    bl _shade_guest_start
    bkpt #0

.align 2
.private_extern dyld_stub_binding_helper
dyld_stub_binding_helper:
    str r12, [sp, #-4]!
    ldr r12, Lmain_header
    str r12, [sp, #-4]!
    ldr r12, Llazy_binder_slot
    ldr pc, [r12]

Lmain_header:
    .long __mh_execute_header
Llazy_binder_slot:
    .long dyld_lazy_symbol_binding_entry_point

.section __DATA,__dyld
.align 2
dyld_lazy_symbol_binding_entry_point:
    .long 0
.globl _shade_dyld_function_lookup_pointer
_shade_dyld_function_lookup_pointer:
    .long 0
    .long 0
    .long 0
    .long 0
    .long dyld_stub_binding_helper
    .long 0
