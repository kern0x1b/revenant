#import <Foundation/Foundation.h>

#include "xl_bridge.h"
#include "xl_diag.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <unistd.h>

#undef p_forw
#undef p_back
#undef p_starttime

#define XL_CTL_SYSCTL 0
#define XL_CTL_SYSCTL_NAME 1
#define XL_CTL_SYSCTL_OIDFMT 4
#define XL_PF_ROUTE 17
#define XL_NET_RT_DUMP 1
#define XL_NET_RT_FLAGS 2

struct xl_guest_timeval {
    int64_t tv_sec;
    int32_t tv_usec;
    int32_t padding;
};

struct xl_guest_loadavg {
    uint32_t ldavg[3];
    uint32_t padding;
    int64_t fscale;
};

struct xl_guest_extern_proc {
    struct xl_guest_timeval p_starttime;
    uint64_t p_vmspace;
    uint64_t p_sigacts;
    int32_t p_flag;
    int8_t p_stat;
    uint8_t padding0[3];
    int32_t p_pid;
    int32_t p_oppid;
    int32_t p_dupfd;
    int32_t padding1;
    uint64_t user_stack;
    uint64_t exit_thread;
    int32_t p_debugger;
    int32_t sigwait;
    uint32_t p_estcpu;
    int32_t p_cpticks;
    uint32_t p_pctcpu;
    int32_t padding2;
    uint64_t p_wchan;
    uint64_t p_wmesg;
    uint32_t p_swtime;
    uint32_t p_slptime;
    struct xl_guest_timeval p_realtimer_interval;
    struct xl_guest_timeval p_realtimer_value;
    struct xl_guest_timeval p_rtime;
    uint64_t p_uticks;
    uint64_t p_sticks;
    uint64_t p_iticks;
    int32_t p_traceflag;
    int32_t padding3;
    uint64_t p_tracep;
    int32_t p_siglist;
    int32_t padding4;
    uint64_t p_textvp;
    int32_t p_holdcnt;
    uint32_t p_sigmask;
    uint32_t p_sigignore;
    uint32_t p_sigcatch;
    uint8_t p_priority;
    uint8_t p_usrpri;
    int8_t p_nice;
    char p_comm[17];
    uint8_t padding5[4];
    uint64_t p_pgrp;
    uint64_t p_addr;
    uint16_t p_xstat;
    uint16_t p_acflag;
    uint8_t padding6[4];
    uint64_t p_ru;
};

struct xl_guest_pcred {
    char pc_lock[72];
    uint64_t pc_ucred;
    uint32_t p_ruid;
    uint32_t p_svuid;
    uint32_t p_rgid;
    uint32_t p_svgid;
    int32_t p_refcnt;
    int32_t padding;
};

struct xl_guest_ucred {
    int32_t cr_ref;
    uint32_t cr_uid;
    int16_t cr_ngroups;
    int16_t padding;
    uint32_t cr_groups[16];
};

struct xl_guest_vmspace {
    int32_t dummy;
    int32_t padding0;
    uint64_t dummy2;
    int32_t dummy3[5];
    int32_t padding1;
    uint64_t dummy4[3];
};

struct xl_guest_eproc {
    uint64_t e_paddr;
    uint64_t e_sess;
    struct xl_guest_pcred e_pcred;
    struct xl_guest_ucred e_ucred;
    int32_t padding0;
    struct xl_guest_vmspace e_vm;
    int32_t e_ppid;
    int32_t e_pgid;
    int16_t e_jobc;
    int16_t padding1;
    uint32_t e_tdev;
    int32_t e_tpgid;
    int32_t padding2;
    uint64_t e_tsess;
    char e_wmesg[8];
    int32_t e_xsize;
    int16_t e_xrssize;
    int16_t e_xccount;
    int16_t e_xswrss;
    int16_t padding3;
    int32_t e_flag;
    char e_login[12];
    int32_t e_spare[4];
    int32_t padding4;
};

struct xl_guest_kinfo_proc {
    struct xl_guest_extern_proc kp_proc;
    struct xl_guest_eproc kp_eproc;
};

_Static_assert(sizeof(struct xl_guest_timeval) == 16 && sizeof(struct xl_guest_loadavg) == 24 && offsetof(struct xl_guest_loadavg, fscale) == 16,
               "arm64 struct timeval and struct loadavg");
