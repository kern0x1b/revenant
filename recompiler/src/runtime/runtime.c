#include "xl_state.h"
#include "xl_vm_map.h"

void xl_thread_altstack(void);

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <mach/mach.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/ucontext.h>
#include <unistd.h>

typedef struct State State;
typedef struct Memory Memory;
typedef void (*xl_lifted)(State *);

struct xl_function {
    uint32_t address;
    xl_lifted function;
};

extern const struct xl_function xl_functions[];
extern const uint32_t xl_function_count;
extern const uint32_t xl_entry_address;
uint32_t xl_guest_low, xl_guest_high;
unsigned long xl_guest_image_low, xl_guest_image_high, xl_guest_arena_low, xl_guest_arena_high;
xl_lifted xl_imp_lookup(uint64_t address);

#define XL_REG(state, name) (*(uint64_t *)((char *)(state) + XL_OFFSET_##name))
#define XL_GUEST_STACK_MAIN (16u << 20)
#define XL_GUEST_STACK_THREAD (4u << 20)
#define XL_GUEST_STACK_FLOOR (256u << 10)

#ifdef XL_LIBRARY
extern void xl_library_ensure(void);
#define xl_ensure_ready xl_library_ensure
#else
extern void xl_bridge_init(void);
#define xl_ensure_ready xl_bridge_init
#endif

static pthread_key_t xl_state_key;
static pthread_once_t xl_state_once = PTHREAD_ONCE_INIT;
static int xl_diagnostics_installed;
static int xl_map_on;

struct xl_thread {
    void *stack;
    void *tsd_pages;
    size_t stack_size;
    size_t guard_size;
};

#define XL_THREAD_HEADER 32u
#include "xl_tsd_guard.h"

static uint32_t xl_threads_created;
static uint32_t xl_threads_ended;
static uint32_t xl_threads_stack_live;

int xl_stats_enabled(void)
{
    static int enabled = -1;
    if (enabled < 0)
        enabled = getenv("XL_STATS") != NULL || access("/private/var/revenant/xl-stats", F_OK) == 0;
    return enabled;
}

static void xl_threads_report(const char *what, size_t stack, size_t host_stack)
{
    uint32_t created = __atomic_load_n(&xl_threads_created, __ATOMIC_RELAXED);
    uint32_t ended = __atomic_load_n(&xl_threads_ended, __ATOMIC_RELAXED);
    dprintf(2, "xlate: threads: %s (guest stack %lu KiB, host stack %lu KiB): %u live, %u created, %u ended, %lu KiB of guest stack live\n",
            what, (unsigned long)(stack >> 10), (unsigned long)(host_stack >> 10), created - ended, created, ended,
            (unsigned long)(__atomic_load_n(&xl_threads_stack_live, __ATOMIC_RELAXED) >> 10));
}

#define XL_PROFILE_BUCKETS 1024
#define XL_PROFILE_INTERVAL_US 20000u
#define XL_PROFILE_WINDOW_US 5000000u
#define XL_PROFILE_TOP 10
#define XL_PROFILE_THREADS 64

struct xl_profile_bucket {
    uint32_t address;
    uint32_t count;
};

static struct xl_profile_bucket xl_profile_buckets[XL_PROFILE_BUCKETS];
static pthread_once_t xl_profile_once = PTHREAD_ONCE_INIT;

void xl_stats_snapshot(uint32_t *messages, uint32_t *dynamic, uint64_t *routing_ticks, uint64_t *call_ticks);
uint64_t xl_stats_microseconds(uint64_t ticks);
void xl_stats_window_report(void);

static void xl_profile_note(uint32_t pc)
{
    uint32_t address = pc & ~0x3fu;
    unsigned start = (address >> 6) * 2654435761u % XL_PROFILE_BUCKETS;
    for (unsigned probe = 0; probe < XL_PROFILE_BUCKETS; probe++) {
        struct xl_profile_bucket *bucket = &xl_profile_buckets[(start + probe) % XL_PROFILE_BUCKETS];
        if (!bucket->count)
            bucket->address = address;
        if (bucket->address == address) {
            bucket->count++;
            return;
        }
    }
}

