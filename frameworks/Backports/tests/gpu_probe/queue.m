#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void (*ms_hook_fn)(void *symbol, void *replace, void **result);
typedef uintptr_t (*gld_fn)(uintptr_t, uintptr_t, uintptr_t, uintptr_t);

static const char *gpu_support_path = "/System/Library/PrivateFrameworks/GPUSupport.framework/libGPUSupportMercury.dylib";

static uintptr_t peek(uintptr_t addr) {
    uintptr_t v = 0;
    vm_size_t got = 0;
    if (!addr) return 0;
    if (vm_read_overwrite(mach_task_self(), (vm_address_t)addr, sizeof v, (vm_address_t)&v, &got) != KERN_SUCCESS) return (uintptr_t)-1;
    return v;
}

static void *gpu_support(void) {
    void *h = dlopen(gpu_support_path, RTLD_NOW | RTLD_GLOBAL);
    if (!h) printf("dlopen libGPUSupportMercury: %s\n", dlerror());
    return h;
}

static int dump(const char *name, size_t n) {
    void *h = gpu_support();
    void *sym = dlsym(h ? h : RTLD_DEFAULT, name);
    printf("sym %s = %p\n", name, sym);
    if (!sym) {
        printf("dlerror: %s\n", dlerror());
        return 1;
    }
    const unsigned char *b = (const unsigned char *)((uintptr_t)sym & ~(uintptr_t)1);
    printf("bytes %s =", name);
    for (size_t i = 0; i < n; i++) printf(" %02x", b[i]);
    printf("\n");
    return 0;
}

static gld_fn o_create_context;
static gld_fn o_create_queue;
static uintptr_t last_context;
static uintptr_t last_device;

static uintptr_t h_create_context(uintptr_t a0, uintptr_t a1, uintptr_t a2, uintptr_t a3) {
    uintptr_t r = o_create_context(a0, a1, a2, a3);
    uintptr_t o1 = peek(a1);
    uintptr_t o3 = peek(a3);
    printf("hook gldCreateContext(%#lx, %#lx, %#lx, %#lx) -> %#lx *a1=%#lx *a3=%#lx\n", (unsigned long)a0, (unsigned long)a1, (unsigned long)a2, (unsigned long)a3, (unsigned long)r, (unsigned long)o1, (unsigned long)o3);
    last_context = o1 ? o1 : o3;
    last_device = a0;
    return r;
}

static uintptr_t h_create_queue(uintptr_t a0, uintptr_t a1, uintptr_t a2, uintptr_t a3) {
    uintptr_t r = o_create_queue(a0, a1, a2, a3);
    uintptr_t out = peek(a1);
    printf("hook gldCreateQueue(%#lx, %#lx, %#lx, %#lx) -> %#lx out=%#lx\n", (unsigned long)a0, (unsigned long)a1, (unsigned long)a2, (unsigned long)a3, (unsigned long)r, (unsigned long)out);
    return r;
}

static void sweep(void) {
    io_service_t svc = IOServiceGetMatchingService(MACH_PORT_NULL, IOServiceMatching("IOAcceleratorES"));
    printf("sweep service=%u\n", svc);
    if (!svc) return;
    for (uint32_t t = 3; t <= 8; t++) {
        io_connect_t conn = 0;
        kern_return_t kr = IOServiceOpen(svc, mach_task_self(), t, &conn);
        printf("sweep type=%u kr=0x%x conn=%u\n", t, (unsigned)kr, conn);
        if (kr == KERN_SUCCESS) IOServiceClose(conn);
    }
    IOObjectRelease(svc);
}

static int queue(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    void *h = gpu_support();
    void *substrate = dlopen("/usr/lib/libsubstrate.dylib", RTLD_NOW);
    ms_hook_fn ms = substrate ? (ms_hook_fn)dlsym(substrate, "MSHookFunction") : NULL;
    void *create_context = h ? dlsym(h, "gldCreateContext") : NULL;
    void *create_queue = h ? dlsym(h, "gldCreateQueue") : NULL;
    printf("gldCreateContext=%p gldCreateQueue=%p substrate=%p MSHookFunction=%p\n", create_context, create_queue, substrate, (void *)ms);
    if (!ms || !create_context || !create_queue) return 1;
    ms(create_context, (void *)h_create_context, (void **)&o_create_context);
    ms(create_queue, (void *)h_create_queue, (void **)&o_create_queue);

    EAGLContext *ctx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    printf("EAGLContext=%p setCurrent=%d\n", (void *)ctx, (int)[EAGLContext setCurrentContext:ctx]);
    printf("GL_RENDERER=%s\n", (const char *)glGetString(GL_RENDERER));
    printf("captured gld context=%#lx device=%#lx\n", (unsigned long)last_context, (unsigned long)last_device);
    if (!last_context) return 3;
    uintptr_t dev_sl = peek(last_device + 4);
    printf("device+4=%#lx [device+4]=%#lx\n", (unsigned long)dev_sl, (unsigned long)peek(dev_sl));
    uintptr_t ctx_sl = peek(last_context + 4);
    printf("context+4=%#lx [context+4]=%#lx\n", (unsigned long)ctx_sl, (unsigned long)peek(ctx_sl));
    printf("gldCreateQueue arg0=%#lx\n", (unsigned long)last_device);

    uintptr_t out = 0;
    uintptr_t status = o_create_queue(last_device, (uintptr_t)&out, 0, 0);
    printf("gldCreateQueue status=%#lx out=%#lx\n", (unsigned long)status, (unsigned long)out);
    sweep();
    glFinish();
    printf("glError=0x%x\n", (unsigned)glGetError());
    [EAGLContext setCurrentContext:nil];
    return 0;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc >= 3 && strcmp(argv[1], "dump") == 0) {
            size_t n = argc >= 4 ? (size_t)strtoul(argv[3], NULL, 10) : 256;
            return dump(argv[2], n);
        }
        if (argc >= 2 && strcmp(argv[1], "queue") == 0) {
            return queue();
        }
        printf("usage: MetalQueueProbe dump SYMBOL [BYTES] | queue\n");
        return 2;
    }
}