_Static_assert(offsetof(struct xl_guest_extern_proc, p_vmspace) == 16 && offsetof(struct xl_guest_extern_proc, p_flag) == 32 &&
                   offsetof(struct xl_guest_extern_proc, p_pid) == 40 && offsetof(struct xl_guest_extern_proc, user_stack) == 56 &&
                   offsetof(struct xl_guest_extern_proc, p_debugger) == 72 && offsetof(struct xl_guest_extern_proc, p_pctcpu) == 88 &&
                   offsetof(struct xl_guest_extern_proc, p_wchan) == 96 && offsetof(struct xl_guest_extern_proc, p_swtime) == 112 &&
                   offsetof(struct xl_guest_extern_proc, p_realtimer_interval) == 120 && offsetof(struct xl_guest_extern_proc, p_rtime) == 152 &&
                   offsetof(struct xl_guest_extern_proc, p_uticks) == 168 && offsetof(struct xl_guest_extern_proc, p_traceflag) == 192 &&
                   offsetof(struct xl_guest_extern_proc, p_tracep) == 200 && offsetof(struct xl_guest_extern_proc, p_siglist) == 208 &&
                   offsetof(struct xl_guest_extern_proc, p_textvp) == 216 && offsetof(struct xl_guest_extern_proc, p_holdcnt) == 224 &&
                   offsetof(struct xl_guest_extern_proc, p_priority) == 240 && offsetof(struct xl_guest_extern_proc, p_comm) == 243 &&
                   offsetof(struct xl_guest_extern_proc, p_pgrp) == 264 && offsetof(struct xl_guest_extern_proc, p_xstat) == 280 &&
                   offsetof(struct xl_guest_extern_proc, p_ru) == 288 && sizeof(struct xl_guest_extern_proc) == 296,
               "arm64 struct extern_proc");
_Static_assert(offsetof(struct xl_guest_eproc, e_pcred) == 16 && offsetof(struct xl_guest_eproc, e_ucred) == 120 &&
                   offsetof(struct xl_guest_eproc, e_vm) == 200 && offsetof(struct xl_guest_eproc, e_ppid) == 264 &&
                   offsetof(struct xl_guest_eproc, e_jobc) == 272 && offsetof(struct xl_guest_eproc, e_tdev) == 276 &&
                   offsetof(struct xl_guest_eproc, e_tsess) == 288 && offsetof(struct xl_guest_eproc, e_wmesg) == 296 &&
                   offsetof(struct xl_guest_eproc, e_xsize) == 304 && offsetof(struct xl_guest_eproc, e_flag) == 316 &&
                   offsetof(struct xl_guest_eproc, e_login) == 320 && offsetof(struct xl_guest_eproc, e_spare) == 332 &&
                   sizeof(struct xl_guest_eproc) == 352 && sizeof(struct xl_guest_pcred) == 104 && sizeof(struct xl_guest_ucred) == 76 &&
                   sizeof(struct xl_guest_vmspace) == 64 && offsetof(struct xl_guest_ucred, cr_groups) == 12,
               "arm64 struct eproc");
_Static_assert(offsetof(struct xl_guest_kinfo_proc, kp_eproc) == 296 && sizeof(struct xl_guest_kinfo_proc) == 648, "arm64 struct kinfo_proc");

enum xl_sysctl_kind {
    XL_SYSCTL_PASS = 1,
    XL_SYSCTL_LONG,
    XL_SYSCTL_ULONG,
    XL_SYSCTL_TIMEVAL,
    XL_SYSCTL_LOADAVG,
    XL_SYSCTL_PROC,
    XL_SYSCTL_NONE,
};

static void xl_guest_timeval_from(struct xl_guest_timeval *guest, const struct timeval *host)
{
    guest->tv_sec = host->tv_sec;
    guest->tv_usec = host->tv_usec;
    guest->padding = 0;
}