static unsigned xl_profile_sample(mach_port_t self)
{
    thread_act_array_t threads;
    mach_msg_type_number_t count;
    if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS)
        return 0;
    uint32_t pcs[XL_PROFILE_THREADS];
    unsigned found = 0;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        thread_t thread = threads[i];
        if (thread == self || found == XL_PROFILE_THREADS)
            continue;
        thread_basic_info_data_t info;
        mach_msg_type_number_t info_count = THREAD_BASIC_INFO_COUNT;
        if (thread_info(thread, THREAD_BASIC_INFO, (thread_info_t)&info, &info_count) != KERN_SUCCESS ||
            info.run_state != TH_STATE_RUNNING)
            continue;
        if (thread_suspend(thread) != KERN_SUCCESS)
            continue;
        arm_thread_state_t state;
        mach_msg_type_number_t state_count = ARM_THREAD_STATE_COUNT;
        kern_return_t result = thread_get_state(thread, ARM_THREAD_STATE, (thread_state_t)&state, &state_count);
        thread_resume(thread);
        if (result == KERN_SUCCESS)
            pcs[found++] = state.__pc;
    }
    for (mach_msg_type_number_t i = 0; i < count; i++)
        mach_port_deallocate(mach_task_self(), threads[i]);
    vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof *threads);
    for (unsigned i = 0; i < found; i++)
        xl_profile_note(pcs[i]);
    return found;
}

static void xl_profile_report(unsigned samples, uint32_t window_messages, uint32_t window_dynamic, uint64_t window_routing, uint64_t window_call)
{
    char line[320];
    int length = snprintf(line, sizeof line,
                          "xlate: profile: %u samples of running threads in 5 s, %u messages (%u dynamic), routing %llu us, host call of the dynamic ones %llu us\n",
                          samples, window_messages, window_dynamic, (unsigned long long)xl_stats_microseconds(window_routing),
                          (unsigned long long)xl_stats_microseconds(window_call));
    write(2, line, (size_t)length);
    Dl_info own;
    uintptr_t base = dladdr((const void *)xl_threads_report, &own) ? (uintptr_t)own.dli_fbase : 0;
    for (unsigned rank = 0; rank < XL_PROFILE_TOP; rank++) {
        struct xl_profile_bucket *best = NULL;
        for (unsigned i = 0; i < XL_PROFILE_BUCKETS; i++) {
            struct xl_profile_bucket *bucket = &xl_profile_buckets[i];
            if (bucket->count && (!best || bucket->count > best->count))
                best = bucket;
        }
        if (!best)
            break;
        Dl_info where;
        const char *image = "?";
        const char *symbol = "";
        uintptr_t offset = 0;
        if (dladdr((const void *)(uintptr_t)best->address, &where)) {
            image = where.dli_fname ? strrchr(where.dli_fname, '/') : NULL;
            image = image ? image + 1 : where.dli_fname ? where.dli_fname : "?";
            symbol = where.dli_sname ? where.dli_sname : "";
            offset = best->address - (uintptr_t)where.dli_fbase;
        }
        length = snprintf(line, sizeof line, "xlate:   %5u samples at 0x%08x (%s+0x%lx%s%s)%s\n", best->count, best->address, image,
                          (unsigned long)offset, *symbol ? " " : "", symbol,
                          base && (uintptr_t)best->address - base < (104u << 20) ? " [the library]" : "");
        write(2, line, (size_t)length);
        best->count = 0;
    }
    xl_stats_window_report();
    memset(xl_profile_buckets, 0, sizeof xl_profile_buckets);
}

static void *xl_profile_thread(void *unused)
{
    (void)unused;
    mach_port_t self = mach_thread_self();
    uint32_t seen_messages = 0, seen_dynamic = 0;
    uint64_t seen_routing = 0, seen_call = 0;
    unsigned samples = 0;
    unsigned elapsed = 0;
    for (;;) {
        usleep(XL_PROFILE_INTERVAL_US);
        samples += xl_profile_sample(self);
        elapsed += XL_PROFILE_INTERVAL_US;
        if (elapsed < XL_PROFILE_WINDOW_US)
            continue;
        elapsed = 0;
        uint32_t messages, dynamic;
        uint64_t routing, call;
        xl_stats_snapshot(&messages, &dynamic, &routing, &call);
        if (samples || messages != seen_messages)
            xl_profile_report(samples, messages - seen_messages, dynamic - seen_dynamic, routing - seen_routing, call - seen_call);
        seen_messages = messages;
        seen_dynamic = dynamic;
        seen_routing = routing;
        seen_call = call;
        samples = 0;
    }
    return NULL;
}

