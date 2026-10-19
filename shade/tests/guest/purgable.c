// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// purgable.c: guest test of vm_purgable_control on a purgeable allocation.
//
// The state word carries more than the state: bits 8-10 name a volatile group, bit 6 a LIFO queue, bit 5
// the obsolete queue, bit 4 an obsolete ordering parameter, bits 12-13 debug flags (xnu's
// osfmk/mach/vm_purgable.h, VM_PURGABLE_ALL_MASKS). vm_map_purgable_control refuses a word with any
// other bit set and takes the rest, so a client that marks its memory volatile in an ordering group
// works on a device. The Core VM server does exactly that to the memory it keeps compiled code in, and
// Core Image's CPU renderer depends on it.
//
// One line per case, "ok" or "FAIL <why>"; exits with the number of failures.
#include <mach/mach.h>
#include <mach/vm_purgable.h>
#include <stdio.h>

static int failures;

static void check(const char *name, int good, const char *why)
{
    if (good) {
        printf("ok   %s\n", name);
    } else {
        printf("FAIL %s: %s\n", name, why);
        failures++;
    }
}

static int control(vm_address_t address, vm_purgable_t what, int *state)
{
    return vm_purgable_control(mach_task_self(), address, what, state);
}

int main(void)
{
    vm_address_t address = 0;
    kern_return_t result = vm_allocate(mach_task_self(), &address, 0x4000, VM_FLAGS_ANYWHERE | VM_FLAGS_PURGABLE);
    check("allocate purgeable", result == KERN_SUCCESS, "vm_allocate refused VM_FLAGS_PURGABLE");
    if (result != KERN_SUCCESS)
        return failures;

    int state = 0;
    result = control(address, VM_PURGABLE_GET_STATE, &state);
    check("new memory is non-volatile", result == KERN_SUCCESS && state == VM_PURGABLE_NONVOLATILE, "get state");

    state = VM_PURGABLE_VOLATILE;
    result = control(address, VM_PURGABLE_SET_STATE, &state);
    check("volatile", result == KERN_SUCCESS && state == VM_PURGABLE_NONVOLATILE, "set volatile, previous state");
    state = 0;
    result = control(address, VM_PURGABLE_GET_STATE, &state);
    check("state reads volatile", result == KERN_SUCCESS && state == VM_PURGABLE_VOLATILE, "get state");

    state = VM_PURGABLE_NONVOLATILE;
    result = control(address, VM_PURGABLE_SET_STATE, &state);
    check("non-volatile again", result == KERN_SUCCESS && state == VM_PURGABLE_VOLATILE, "previous state");

    // The words clients send: an ordering, a behaviour and a group beside the state.
    const int words[] = {
        VM_PURGABLE_VOLATILE | VM_PURGABLE_ORDERING_OBSOLETE,
        VM_PURGABLE_VOLATILE | VM_PURGABLE_BEHAVIOR_LIFO,
        VM_PURGABLE_VOLATILE | VM_VOLATILE_GROUP_3,
        VM_PURGABLE_VOLATILE | VM_VOLATILE_ORDER_MASK,
    };
    for (unsigned i = 0; i < sizeof words / sizeof words[0]; i++) {
        char name[64];
        snprintf(name, sizeof name, "volatile with flags 0x%x", words[i] & ~VM_PURGABLE_STATE_MASK);
        state = words[i];
        result = control(address, VM_PURGABLE_SET_STATE, &state);
        check(name, result == KERN_SUCCESS && state == VM_PURGABLE_NONVOLATILE, "set state");
        state = VM_PURGABLE_NONVOLATILE;
        control(address, VM_PURGABLE_SET_STATE, &state);
    }

    // The previous state comes back without the flags, and a flag does not stay on the memory.
    state = VM_PURGABLE_VOLATILE | VM_VOLATILE_GROUP_5;
    control(address, VM_PURGABLE_SET_STATE, &state);
    state = VM_PURGABLE_VOLATILE | VM_PURGABLE_BEHAVIOR_LIFO;
    result = control(address, VM_PURGABLE_SET_STATE, &state);
    check("previous state has no flags", result == KERN_SUCCESS && state == VM_PURGABLE_VOLATILE, "previous state");
    state = VM_PURGABLE_NONVOLATILE;
    control(address, VM_PURGABLE_SET_STATE, &state);

    state = VM_PURGABLE_DENY;
    result = control(address, VM_PURGABLE_SET_STATE, &state);
    check("deny", result == KERN_SUCCESS && state == VM_PURGABLE_NONVOLATILE, "set deny");

    // A bit outside VM_PURGABLE_ALL_MASKS is refused and changes nothing.
    state = VM_PURGABLE_NONVOLATILE;
    control(address, VM_PURGABLE_SET_STATE, &state);
    state = VM_PURGABLE_VOLATILE | (1 << 16);
    result = control(address, VM_PURGABLE_SET_STATE, &state);
    check("a bit outside the masks is refused", result == KERN_INVALID_ARGUMENT, "not KERN_INVALID_ARGUMENT");
    state = 0;
    result = control(address, VM_PURGABLE_GET_STATE, &state);
    check("a refused word changes nothing", result == KERN_SUCCESS && state == VM_PURGABLE_NONVOLATILE, "state moved");

    vm_deallocate(mach_task_self(), address, 0x4000);
    return failures;
}