static void xl_guest_kinfo_proc_from(struct xl_guest_kinfo_proc *guest, const struct kinfo_proc *host)
{
    memset(guest, 0, sizeof *guest);
    const struct extern_proc *hp = &host->kp_proc;
    struct xl_guest_extern_proc *gp = &guest->kp_proc;
    xl_guest_timeval_from(&gp->p_starttime, &hp->p_un.__p_starttime);
    gp->p_vmspace = (uintptr_t)hp->p_vmspace;
    gp->p_sigacts = (uintptr_t)hp->p_sigacts;
    gp->p_flag = hp->p_flag;
    gp->p_stat = hp->p_stat;
    gp->p_pid = hp->p_pid;
    gp->p_oppid = hp->p_oppid;
    gp->p_dupfd = hp->p_dupfd;
    gp->user_stack = (uintptr_t)hp->user_stack;
    gp->exit_thread = (uintptr_t)hp->exit_thread;
    gp->p_debugger = hp->p_debugger;
    gp->sigwait = hp->sigwait;
    gp->p_estcpu = hp->p_estcpu;
    gp->p_cpticks = hp->p_cpticks;
    gp->p_pctcpu = hp->p_pctcpu;
    gp->p_wchan = (uintptr_t)hp->p_wchan;
    gp->p_wmesg = (uintptr_t)hp->p_wmesg;
    gp->p_swtime = hp->p_swtime;
    gp->p_slptime = hp->p_slptime;
    xl_guest_timeval_from(&gp->p_realtimer_interval, &hp->p_realtimer.it_interval);
    xl_guest_timeval_from(&gp->p_realtimer_value, &hp->p_realtimer.it_value);
    xl_guest_timeval_from(&gp->p_rtime, &hp->p_rtime);
    gp->p_uticks = hp->p_uticks;
    gp->p_sticks = hp->p_sticks;
    gp->p_iticks = hp->p_iticks;
    gp->p_traceflag = hp->p_traceflag;
    gp->p_tracep = (uintptr_t)hp->p_tracep;
    gp->p_siglist = hp->p_siglist;
    gp->p_textvp = (uintptr_t)hp->p_textvp;
    gp->p_holdcnt = hp->p_holdcnt;
    gp->p_sigmask = hp->p_sigmask;
    gp->p_sigignore = hp->p_sigignore;
    gp->p_sigcatch = hp->p_sigcatch;
    gp->p_priority = hp->p_priority;
    gp->p_usrpri = hp->p_usrpri;
    gp->p_nice = hp->p_nice;
    _Static_assert(sizeof gp->p_comm == sizeof hp->p_comm, "p_comm");
    memcpy(gp->p_comm, hp->p_comm, sizeof gp->p_comm);
    gp->p_pgrp = (uintptr_t)hp->p_pgrp;
    gp->p_addr = (uintptr_t)hp->p_addr;
    gp->p_xstat = hp->p_xstat;
    gp->p_acflag = hp->p_acflag;
    gp->p_ru = (uintptr_t)hp->p_ru;
    const struct eproc *he = &host->kp_eproc;
    struct xl_guest_eproc *ge = &guest->kp_eproc;
    ge->e_paddr = (uintptr_t)he->e_paddr;
    ge->e_sess = (uintptr_t)he->e_sess;
    _Static_assert(sizeof ge->e_pcred.pc_lock == sizeof he->e_pcred.pc_lock, "pc_lock");
    memcpy(ge->e_pcred.pc_lock, he->e_pcred.pc_lock, sizeof ge->e_pcred.pc_lock);
    ge->e_pcred.pc_ucred = (uintptr_t)he->e_pcred.pc_ucred;
    ge->e_pcred.p_ruid = he->e_pcred.p_ruid;
    ge->e_pcred.p_svuid = he->e_pcred.p_svuid;
    ge->e_pcred.p_rgid = he->e_pcred.p_rgid;
    ge->e_pcred.p_svgid = he->e_pcred.p_svgid;
    ge->e_pcred.p_refcnt = he->e_pcred.p_refcnt;
    ge->e_ucred.cr_ref = he->e_ucred.cr_ref;
    ge->e_ucred.cr_uid = he->e_ucred.cr_uid;
    ge->e_ucred.cr_ngroups = he->e_ucred.cr_ngroups;
    _Static_assert(sizeof ge->e_ucred.cr_groups == sizeof he->e_ucred.cr_groups, "cr_groups");
    memcpy(ge->e_ucred.cr_groups, he->e_ucred.cr_groups, sizeof ge->e_ucred.cr_groups);
    ge->e_vm.dummy = he->e_vm.dummy;
    ge->e_vm.dummy2 = (uintptr_t)he->e_vm.dummy2;
    _Static_assert(sizeof ge->e_vm.dummy3 == sizeof he->e_vm.dummy3, "dummy3");
    memcpy(ge->e_vm.dummy3, he->e_vm.dummy3, sizeof ge->e_vm.dummy3);
    for (unsigned i = 0; i < 3; i++)
        ge->e_vm.dummy4[i] = (uintptr_t)he->e_vm.dummy4[i];
    ge->e_ppid = he->e_ppid;
    ge->e_pgid = he->e_pgid;
    ge->e_jobc = he->e_jobc;
    ge->e_tdev = he->e_tdev;
    ge->e_tpgid = he->e_tpgid;
    ge->e_tsess = (uintptr_t)he->e_tsess;
    memcpy(ge->e_wmesg, he->e_wmesg, sizeof ge->e_wmesg);
    ge->e_xsize = he->e_xsize;
    ge->e_xrssize = he->e_xrssize;
    ge->e_xccount = he->e_xccount;
    ge->e_xswrss = he->e_xswrss;
    ge->e_flag = he->e_flag;
    memcpy(ge->e_login, he->e_login, sizeof ge->e_login);
}