static void xl_profile_launch(void)
{
    pthread_t thread;
    if (pthread_create(&thread, NULL, xl_profile_thread, NULL) == 0)
        pthread_detach(thread);
}

void xl_profile_start(void)
{
    pthread_once(&xl_profile_once, xl_profile_launch);
}

static void xl_state_destroy(void *value)
{
    struct xl_thread *thread = (struct xl_thread *)((char *)value - XL_THREAD_HEADER);
    size_t stack = thread->stack_size;
    munmap(thread->stack, thread->stack_size);
    xl_tsd_free(thread->tsd_pages);
    free(thread);
    __atomic_fetch_add(&xl_threads_ended, 1, __ATOMIC_RELAXED);
    __atomic_fetch_sub(&xl_threads_stack_live, (uint32_t)stack, __ATOMIC_RELAXED);
    if (xl_stats_enabled())
        xl_threads_report("ended", stack, 0);
}

static void xl_thread_state_failed(const char *what, size_t size)
{
    int error = errno;
    fprintf(stderr, "xlate: cannot set up a thread for translated code: %s of %lu bytes failed, errno %d\n", what, (unsigned long)size, error);
    xl_threads_report("at the failure", size, 0);
    xl_vm_map_dump(fileno(stderr), "thread state");
    abort();
}

static void xl_state_key_create(void)
{
    pthread_key_create(&xl_state_key, xl_state_destroy);
}

State *xl_current_state(void)
{
    pthread_once(&xl_state_once, xl_state_key_create);
    State *state = pthread_getspecific(xl_state_key);
    if (state)
        return state;
    struct xl_thread *thread;
    if (posix_memalign((void **)&thread, 16, XL_THREAD_HEADER + XL_STATE_SIZE))
        xl_thread_state_failed("the allocation of the state", XL_THREAD_HEADER + XL_STATE_SIZE);
    memset(thread, 0, XL_THREAD_HEADER + XL_STATE_SIZE);
    size_t first = pthread_main_np() ? XL_GUEST_STACK_MAIN
                                     : xl_stack_first(pthread_get_stacksize_np(pthread_self()), XL_GUEST_STACK_FLOOR, XL_GUEST_STACK_THREAD);
    thread->stack = xl_stack_map(first, XL_GUEST_STACK_FLOOR, xl_map_anonymous, &thread->stack_size, &thread->guard_size);
    if (thread->stack == MAP_FAILED)
        xl_thread_state_failed("the mapping of the guest stack", XL_GUEST_STACK_FLOOR);
    size_t size = thread->stack_size;
    __atomic_fetch_add(&xl_threads_created, 1, __ATOMIC_RELAXED);
    __atomic_fetch_add(&xl_threads_stack_live, (uint32_t)size, __ATOMIC_RELAXED);
    if (size < first || xl_stats_enabled())
        xl_threads_report(size < first ? "created with a halved stack" : "created", size,
                          pthread_main_np() ? 0 : pthread_get_stacksize_np(pthread_self()));
    thread->tsd_pages = xl_tsd_alloc();
    state = (State *)((char *)thread + XL_THREAD_HEADER);
    XL_REG(state, TPIDRRO_EL0) = xl_tsd_base(thread->tsd_pages);
    XL_REG(state, SP) = ((uintptr_t)thread->stack + size) & ~15u;
    pthread_setspecific(xl_state_key, state);
    if (xl_diagnostics_installed)
        xl_thread_altstack();
    return state;
}

#define XL_LOG_DIR "/private/var/revenant/"
#define XL_LOG_LIMIT (1 << 20)

int xl_log_enabled(void)
{
    static int enabled = -1;
    if (enabled < 0)
        enabled = getenv("XL_LOG") != NULL || access(XL_LOG_DIR "xl-log", F_OK) == 0;
    return enabled;
}

int xl_log_open(const char *name)
{
    if (!xl_log_enabled())
        return -1;
    char file[128];
    strlcpy(file, XL_LOG_DIR, sizeof file);
    strlcat(file, name, sizeof file);
    int fd = open(file, O_WRONLY | O_CREAT | O_APPEND, 0666);
    struct stat info;
    if (fd >= 0 && fstat(fd, &info) == 0 && info.st_size > XL_LOG_LIMIT)
        ftruncate(fd, 0);
    return fd;
}

