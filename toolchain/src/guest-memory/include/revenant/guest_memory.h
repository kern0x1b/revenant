#ifndef REVENANT_GUEST_MEMORY_H
#define REVENANT_GUEST_MEMORY_H

#include <mach/mach.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

typedef struct revenant_guest_memory {
    uint64_t virtual_bytes;
    uint64_t resident_bytes;
    uint64_t peak_resident_bytes;
    bool peak_known;
} revenant_guest_memory_t;

kern_return_t revenant_guest_memory_read(task_t task, revenant_guest_memory_t *out);
kern_return_t revenant_guest_memory_read_self(revenant_guest_memory_t *out);
kern_return_t revenant_guest_memory_read_pid(pid_t pid, revenant_guest_memory_t *out);

#endif