static int xl_sysctl_static_kind(const int *mib, unsigned count)
{
    if (count >= 1 && mib[0] == XL_CTL_SYSCTL)
        return XL_SYSCTL_PASS;
    if (count >= 2 && mib[0] == CTL_KERN) {
        switch (mib[1]) {
        case KERN_BOOTTIME:
            return count == 2 ? XL_SYSCTL_TIMEVAL : XL_SYSCTL_NONE;
        case KERN_PROCARGS:
        case KERN_PROCARGS2:
            return XL_SYSCTL_PASS;
        case KERN_PROC:
            if (count == 4 || (count == 3 && mib[2] == KERN_PROC_ALL)) {
                switch (mib[2]) {
                case KERN_PROC_ALL:
                case KERN_PROC_PID:
                case KERN_PROC_PGRP:
                case KERN_PROC_SESSION:
                case KERN_PROC_TTY:
                case KERN_PROC_UID:
                case KERN_PROC_RUID:
                case KERN_PROC_LCID:
                    return XL_SYSCTL_PROC;
                }
            }
            return XL_SYSCTL_NONE;
        }
    }
    if (count == 2 && mib[0] == CTL_VM && mib[1] == VM_LOADAVG)
        return XL_SYSCTL_LOADAVG;
    if (count >= 2 && mib[0] == CTL_NET && mib[1] == XL_PF_ROUTE) {
        if (count >= 5 && (mib[4] == XL_NET_RT_DUMP || mib[4] == XL_NET_RT_FLAGS))
            return XL_SYSCTL_PASS;
        return XL_SYSCTL_NONE;
    }
    return 0;
}

static int xl_sysctl_format_kind(const int *mib, unsigned count)
{
    if (count > CTL_MAXNAME)
        return XL_SYSCTL_NONE;
    int query[CTL_MAXNAME + 2];
    query[0] = XL_CTL_SYSCTL;
    query[1] = XL_CTL_SYSCTL_OIDFMT;
    memcpy(query + 2, mib, count * sizeof(int));
    char buffer[128];
    size_t length = sizeof buffer;
    if (sysctl(query, count + 2, buffer, &length, NULL, 0) || length < 4)
        return XL_SYSCTL_NONE;
    unsigned type = *(unsigned *)buffer & CTLTYPE;
    const char *format = buffer + 4;
    buffer[sizeof buffer - 1] = 0;
    if (!strcmp(format, "L"))
        return XL_SYSCTL_LONG;
    if (!strcmp(format, "LU"))
        return XL_SYSCTL_ULONG;
    if (!strcmp(format, "S,timeval"))
        return XL_SYSCTL_TIMEVAL;
    if (!strcmp(format, "S,loadavg"))
        return XL_SYSCTL_LOADAVG;
    if (!strcmp(format, "S,clockinfo") || !strcmp(format, "S,xsw_usage"))
        return XL_SYSCTL_PASS;
    if (type == CTLTYPE_INT || type == CTLTYPE_QUAD || type == CTLTYPE_STRING || type == CTLTYPE_NODE)
        return XL_SYSCTL_PASS;
    return XL_SYSCTL_NONE;
}