static void xl_walk_frames(State *state, int fd);

static void xl_dump(State *state)
{
    fprintf(stderr, "xlate: pc=0x%llx lr=0x%llx sp=0x%llx\n", XL_REG(state, PC), XL_REG(state, X30), XL_REG(state, SP));
    for (int i = 0; i < 8; i++)
        fprintf(stderr, "xlate: x%d=0x%llx\n", i, *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i));
    xl_walk_frames(state, fileno(stderr));
    if (xl_map_on)
        xl_vm_map_dump(fileno(stderr), "fault");
}

void xl_fault(State *state, const char *reason)
{
    fprintf(stderr, "xlate: %s\n", reason);
    int log_fd = xl_log_open("xlate-crash.log");
    if (log_fd >= 0) {
        dprintf(log_fd, "xlate: %s\n", reason);
        close(log_fd);
    }
    xl_dump(state);
    abort();
}

static void xl_walk_guest(int fd)
{
    State *state = xl_current_state();
    dprintf(fd, "xlate: guest pc=0x%llx lr=0x%llx sp=0x%llx\n", XL_REG(state, PC), XL_REG(state, X30), XL_REG(state, SP));
    for (int i = 0; i < 8; i++)
        dprintf(fd, "xlate: guest x%d=0x%llx\n", i, *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i));
    xl_walk_frames(state, fd);
}

static void xl_walk_frames(State *state, int fd)
{
    uint64_t fp = XL_REG(state, X29);
    for (int depth = 0; depth < 16 && fp && fp >> 32 == 0; depth++) {
        uint64_t saved_fp = *(uint64_t *)(uintptr_t)fp;
        uint64_t saved_lr = *(uint64_t *)(uintptr_t)(fp + 8);
        dprintf(fd, "xlate: guest frame %d fp=0x%llx lr=0x%llx\n", depth, fp, saved_lr);
        if (saved_fp <= fp)
            break;
        fp = saved_fp;
    }
}

void xl_report_guest_frame(void)
{
    xl_walk_guest(fileno(stderr));
}

static int xl_crash_fd(void);

void xl_log_guest_frames(const char *why)
{
    int fd = xl_crash_fd();
    dprintf(fd, "xlate: %s\n", why);
    xl_walk_guest(fd);
    if (fd != fileno(stderr))
        close(fd);
}

static int xl_crash_fd(void)
{
    int fd = xl_log_open("xlate-crash.log");
    return fd >= 0 ? fd : fileno(stderr);
}

static volatile sig_atomic_t xl_crashing;

