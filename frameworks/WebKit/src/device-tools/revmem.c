#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach/vm_statistics.h>

static const char *tag_name(int t)
{
    switch (t) {
    case 0: return "(none)";
    case VM_MEMORY_MALLOC: return "malloc";
    case VM_MEMORY_MALLOC_SMALL: return "malloc_small";
    case VM_MEMORY_MALLOC_LARGE: return "malloc_large";
    case VM_MEMORY_MALLOC_HUGE: return "malloc_huge";
    case VM_MEMORY_MALLOC_TINY: return "malloc_tiny";
    case VM_MEMORY_MALLOC_NANO: return "malloc_nano";
    case VM_MEMORY_STACK: return "stack";
    case VM_MEMORY_CORESERVICES: return "coreservices";
    case VM_MEMORY_JAVASCRIPT_CORE: return "javascriptcore";
    case VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR: return "jsc_jit_exec";
    case VM_MEMORY_JAVASCRIPT_JIT_REGISTER_FILE: return "jsc_jit_regfile";
    case VM_MEMORY_WEBCORE_PURGEABLE_BUFFERS: return "webcore_purgeable";
    case VM_MEMORY_IMAGEIO: return "imageio";
    case VM_MEMORY_COREGRAPHICS: return "coregraphics";
    case VM_MEMORY_COREGRAPHICS_DATA: return "coregraphics_data";
    case VM_MEMORY_COREGRAPHICS_SHARED: return "coregraphics_shared";
    case VM_MEMORY_COREGRAPHICS_FRAMEBUFFERS: return "coregraphics_fb";
    case VM_MEMORY_COREGRAPHICS_BACKINGSTORES: return "coregraphics_backing";
    case VM_MEMORY_LAYERKIT: return "coreanimation";
    case VM_MEMORY_CGIMAGE: return "cgimage";
    case VM_MEMORY_IOKIT: return "iokit";
    case VM_MEMORY_DYLD: return "dyld";
    case VM_MEMORY_DYLD_MALLOC: return "dyld_malloc";
    case VM_MEMORY_SQLITE: return "sqlite";
    case VM_MEMORY_TCMALLOC: return "tcmalloc/bmalloc";
    case VM_MEMORY_FOUNDATION: return "foundation";
    case VM_MEMORY_LIBDISPATCH: return "libdispatch";
    default: return "?";
    }
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: revmem <pid|process-name>\n"); return 2; }

    pid_t pid = atoi(argv[1]);
    if (!pid) {
        int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
        size_t length = 0;
        if (sysctl(mib, 4, NULL, &length, NULL, 0) < 0) { perror("sysctl"); return 1; }
        struct kinfo_proc *procs = malloc(length);
        if (!procs) { perror("malloc"); return 1; }
        if (sysctl(mib, 4, procs, &length, NULL, 0) < 0) { perror("sysctl"); free(procs); return 1; }
        size_t count = length / sizeof(struct kinfo_proc);
        for (size_t i = 0; i < count; i++) {
            if (!strcmp(procs[i].kp_proc.p_comm, argv[1])) {
                pid = procs[i].kp_proc.p_pid;
                break;
            }
        }
        free(procs);
        if (!pid) { fprintf(stderr, "no process named %s\n", argv[1]); return 1; }
        fprintf(stderr, "%s is pid %d\n", argv[1], pid);
    }

    task_t task;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr != KERN_SUCCESS) { fprintf(stderr, "task_for_pid(%d) failed: %d (need root)\n", pid, kr); return 1; }

    enum { MAXTAG = 256 };
    unsigned long long dirty[MAXTAG] = {0}, resident[MAXTAG] = {0}, swapped[MAXTAG] = {0};
    unsigned long long tDirty = 0, tRes = 0, tSwap = 0;

    vm_address_t addr = 0;
    natural_t depth = 0;
    for (int iter = 0; iter < 1000000; iter++) {
        vm_size_t size = 0;
        vm_region_submap_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kr = vm_region_recurse_64(task, &addr, &size, &depth, (vm_region_recurse_info_64_t)&info, &count);
        if (kr != KERN_SUCCESS) break;
        if (size == 0) break;
        if (info.is_submap) { depth++; continue; }
        int tag = info.user_tag; if (tag < 0 || tag >= MAXTAG) tag = 0;
        unsigned long long d = (unsigned long long)info.pages_dirtied * 4096ULL;
        unsigned long long r = (unsigned long long)info.pages_resident * 4096ULL;
        unsigned long long s = (unsigned long long)info.pages_swapped_out * 4096ULL;
        dirty[tag] += d; resident[tag] += r; swapped[tag] += s;
        tDirty += d; tRes += r; tSwap += s;
        addr += size;
    }

    printf("pid %d   dirty=%.1f MB   resident=%.1f MB   swapped=%.1f MB\n",
           pid, tDirty/1048576.0, tRes/1048576.0, tSwap/1048576.0);
    printf("%-22s %10s %10s\n", "owner (vm tag)", "dirty MB", "resid MB");
    char done[MAXTAG] = {0};
    for (int n = 0; n < MAXTAG; n++) {
        int best = -1; unsigned long long bestv = 0;
        for (int t = 0; t < MAXTAG; t++)
            if (!done[t] && dirty[t] > bestv) { bestv = dirty[t]; best = t; }
        if (best < 0) break;
        done[best] = 1;
        printf("%-16s(%3d) %10.2f %10.2f\n", tag_name(best), best,
               dirty[best]/1048576.0, resident[best]/1048576.0);
    }
    return 0;
}
