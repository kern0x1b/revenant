#import <UIKit/UIKit.h>
#import <execinfo.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/vm_region.h>
#import <signal.h>
#import <string.h>
#import <sys/ucontext.h>
#import <stdio.h>
#import <unistd.h>
#import "RNHostAppDelegate.h"

static void RNHostFatalSignal(int signal, siginfo_t *info, void *context)
{
    void *frames[64];
    int count = backtrace(frames, 64);
    ucontext_t *uc = (ucontext_t *)context;
    fprintf(stderr, "rn-host: fatal signal %d at address %p, pc %p, r0 %p r1 %p r2 %p, %d frames\n", signal, info->si_addr,
            (void *)uc->uc_mcontext->__ss.__pc, (void *)uc->uc_mcontext->__ss.__r[0], (void *)uc->uc_mcontext->__ss.__r[1],
            (void *)uc->uc_mcontext->__ss.__r[2], count);
    backtrace_symbols_fd(frames, count, STDERR_FILENO);
    {
        const _STRUCT_ARM_THREAD_STATE *ss = &uc->uc_mcontext->__ss;
        fprintf(stderr, "rn-host: si_code %d cpsr %p (thumb %d)\n", info->si_code, (void *)ss->__cpsr, (ss->__cpsr >> 5) & 1);
        for (int r = 0; r < 13; r++) {
            fprintf(stderr, "rn-host: r%d %p\n", r, (void *)ss->__r[r]);
        }
        uintptr_t targets[3] = {(uintptr_t)ss->__pc, (uintptr_t)ss->__lr & ~1u, (uintptr_t)ss->__pc & ~1u};
        for (int t = 0; t < 3; t++) {
            vm_address_t addr = targets[t];
            vm_size_t size = 0;
            vm_region_basic_info_data_64_t region;
            mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
            mach_port_t object = 0;
            kern_return_t kr = vm_region_64(mach_task_self(), &addr, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&region, &infoCount, &object);
            fprintf(stderr, "rn-host: target[%d] %p region kr %d start %p size %p prot %d max %d\n", t, (void *)targets[t], kr, (void *)addr, (void *)size,
                    kr == 0 ? region.protection : -1, kr == 0 ? region.max_protection : -1);
            if (kr == 0 && addr <= targets[t] && targets[t] < addr + size && (region.protection & 1)) {
                const unsigned char *bytes = (const unsigned char *)targets[t];
                fprintf(stderr, "rn-host: bytes[%d]", t);
                for (int b = 0; b < 16; b++) {
                    fprintf(stderr, " %02x", bytes[b]);
                }
                fprintf(stderr, "\n");
            }
        }
    }
    const unsigned int *sp = (const unsigned int *)uc->uc_mcontext->__ss.__sp;
    fprintf(stderr, "rn-host: lr %p sp %p slide %p\n", (void *)uc->uc_mcontext->__ss.__lr, (void *)sp, (void *)_dyld_get_image_vmaddr_slide(0));
    for (int index = 0; index < 96; index++) {
        fprintf(stderr, "rn-host: stack[%d] %p\n", index, (void *)sp[index]);
    }
    _exit(128 + signal);
}

int main(int argc, char *argv[])
{
    if (access("/var/tmp/rnhost.log.on", F_OK) == 0) {
        freopen("/var/tmp/rnhost.log", "w", stderr);
        setvbuf(stderr, NULL, _IONBF, 0);
        const int fatal[] = {SIGSEGV, SIGBUS, SIGILL, SIGABRT, SIGTRAP};
        for (unsigned index = 0; index < sizeof(fatal) / sizeof(fatal[0]); index++) {
            struct sigaction action;
            memset(&action, 0, sizeof(action));
            action.sa_sigaction = RNHostFatalSignal;
            action.sa_flags = SA_SIGINFO;
            sigaction(fatal[index], &action, NULL);
        }
    }
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RNHostAppDelegate class]));
    }
}
