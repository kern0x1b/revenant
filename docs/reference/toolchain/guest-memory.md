# Guest memory

The guest memory helper reads a task's virtual and resident size, and its peak where the kernel offers one. It is
`toolchain/src/guest-memory`, the header `revenant/guest_memory.h`, and the target `guest-memory`, a static library for
`iphoneos`. It is built for armv7 and arm64 and works unchanged on a device and in the emulator.

## The API

    typedef struct revenant_guest_memory {
        uint64_t virtual_bytes;
        uint64_t resident_bytes;
        uint64_t peak_resident_bytes;
        bool peak_known;
    } revenant_guest_memory_t;

    kern_return_t revenant_guest_memory_read(task_t task, revenant_guest_memory_t *out);
    kern_return_t revenant_guest_memory_read_self(revenant_guest_memory_t *out);
    kern_return_t revenant_guest_memory_read_pid(pid_t pid, revenant_guest_memory_t *out);

`read_pid` takes the task port of another process with `task_for_pid` and releases it. `read_self` reads
`mach_task_self()`. `peak_known` says whether `peak_resident_bytes` came from the kernel; when it is `false`, that field
holds the current resident size, which is a lower bound on the peak and must not be reported as one.

## What the kernel answers

| Flavour | Used for | Note |
| --- | --- | --- |
| `TASK_BASIC_INFO_64` | virtual and resident size | On armv7 with a deployment target of iOS 5.0 or later the SDK makes this flavour 18 (`task_basic_info_64_2`, ten words); the emulator answers 18 and the older flavour 5 |
| `TASK_VM_INFO` | `resident_size_peak` | The helper asks for it and takes the peak only when the reply covers that field |

The suspend count and the user and system times of `task_basic_info_64_2` are zero in the emulator, which tracks neither.

## The emulator

The emulator answers flavours 5 and 18 from its own page accounting: virtual size is the mapped pages and resident size
is the resident pages. Checked with a guest that touches 32 MiB through `vm_allocate`, `mmap` and `malloc`: each rises by
its size on the first touch and falls back on free.

The emulator does not answer `TASK_VM_INFO`. So on the emulator `peak_known` is `false`. A peak needs a high-water mark
that every change to a page's residency updates, and a reset when pages leave the address space. That is not implemented:
the residency changes are spread over about twenty-seven sites in `emulator/src/foundation/address_space.cpp`, and
`resident_page_count()` is a scan, not a counter.

## Writing a test that measures residency

The compiler deletes an allocation that never escapes: a `malloc`, a `memset` and a `free` with nothing read in between
compile to nothing. A test must let the buffer escape, for example by printing its pointer, before it frees it.
