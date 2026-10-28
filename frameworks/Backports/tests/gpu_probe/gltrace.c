#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <mach/mach.h>
#include <IOKit/IOKitLib.h>

typedef void (*ms_hook_fn)(void *symbol, void *replace, void **result);

typedef kern_return_t (*call_method_fn)(mach_port_t, uint32_t, const uint64_t *, uint32_t, const void *, size_t, uint64_t *, uint32_t *, void *, size_t *);
typedef kern_return_t (*call_scalar_fn)(mach_port_t, uint32_t, const uint64_t *, uint32_t, uint64_t *, uint32_t *);
typedef kern_return_t (*call_struct_fn)(mach_port_t, uint32_t, const void *, size_t, void *, size_t *);
typedef kern_return_t (*service_open_fn)(io_service_t, mach_port_t, uint32_t, io_connect_t *);
typedef CFMutableDictionaryRef (*matching_fn)(const char *);
typedef io_service_t (*get_service_fn)(mach_port_t, CFDictionaryRef);
typedef kern_return_t (*get_services_fn)(mach_port_t, CFDictionaryRef, io_iterator_t *);
typedef kern_return_t (*map_memory_fn)(io_connect_t, uint32_t, mach_port_t, vm_address_t *, vm_size_t *, uint32_t);

static call_method_fn o_call_method;
static call_scalar_fn o_call_scalar;
static call_struct_fn o_call_struct;
static service_open_fn o_service_open;
static matching_fn o_matching;
static get_service_fn o_get_service;
static get_services_fn o_get_services;
static map_memory_fn o_map_memory;

static int log_fd = -1;

struct conn_entry {
    mach_port_t port;
    char cls[128];
    uint32_t type;
};
static struct conn_entry conns[128];
static int nconns;

static void emit(const char *fmt, ...) {
    char buf[1536];
    va_list ap;
    int n;
    if (log_fd < 0) return;
    va_start(ap, fmt);
    n = vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (n > 0) write(log_fd, buf, n < (int)sizeof buf ? n : (int)sizeof buf - 1);
}

static void hexdump(char *dst, size_t cap, const void *src, size_t len) {
    static const char digits[] = "0123456789abcdef";
    const unsigned char *b = src;
    size_t i, o = 0;
    if (!src) {
        snprintf(dst, cap, "-");
        return;
    }
    if (len > 96) len = 96;
    for (i = 0; i < len && o + 2 < cap; i++) {
        dst[o++] = digits[b[i] >> 4];
        dst[o++] = digits[b[i] & 15];
    }
    dst[o] = 0;
}

static void words(char *dst, size_t cap, const uint64_t *v, uint32_t n) {
    size_t o = 0;
    uint32_t i;
    dst[0] = 0;
    if (!v) {
        snprintf(dst, cap, "-");
        return;
    }
    if (n > 16) n = 16;
    for (i = 0; i < n && o + 20 < cap; i++) {
        o += snprintf(dst + o, cap - o, "%llx ", (unsigned long long)v[i]);
    }
}

static const char *conn_class(mach_port_t port) {
    int i;
    for (i = nconns - 1; i >= 0; i--) {
        if (conns[i].port == port) return conns[i].cls;
    }
    return "?";
}

static kern_return_t h_call_method(mach_port_t c, uint32_t sel, const uint64_t *in, uint32_t inc, const void *ins, size_t insz, uint64_t *out, uint32_t *outc, void *outs, size_t *outsz) {
    kern_return_t kr = o_call_method(c, sel, in, inc, ins, insz, out, outc, outs, outsz);
    char win[320], hin[200], wout[320], hout[200];
    uint32_t oc = outc ? *outc : 0;
    size_t os = outsz ? *outsz : 0;
    words(win, sizeof win, in, inc);
    hexdump(hin, sizeof hin, ins, insz);
    words(wout, sizeof wout, out, oc);
    hexdump(hout, sizeof hout, outs, os);
    emit("CallMethod conn=%u cls=%s sel=%u in#=%u in=[%s] inStruct(%zu)=%s out#=%u out=[%s] outStruct(%zu)=%s kr=0x%x\n",
         c, conn_class(c), sel, inc, win, insz, hin, oc, wout, os, hout, kr);
    return kr;
}

static kern_return_t h_call_scalar(mach_port_t c, uint32_t sel, const uint64_t *in, uint32_t inc, uint64_t *out, uint32_t *outc) {
    kern_return_t kr = o_call_scalar(c, sel, in, inc, out, outc);
    char win[320], wout[320];
    uint32_t oc = outc ? *outc : 0;
    words(win, sizeof win, in, inc);
    words(wout, sizeof wout, out, oc);
    emit("CallScalar conn=%u cls=%s sel=%u in#=%u in=[%s] out#=%u out=[%s] kr=0x%x\n",
         c, conn_class(c), sel, inc, win, oc, wout, kr);
    return kr;
}