#define XL_SYSCTL_CACHE 64
#define XL_SYSCTL_CACHE_MIB 8

static struct {
    unsigned count;
    int mib[XL_SYSCTL_CACHE_MIB];
    int kind;
} xl_sysctl_cache[XL_SYSCTL_CACHE];
static pthread_mutex_t xl_sysctl_lock = PTHREAD_MUTEX_INITIALIZER;

static int xl_sysctl_kind(const int *mib, unsigned count)
{
    int kind = xl_sysctl_static_kind(mib, count);
    if (kind)
        return kind;
    unsigned hash = count;
    for (unsigned i = 0; i < count; i++)
        hash = hash * 31u + (unsigned)mib[i];
    unsigned slot = hash % XL_SYSCTL_CACHE;
    int cacheable = count <= XL_SYSCTL_CACHE_MIB;
    if (cacheable) {
        pthread_mutex_lock(&xl_sysctl_lock);
        if (xl_sysctl_cache[slot].count == count && !memcmp(xl_sysctl_cache[slot].mib, mib, count * sizeof(int)))
            kind = xl_sysctl_cache[slot].kind;
        pthread_mutex_unlock(&xl_sysctl_lock);
        if (kind)
            return kind;
    }
    kind = xl_sysctl_format_kind(mib, count);
    if (cacheable) {
        pthread_mutex_lock(&xl_sysctl_lock);
        xl_sysctl_cache[slot].count = count;
        memcpy(xl_sysctl_cache[slot].mib, mib, count * sizeof(int));
        xl_sysctl_cache[slot].kind = kind;
        pthread_mutex_unlock(&xl_sysctl_lock);
    }
    return kind;
}

static void xl_sysctl_name(const int *mib, unsigned count, char *text, size_t size)
{
    int query[CTL_MAXNAME + 2];
    text[0] = 0;
    if (count <= CTL_MAXNAME) {
        query[0] = XL_CTL_SYSCTL;
        query[1] = XL_CTL_SYSCTL_NAME;
        memcpy(query + 2, mib, count * sizeof(int));
        size_t length = size - 1;
        if (!sysctl(query, count + 2, text, &length, NULL, 0)) {
            text[length < size ? length : size - 1] = 0;
            return;
        }
    }
    size_t at = 0;
    for (unsigned i = 0; i < count && at + 12 < size; i++)
        at += (size_t)snprintf(text + at, size - at, i ? ".%d" : "%d", mib[i]);
    text[at < size ? at : size - 1] = 0;
}

static int xl_sysctl_trace_enabled(void)
{
    static struct xl_diag_flag trace = {"xl-sysctl-trace", 0};
    return xl_diag_on(&trace);
}

static void xl_sysctl_trace(const int *mib, unsigned count, int kind, const char *by_name, int has_old, uint64_t length_in, uint64_t length_out,
                            int has_new, uint64_t new_length, int result, int error)
{
    static volatile int64_t calls;
    int64_t number = __sync_add_and_fetch(&calls, 1);
    if (number > 50 && number % 1000)
        return;
    char name[160];
    if (by_name) {
        snprintf(name, sizeof name, "%s", by_name);
    } else {
        xl_sysctl_name(mib, count, name, sizeof name);
    }
    char line[400];
    int n = snprintf(line, sizeof line, "#%lld thread %p kind %d %s old %s in %llu out %llu new %s %llu -> %d errno %d\n", (long long)number,
                     (void *)pthread_self(), kind, name, has_old ? "buffer" : "null", (unsigned long long)length_in, (unsigned long long)length_out,
                     has_new ? "set" : "none", (unsigned long long)new_length, result, result ? error : 0);
    int fd = xl_diag_open("xl-sysctl.log", O_APPEND);
    if (fd >= 0) {
        if (n > 0)
            (void)write(fd, line, (size_t)n);
        close(fd);
    }
}