static void xl_crash_handler(int signal, siginfo_t *info, void *context)
{
    if (xl_crashing) {
        struct sigaction reset = {0};
        reset.sa_handler = SIG_DFL;
        sigaction(signal, &reset, NULL);
        raise(signal);
        return;
    }
    xl_crashing = 1;
    int fd = xl_crash_fd();
    dprintf(fd, "xlate: signal %d at fault 0x%lx\n", signal, (unsigned long)(info ? info->si_addr : 0));
    if (info && (signal == SIGSEGV || signal == SIGBUS) && xl_diagnostics_installed) {
        void *current = pthread_getspecific(xl_state_key);
        if (current) {
            struct xl_thread *thread = (struct xl_thread *)((char *)current - XL_THREAD_HEADER);
            uintptr_t low = (uintptr_t)thread->stack, fault = (uintptr_t)info->si_addr;
            if (thread->guard_size && fault >= low && fault < low + thread->guard_size)
                dprintf(fd, "xlate: the guest stack of this thread overflowed: it holds %lu bytes (0x%lx to 0x%lx) and the fault is in its guard page; guest frames deeper than that need a larger XL_GUEST_STACK_THREAD (XL_GUEST_STACK_MAIN for the main thread) in runtime.c\n",
                        (unsigned long)thread->stack_size, (unsigned long)low, (unsigned long)(low + thread->stack_size));
        }
    }
    ucontext_t *uc = context;
    if (uc) {
        _STRUCT_ARM_THREAD_STATE *ss = &uc->uc_mcontext->__ss;
        dprintf(fd, "xlate: host pc=0x%x lr=0x%x sp=0x%x cpsr=0x%x\n", ss->__pc, ss->__lr, ss->__sp, ss->__cpsr);
        for (int i = 0; i < 13; i++)
            dprintf(fd, "xlate: host r%d=0x%x\n", i, ss->__r[i]);
        {
            Dl_info info;
            if (dladdr((void *)(uintptr_t)ss->__pc, &info) && info.dli_fbase) {
                const char *image = info.dli_fname ? strrchr(info.dli_fname, '/') : NULL;
                dprintf(fd, "xlate: host pc in %s image %s base 0x%lx offset 0x%lx\n", info.dli_sname ? info.dli_sname : "?", image ? image + 1 : info.dli_fname ? info.dli_fname : "?",
                        (unsigned long)info.dli_fbase, (unsigned long)(ss->__pc - (uint32_t)(uintptr_t)info.dli_fbase));
            }
            if (dladdr((void *)(uintptr_t)ss->__pc, &info) && info.dli_sname) {
                vm_size_t got = 0;
                uint32_t words[4] = {0, 0, 0, 0};
                if (!strncmp(info.dli_sname, "objc_msgSend", 12) && ss->__r[0] > 0x1000 &&
                    vm_read_overwrite(mach_task_self(), ss->__r[0], sizeof words, (vm_address_t)words, &got) == KERN_SUCCESS)
                    dprintf(fd, "xlate: host message receiver 0x%x holds 0x%x 0x%x 0x%x 0x%x\n", ss->__r[0], words[0], words[1], words[2], words[3]);
            }
        }
        dprintf(fd, "xlate: host frame 0 lr=0x%x\n", ss->__lr);
        uint32_t hfp = ss->__r[7];
        for (int depth = 1; depth < 24 && hfp && (hfp & 3) == 0; depth++) {
            uint32_t next = *(uint32_t *)(uintptr_t)hfp;
            uint32_t hlr = *(uint32_t *)(uintptr_t)(hfp + 4);
            Dl_info info;
            const char *name = dladdr((void *)(uintptr_t)hlr, &info) && info.dli_sname ? info.dli_sname : "?";
            const char *image = info.dli_fname ? strrchr(info.dli_fname, '/') : NULL;
            dprintf(fd, "xlate: host frame %d lr=0x%x %s (%s +0x%lx)\n", depth, hlr, name, image ? image + 1 : "?", info.dli_fbase ? (unsigned long)(hlr - (uint32_t)(uintptr_t)info.dli_fbase) : 0ul);
            if (next <= hfp)
                break;
            hfp = next;
        }
    }
    if (xl_map_on)
        xl_vm_map_dump(fd, "crash");
    xl_walk_guest(fd);
    if (fd != fileno(stderr))
        close(fd);
    struct sigaction reset = {0};
    reset.sa_handler = SIG_DFL;
    sigaction(signal, &reset, NULL);
    raise(signal);
}

static void xl_note_exit(void)
{
    int fd = xl_log_open("xl-exit.log");
    if (fd < 0)
        return;
    dprintf(fd, "xlate: process exiting normally (pid %d)\n", (int)getpid());
    xl_walk_guest(fd);
    close(fd);
}

static void xl_signal_note(int signal, siginfo_t *info, void *context)
{
    (void)info; (void)context;
    int fd = xl_log_open("xl-exit.log");
    if (fd >= 0) {
        dprintf(fd, "xlate: terminated by signal %d (pid %d)\n", signal, (int)getpid());
        xl_walk_guest(fd);
        close(fd);
    }
    struct sigaction reset = {0};
    reset.sa_handler = SIG_DFL;
    sigaction(signal, &reset, NULL);
    raise(signal);
}

