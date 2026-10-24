#include "revenant/guest_memory.h"

#include <stddef.h>

kern_return_t revenant_guest_memory_read(task_t task, revenant_guest_memory_t *out)
{
    task_basic_info_64_data_t basic;
    mach_msg_type_number_t count = TASK_BASIC_INFO_64_COUNT;
    kern_return_t result = task_info(task, TASK_BASIC_INFO_64, (task_info_t)&basic, &count);
    if (result != KERN_SUCCESS) {
        return result;
    }
    out->virtual_bytes = basic.virtual_size;
    out->resident_bytes = basic.resident_size;
    out->peak_resident_bytes = basic.resident_size;
    out->peak_known = false;

    task_vm_info_data_t vm;
    count = TASK_VM_INFO_REV0_COUNT;
    result = task_info(task, TASK_VM_INFO, (task_info_t)&vm, &count);
    if (result == KERN_SUCCESS &&
        count * sizeof(natural_t) >= offsetof(task_vm_info_data_t, resident_size_peak) + sizeof(vm.resident_size_peak)) {
        out->peak_resident_bytes = vm.resident_size_peak;
        out->peak_known = true;
    }
    return KERN_SUCCESS;
}

kern_return_t revenant_guest_memory_read_self(revenant_guest_memory_t *out)
{
    return revenant_guest_memory_read(mach_task_self(), out);
}

kern_return_t revenant_guest_memory_read_pid(pid_t pid, revenant_guest_memory_t *out)
{
    task_t task = MACH_PORT_NULL;
    kern_return_t result = task_for_pid(mach_task_self(), pid, &task);
    if (result != KERN_SUCCESS) {
        return result;
    }
    result = revenant_guest_memory_read(task, out);
    mach_port_deallocate(mach_task_self(), task);
    return result;
}