static int xl_sysctl_none(const int *mib, unsigned count, const char *by_name)
{
    size_t probe = 0;
    if (sysctl((int *)mib, count, NULL, &probe, NULL, 0))
        return -1;
    char name[160];
    if (by_name) {
        snprintf(name, sizeof name, "%s", by_name);
    } else {
        xl_sysctl_name(mib, count, name, sizeof name);
    }
    fprintf(stderr, "xlate: sysctl %s exists on this system but the bridge has no arm64 layout for its value (not an int, a quad, a string, a long, a timeval, a loadavg or a kinfo_proc), so it is not answered with the armv7 layout\n", name);
    errno = ENOTSUP;
    return -1;
}

static void xl_sysctl_store_length(uint64_t *slot, uint64_t value)
{
    if (slot)
        *slot = value;
}

static int xl_sysctl_run(const int *mib, unsigned count, const char *by_name, void *oldp, uint64_t *slot, void *newp, uint64_t new_length)
{
    int kind = xl_sysctl_kind(mib, count);
    uint64_t guest_in = slot ? *slot : 0;
    int result = -1;
    int error = 0;
    if (kind == XL_SYSCTL_NONE) {
        result = xl_sysctl_none(mib, count, by_name);
        error = errno;
        goto done;
    }
    if (kind == XL_SYSCTL_PASS) {
        size_t length = (size_t)xl_narrow_unsigned(guest_in, (uint64_t)((1ull << 32) - 1), UINT64_MAX, "sysctl", 3);
        result = sysctl((int *)mib, count, oldp, slot ? &length : NULL, newp, (size_t)xl_narrow_unsigned(new_length, (uint64_t)((1ull << 32) - 1), UINT64_MAX, "sysctl", 5));
        error = errno;
        if (slot)
            *slot = (uint64_t)length;
        goto done;
    }
    if (newp) {
        fprintf(stderr, "xlate: sysctl set of a value whose layout differs between the guest and the host is not translated\n");
        result = -1;
        error = errno = ENOTSUP;
        goto done;
    }
    if (kind == XL_SYSCTL_LONG || kind == XL_SYSCTL_ULONG) {
        if (oldp && guest_in < 8) {
            size_t length = (size_t)guest_in;
            result = sysctl((int *)mib, count, oldp, &length, NULL, 0);
            error = errno;
            xl_sysctl_store_length(slot, (uint64_t)length);
            goto done;
        }
        long value = 0;
        size_t length = oldp ? sizeof value : 0;
        result = sysctl((int *)mib, count, oldp ? &value : NULL, slot ? &length : NULL, NULL, 0);
        error = errno;
        if (!result && oldp) {
            if (kind == XL_SYSCTL_LONG) {
                int64_t wide = value;
                memcpy(oldp, &wide, sizeof wide);
            } else {
                uint64_t wide = (unsigned long)value;
                memcpy(oldp, &wide, sizeof wide);
            }
            xl_sysctl_store_length(slot, 8);
        } else if (!result) {
            xl_sysctl_store_length(slot, 8);
        }
        goto done;
    }
    if (kind == XL_SYSCTL_TIMEVAL || kind == XL_SYSCTL_LOADAVG) {
        size_t guest_size = kind == XL_SYSCTL_TIMEVAL ? sizeof(struct xl_guest_timeval) : sizeof(struct xl_guest_loadavg);
        union {
            struct timeval time;
            struct loadavg load;
        } host;
        size_t length = kind == XL_SYSCTL_TIMEVAL ? sizeof(struct timeval) : sizeof(struct loadavg);
        result = sysctl((int *)mib, count, oldp ? &host : NULL, slot ? &length : NULL, NULL, 0);
        error = errno;
        if (!result && !oldp) {
            xl_sysctl_store_length(slot, guest_size);
            goto done;
        }
        if (!result) {
            union {
                struct xl_guest_timeval time;
                struct xl_guest_loadavg load;
            } guest;
            memset(&guest, 0, sizeof guest);
            if (kind == XL_SYSCTL_TIMEVAL) {
                xl_guest_timeval_from(&guest.time, &host.time);
            } else {
                for (int i = 0; i < 3; i++)
                    guest.load.ldavg[i] = host.load.ldavg[i];
                guest.load.fscale = host.load.fscale;
            }
            if (guest_in < guest_size) {
                xl_sysctl_store_length(slot, 0);
                result = -1;
                error = errno = ENOMEM;
            } else {
                memcpy(oldp, &guest, guest_size);
                xl_sysctl_store_length(slot, guest_size);
            }
        }
        goto done;
    }
    {
        size_t host_size = sizeof(struct kinfo_proc), guest_size = sizeof(struct xl_guest_kinfo_proc);
        size_t probe = 0;
        result = sysctl((int *)mib, count, NULL, &probe, NULL, 0);
        error = errno;
        if (result)
            goto done;
        if (!oldp) {
            xl_sysctl_store_length(slot, (uint64_t)((probe + host_size - 1) / host_size * guest_size));
            goto done;
        }
        size_t size = probe > host_size ? probe : host_size;
        struct kinfo_proc *host = malloc(size);
        for (unsigned attempt = 0; host; attempt++) {
            size_t length = size;
            result = sysctl((int *)mib, count, host, &length, NULL, 0);
            error = errno;
            if (result && error == ENOMEM && attempt < 4) {
                size *= 2;
                struct kinfo_proc *grown = realloc(host, size);
                if (!grown) {
                    free(host);
                    host = NULL;
                }
                host = grown;
                continue;
            }
            probe = length;
            break;
        }
        if (!host) {
            result = -1;
            error = ENOMEM;
            xl_sysctl_store_length(slot, 0);
            goto done;
        }
        if (!result) {
            size_t listed = probe / host_size;
            if (listed * guest_size > guest_in) {
                result = -1;
                error = ENOMEM;
                xl_sysctl_store_length(slot, 0);
            } else {
                struct xl_guest_kinfo_proc *guest = oldp;
                struct xl_guest_kinfo_proc converted;
                for (size_t i = 0; i < listed; i++) {
                    xl_guest_kinfo_proc_from(&converted, &host[i]);
                    memcpy(&guest[i], &converted, guest_size);
                }
                xl_sysctl_store_length(slot, (uint64_t)(listed * guest_size));
            }
        } else if (error == ENOMEM) {
            xl_sysctl_store_length(slot, 0);
        }
        free(host);
    }
done:
    if (xl_sysctl_trace_enabled())
        xl_sysctl_trace(mib, count, kind, by_name, oldp != NULL, guest_in, slot ? *slot : 0, newp != NULL, new_length, result, error);
    errno = error;
    return result;
}