void xl_install_diagnostics(void)
{
    if (__sync_lock_test_and_set(&xl_diagnostics_installed, 1))
        return;
    xl_map_on = xl_vm_map_enabled();
    atexit(xl_note_exit);
    {
        struct sigaction note = {0};
        note.sa_sigaction = xl_signal_note;
        note.sa_flags = SA_SIGINFO | SA_ONSTACK;
        sigemptyset(&note.sa_mask);
        for (int i = 0; i < 10; i++)
            sigaction((int[]){SIGPIPE, SIGTERM, SIGHUP, SIGQUIT, SIGFPE, SIGALRM, SIGUSR1, SIGUSR2, SIGXCPU, SIGSYS}[i], &note, NULL);
    }
    static char alt_stack[SIGSTKSZ < (64 * 1024) ? (64 * 1024) : SIGSTKSZ];
    stack_t alt = {0};
    alt.ss_sp = alt_stack;
    alt.ss_size = sizeof alt_stack;
    sigaltstack(&alt, NULL);
    struct sigaction action = {0};
    action.sa_sigaction = xl_crash_handler;
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigemptyset(&action.sa_mask);
    for (int i = 0; i < 5; i++)
        sigaction((int[]){SIGSEGV, SIGBUS, SIGILL, SIGABRT, SIGTRAP}[i], &action, NULL);
}

#ifndef XL_LIBRARY
__attribute__((constructor)) static void xl_install_crash_handler(void)
{
    xl_install_diagnostics();
}
#endif

static pthread_key_t xl_altstack_key;
static pthread_once_t xl_altstack_once = PTHREAD_ONCE_INIT;

static void xl_altstack_free(void *stack)
{
    stack_t disable = {0};
    disable.ss_flags = SS_DISABLE;
    sigaltstack(&disable, NULL);
    free(stack);
}

static void xl_altstack_setup(void) { pthread_key_create(&xl_altstack_key, xl_altstack_free); }

void xl_thread_altstack(void)
{
    pthread_once(&xl_altstack_once, xl_altstack_setup);
    if (pthread_getspecific(xl_altstack_key))
        return;
    size_t size = 64 * 1024;
    void *memory = malloc(size);
    if (!memory)
        return;
    stack_t alt = {0};
    alt.ss_sp = memory;
    alt.ss_size = size;
    if (sigaltstack(&alt, NULL) == 0)
        pthread_setspecific(xl_altstack_key, memory);
    else
        free(memory);
}

xl_lifted xl_lookup(uint64_t address)
{
    uint32_t low = 0, high = xl_function_count;
    while (low < high) {
        uint32_t middle = low + (high - low) / 2;
        if (xl_functions[middle].address < address)
            low = middle + 1;
        else
            high = middle;
    }
    if (low < xl_function_count && xl_functions[low].address == address && address >> 32 == 0)
        return xl_functions[low].function;
    return xl_imp_lookup(address);
}

static void xl_untranslated(State *state, const char *what)
{
    uint64_t pc = XL_REG(state, PC);
    char why[320];
    Dl_info info;
    if (!(pc >> 32) && dladdr((const void *)(uintptr_t)pc, &info) && info.dli_sname && info.dli_fname) {
        const char *image = strrchr(info.dli_fname, '/');
        snprintf(why, sizeof why, "%s; 0x%llx is %s+%lu of %s, code of the host that reached translated code as an address", what, (unsigned long long)pc,
                 info.dli_sname, (unsigned long)((uintptr_t)pc & ~(uintptr_t)1) - ((unsigned long)info.dli_saddr & ~1ul), image ? image + 1 : info.dli_fname);
        xl_fault(state, why);
    }
    xl_fault(state, what);
}

void xl_call(State *state)
{
    xl_lifted function = xl_lookup(XL_REG(state, PC));
    if (!function)
        xl_untranslated(state, "call to an address without translated code (or an unsupported instruction)");
    function(state);
}

void xl_tail(State *state)
{
    xl_lifted function = xl_lookup(XL_REG(state, PC));
    if (!function)
        xl_untranslated(state, "jump to an address that does not start a translated function (or an unsupported instruction)");
    [[clang::musttail]] return function(state);
}

uint64_t xl_invoke(uint64_t address, uint64_t argument)
{
    xl_ensure_ready();
    State *state = xl_current_state();
    xl_lifted function = xl_lookup(address);
    if (!function)
    {
        char why[96];
        snprintf(why, sizeof why, "callback into address 0x%llx without translated code", (unsigned long long)address);
        xl_fault(state, why);
    }
    uint64_t saved_pc = XL_REG(state, PC), saved_lr = XL_REG(state, X30);
    XL_REG(state, PC) = address;
    XL_REG(state, X0) = argument;
    XL_REG(state, X30) = 0;
    function(state);
    uint64_t result = XL_REG(state, X0);
    XL_REG(state, PC) = saved_pc;
    XL_REG(state, X30) = saved_lr;
    return result;
}