static kern_return_t h_call_struct(mach_port_t c, uint32_t sel, const void *ins, size_t insz, void *outs, size_t *outsz) {
    kern_return_t kr = o_call_struct(c, sel, ins, insz, outs, outsz);
    char hin[200], hout[200];
    size_t os = outsz ? *outsz : 0;
    hexdump(hin, sizeof hin, ins, insz);
    hexdump(hout, sizeof hout, outs, os);
    emit("CallStruct conn=%u cls=%s sel=%u inStruct(%zu)=%s outStruct(%zu)=%s kr=0x%x\n",
         c, conn_class(c), sel, insz, hin, os, hout, kr);
    return kr;
}

static kern_return_t h_service_open(io_service_t s, mach_port_t task, uint32_t type, io_connect_t *conn) {
    io_name_t name;
    char cls[128] = "?";
    kern_return_t kr;
    if (IOObjectGetClass(s, name) == KERN_SUCCESS) {
        strncpy(cls, name, sizeof cls - 1);
        cls[sizeof cls - 1] = 0;
    }
    kr = o_service_open(s, task, type, conn);
    emit("ServiceOpen svc=%u cls=%s type=%u kr=0x%x conn=%u\n", s, cls, type, kr, conn ? *conn : 0);
    if (kr == KERN_SUCCESS && conn && nconns < 128) {
        conns[nconns].port = *conn;
        strncpy(conns[nconns].cls, cls, sizeof conns[nconns].cls - 1);
        conns[nconns].type = type;
        nconns++;
    }
    return kr;
}

static CFMutableDictionaryRef h_matching(const char *name) {
    CFMutableDictionaryRef d = o_matching(name);
    emit("ServiceMatching name=%s dict=%p\n", name ? name : "-", (void *)d);
    return d;
}

static io_service_t h_get_service(mach_port_t port, CFDictionaryRef d) {
    io_service_t s = o_get_service(port, d);
    emit("GetMatchingService svc=%u\n", s);
    return s;
}

static kern_return_t h_get_services(mach_port_t port, CFDictionaryRef d, io_iterator_t *it) {
    kern_return_t kr = o_get_services(port, d, it);
    emit("GetMatchingServices kr=0x%x iter=%u\n", kr, it ? *it : 0);
    return kr;
}

static kern_return_t h_map_memory(io_connect_t c, uint32_t type, mach_port_t task, vm_address_t *addr, vm_size_t *size, uint32_t opts) {
    kern_return_t kr = o_map_memory(c, type, task, addr, size, opts);
    emit("MapMemory conn=%u cls=%s type=%u kr=0x%x addr=0x%lx size=0x%lx\n", c, conn_class(c), type, kr,
         addr ? (unsigned long)*addr : 0UL, size ? (unsigned long)*size : 0UL);
    return kr;
}

static void hook(ms_hook_fn ms, const char *name, void *replace, void **orig) {
    void *sym = dlsym(RTLD_DEFAULT, name);
    if (!sym) {
        emit("hook %s: not found\n", name);
        return;
    }
    ms(sym, replace, orig);
    emit("hook %s sym=%p orig=%p\n", name, sym, *orig);
}

__attribute__((constructor)) static void gltrace_init(void) {
    void *sub = dlopen("/usr/lib/libsubstrate.dylib", RTLD_NOW);
    ms_hook_fn ms = sub ? (ms_hook_fn)dlsym(sub, "MSHookFunction") : NULL;
    log_fd = open("/tmp/gltrace.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (!ms) {
        emit("no MSHookFunction (substrate dlopen=%p)\n", sub);
        return;
    }
    hook(ms, "IOServiceMatching", (void *)h_matching, (void **)&o_matching);
    hook(ms, "IOServiceGetMatchingService", (void *)h_get_service, (void **)&o_get_service);
    hook(ms, "IOServiceGetMatchingServices", (void *)h_get_services, (void **)&o_get_services);
    hook(ms, "IOServiceOpen", (void *)h_service_open, (void **)&o_service_open);
    hook(ms, "IOConnectCallMethod", (void *)h_call_method, (void **)&o_call_method);
    hook(ms, "IOConnectCallScalarMethod", (void *)h_call_scalar, (void **)&o_call_scalar);
    hook(ms, "IOConnectCallStructMethod", (void *)h_call_struct, (void **)&o_call_struct);
    hook(ms, "IOConnectMapMemory", (void *)h_map_memory, (void **)&o_map_memory);
}