void xl_manual_sysctl(void *pack)
{
    struct __attribute__((packed)) { uint64_t name, count, oldp, oldlenp, newp, newlen, r; } *p = pack;
    unsigned count = (unsigned)xl_narrow_unsigned(p->count, (uint64_t)((1ull << 32) - 1), UINT64_MAX, "sysctl", 1);
    int mib[CTL_MAXNAME];
    if (count == 0 || count > CTL_MAXNAME || !p->name) {
        errno = EINVAL;
        p->r = (uint64_t)(int64_t)-1;
        return;
    }
    memcpy(mib, (const void *)xl_narrow_pointer(p->name, "sysctl", 0), count * sizeof(int));
    int result = xl_sysctl_run(mib, count, NULL, (void *)xl_narrow_pointer(p->oldp, "sysctl", 2),
                               (uint64_t *)xl_narrow_pointer(p->oldlenp, "sysctl", 3), (void *)xl_narrow_pointer(p->newp, "sysctl", 4), p->newlen);
    p->r = (uint64_t)(int64_t)result;
}

void xl_manual_sysctlbyname(void *pack)
{
    struct __attribute__((packed)) { uint64_t name, oldp, oldlenp, newp, newlen, r; } *p = pack;
    const char *name = (const char *)xl_narrow_pointer(p->name, "sysctlbyname", 0);
    int mib[CTL_MAXNAME];
    size_t count = CTL_MAXNAME;
    if (!name || sysctlnametomib(name, mib, &count)) {
        if (!name)
            errno = EFAULT;
        p->r = (uint64_t)(int64_t)-1;
        return;
    }
    int result = xl_sysctl_run(mib, (unsigned)count, name, (void *)xl_narrow_pointer(p->oldp, "sysctlbyname", 1),
                               (uint64_t *)xl_narrow_pointer(p->oldlenp, "sysctlbyname", 2), (void *)xl_narrow_pointer(p->newp, "sysctlbyname", 3), p->newlen);
    p->r = (uint64_t)(int64_t)result;
}