uint64_t xl_invoke_n(uint64_t address, const uint64_t *arguments, unsigned count)
{
    xl_ensure_ready();
    State *state = xl_current_state();
    xl_lifted function = xl_lookup(address);
    if (!function)
    {
        char why[96];
        snprintf(why, sizeof why, "callback into address 0x%llx without translated code", (unsigned long long)address);
        xl_fault(state, why);
    }
    uint64_t saved_pc = XL_REG(state, PC), saved_lr = XL_REG(state, X30);
    uint64_t saved_arg[8];
    for (unsigned i = 0; i < 8; i++)
        saved_arg[i] = *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i);
    for (unsigned i = 0; i < count && i < 8; i++)
        *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i) = arguments[i];
    XL_REG(state, PC) = address;
    XL_REG(state, X30) = 0;
    function(state);
    uint64_t result = XL_REG(state, X0);
    XL_REG(state, PC) = saved_pc;
    XL_REG(state, X30) = saved_lr;
    for (unsigned i = 0; i < 8; i++)
        *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i) = saved_arg[i];
    return result;
}

uint64_t xl_invoke_registers(uint64_t address, const uint64_t *integers, unsigned integer_count, const uint64_t *floats, unsigned float_count, uint64_t *float_result)
{
    xl_ensure_ready();
    State *state = xl_current_state();
    xl_lifted function = xl_lookup(address);
    if (!function)
    {
        char why[96];
        snprintf(why, sizeof why, "callback into address 0x%llx without translated code", (unsigned long long)address);
        xl_fault(state, why);
    }
    uint64_t saved_pc = XL_REG(state, PC), saved_lr = XL_REG(state, X30);
    uint64_t saved_integer[8], saved_float[8];
    for (unsigned i = 0; i < 8; i++) {
        saved_integer[i] = *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i);
        saved_float[i] = *(uint64_t *)((char *)state + XL_OFFSET_V0 + 16 * i);
    }
    for (unsigned i = 0; i < integer_count && i < 8; i++)
        *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i) = integers[i];
    for (unsigned i = 0; i < float_count && i < 8; i++) {
        *(uint64_t *)((char *)state + XL_OFFSET_V0 + 16 * i) = floats[i];
        *(uint64_t *)((char *)state + XL_OFFSET_V0 + 16 * i + 8) = 0;
    }
    XL_REG(state, PC) = address;
    XL_REG(state, X30) = 0;
    function(state);
    uint64_t result = XL_REG(state, X0);
    if (float_result)
        *float_result = *(uint64_t *)((char *)state + XL_OFFSET_V0);
    XL_REG(state, PC) = saved_pc;
    XL_REG(state, X30) = saved_lr;
    for (unsigned i = 0; i < 8; i++) {
        *(uint64_t *)((char *)state + XL_OFFSET_X0 + (XL_OFFSET_X1 - XL_OFFSET_X0) * i) = saved_integer[i];
        *(uint64_t *)((char *)state + XL_OFFSET_V0 + 16 * i) = saved_float[i];
    }
    return result;
}

#ifndef XL_LIBRARY
static uint64_t *xl_guest_vector(char **vector)
{
    size_t count = 0;
    while (vector && vector[count])
        count++;
    uint64_t *copy = calloc(count + 1, sizeof *copy);
    for (size_t i = 0; i < count; i++)
        copy[i] = (uintptr_t)vector[i];
    return copy;
}

extern void xl_register_application_classes(void);
extern void xl_run_initializers(void);

int main(int argc, char **argv, char **envp, char **apple)
{
    xl_register_application_classes();
    xl_run_initializers();
    State *state = xl_current_state();
    XL_REG(state, X0) = (uint64_t)argc;
    XL_REG(state, X1) = (uintptr_t)xl_guest_vector(argv);
    XL_REG(state, X2) = (uintptr_t)xl_guest_vector(envp);
    XL_REG(state, X3) = (uintptr_t)xl_guest_vector(apple);
    XL_REG(state, X30) = 0;
    xl_lifted entry = xl_lookup(xl_entry_address);
    XL_REG(state, PC) = xl_entry_address;
    if (!entry)
        xl_fault(state, "entry point was not translated");
    entry(state);
    return (int)(uint32_t)XL_REG(state, X0);
}
#endif
