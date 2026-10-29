// q4probe.m: read-only measurement of one trivial GLES2 draw on the phone, and of a 100-draw frame.
//
// The probe rebinds the IOConnect imports of every image loaded in this process to counting wrappers. It changes
// only this process's own indirect-symbol pointers, on private copies of their pages. No Apple code is patched, and
// the probe writes nothing to the phone except its stdout. The draw is a small quad (about 6 by 6 pixels of a
// 256 by 256 offscreen texture), so GPU fill stays small. Each phase is timed in wall time and in thread CPU time,
// because a call that blocks on the GPU shows wall time without CPU time. IOConnect calls are counted by the image
// that made them and by selector. Counters are not locked, so calls from other threads may be missed or merged.
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <pthread.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach/thread_info.h>
#include <mach/vm_map.h>
#include <mach/vm_prot.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef kern_return_t (*call_method_fn)(mach_port_t, uint32_t, const uint64_t *, uint32_t, const void *, size_t, uint64_t *, uint32_t *, void *, size_t *);
typedef kern_return_t (*call_scalar_fn)(mach_port_t, uint32_t, const uint64_t *, uint32_t, uint64_t *, uint32_t *);
typedef kern_return_t (*call_struct_fn)(mach_port_t, uint32_t, const void *, size_t, void *, size_t *);

enum { KIND_METHOD, KIND_SCALAR, KIND_STRUCT, KINDS };
enum { SEL_MAX = 64, CALLERS_MAX = 16, SINGLE_FRAMES = 2000, FRAMES_100 = 200, DRAWS_PER_FRAME = 100 };

static const char *kind_name[KINDS] = {"CallMethod", "CallScalar", "CallStruct"};

static mach_timebase_info_data_t timebase;
static uint64_t io_ticks, io_cpu_ns, io_calls;
static uint64_t sel_calls[KINDS][SEL_MAX], sel_ticks[KINDS][SEL_MAX], sel_cpu_ns[KINDS][SEL_MAX];
static char caller_name[CALLERS_MAX][64];
static uint64_t caller_calls[CALLERS_MAX], caller_ticks[CALLERS_MAX], caller_cpu_ns[CALLERS_MAX];
static int callers;

static call_method_fn real_call_method;
static call_scalar_fn real_call_scalar;
static call_struct_fn real_call_struct;

static double ns(uint64_t ticks) { return (double)ticks * timebase.numer / timebase.denom; }

// thread_cpu_ns is the user and system CPU time of the calling thread. The port comes from pthread_mach_thread_np,
// which does not add a send right, so calling it on every sample leaks nothing.
static uint64_t thread_cpu_ns(void)
{
    thread_basic_info_data_t info;
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    if (thread_info(pthread_mach_thread_np(pthread_self()), THREAD_BASIC_INFO, (thread_info_t)&info, &count) != KERN_SUCCESS) return 0;
    return ((uint64_t)info.user_time.seconds + info.system_time.seconds) * 1000000000ULL
         + ((uint64_t)info.user_time.microseconds + info.system_time.microseconds) * 1000ULL;
}

static int caller_slot(void *ret)
{
    Dl_info info;
    const char *path = NULL, *base = "?";
    int i;
    if (dladdr(ret, &info) && info.dli_fname) path = info.dli_fname;
    if (path) base = strrchr(path, '/') ? strrchr(path, '/') + 1 : path;
    for (i = 0; i < callers; i++) {
        if (strcmp(caller_name[i], base) == 0) return i;
    }
    if (callers >= CALLERS_MAX) return CALLERS_MAX - 1;
    strncpy(caller_name[callers], base, sizeof caller_name[0] - 1);
    return callers++;
}

static void account(int kind, uint32_t sel, uint64_t ticks, uint64_t cpu, void *ret)
{
    int slot = caller_slot(ret);
    io_ticks += ticks;
    io_cpu_ns += cpu;
    io_calls++;
    if (sel < SEL_MAX) {
        sel_calls[kind][sel]++;
        sel_ticks[kind][sel] += ticks;
        sel_cpu_ns[kind][sel] += cpu;
    }
    caller_calls[slot]++;
    caller_ticks[slot] += ticks;
    caller_cpu_ns[slot] += cpu;
}

static kern_return_t hook_call_method(mach_port_t c, uint32_t sel, const uint64_t *in, uint32_t inc, const void *ins, size_t insz, uint64_t *out, uint32_t *outc, void *outs, size_t *outsz)
{
    void *ret = __builtin_return_address(0);
    uint64_t t0 = mach_absolute_time(), k0 = thread_cpu_ns();
    kern_return_t kr = real_call_method(c, sel, in, inc, ins, insz, out, outc, outs, outsz);
    uint64_t k1 = thread_cpu_ns(), t1 = mach_absolute_time();
    account(KIND_METHOD, sel, t1 - t0, k1 - k0, ret);
    return kr;
}

static kern_return_t hook_call_scalar(mach_port_t c, uint32_t sel, const uint64_t *in, uint32_t inc, uint64_t *out, uint32_t *outc)
{
    void *ret = __builtin_return_address(0);
    uint64_t t0 = mach_absolute_time(), k0 = thread_cpu_ns();
    kern_return_t kr = real_call_scalar(c, sel, in, inc, out, outc);
    uint64_t k1 = thread_cpu_ns(), t1 = mach_absolute_time();
    account(KIND_SCALAR, sel, t1 - t0, k1 - k0, ret);
    return kr;
}

static kern_return_t hook_call_struct(mach_port_t c, uint32_t sel, const void *ins, size_t insz, void *outs, size_t *outsz)
{
    void *ret = __builtin_return_address(0);
    uint64_t t0 = mach_absolute_time(), k0 = thread_cpu_ns();
    kern_return_t kr = real_call_struct(c, sel, ins, insz, outs, outsz);
    uint64_t k1 = thread_cpu_ns(), t1 = mach_absolute_time();
    account(KIND_STRUCT, sel, t1 - t0, k1 - k0, ret);
    return kr;
}

struct binding {
    const char *name;
    void *replacement;
    int hits;
};
static struct binding bindings[] = {
    {"_IOConnectCallMethod", (void *)hook_call_method, 0},
    {"_IOConnectCallScalarMethod", (void *)hook_call_scalar, 0},
    {"_IOConnectCallStructMethod", (void *)hook_call_struct, 0},
};
#define NBINDINGS (sizeof bindings / sizeof bindings[0])

static void make_writable(void *address)
{
    vm_size_t page = (vm_size_t)getpagesize();
    vm_address_t start = (vm_address_t)address & ~(page - 1);
    vm_protect(mach_task_self(), start, page, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
}

// rebind_image replaces the lazy and non-lazy pointers of one image's imports that name an IOConnect function.
// It is called for every image already loaded, and for each image loaded later.
static void rebind_image(const struct mach_header *mh, intptr_t slide)
{
    const struct segment_command *segs[64];
    const struct symtab_command *symtab = NULL;
    const struct dysymtab_command *dysym = NULL;
    const struct segment_command *linkedit = NULL;
    const struct load_command *lc = (const struct load_command *)(mh + 1);
    uint32_t i, s, nsegs = 0;
    uintptr_t base;
    const struct nlist *syms;
    const char *strs;
    const uint32_t *indirect;

    if (mh->magic != MH_MAGIC) return;
    for (i = 0; i < mh->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT) {
            const struct segment_command *seg = (const struct segment_command *)lc;
            if (nsegs < 64) segs[nsegs++] = seg;
            if (strcmp(seg->segname, SEG_LINKEDIT) == 0) linkedit = seg;
        } else if (lc->cmd == LC_SYMTAB) {
            symtab = (const struct symtab_command *)lc;
        } else if (lc->cmd == LC_DYSYMTAB) {
            dysym = (const struct dysymtab_command *)lc;
        }
        lc = (const struct load_command *)((const char *)lc + lc->cmdsize);
    }
    if (!linkedit || !symtab || !dysym) return;

    base = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    syms = (const struct nlist *)(base + symtab->symoff);
    strs = (const char *)(base + symtab->stroff);
    indirect = (const uint32_t *)(base + dysym->indirectsymoff);

    for (s = 0; s < nsegs; s++) {
        const struct section *sect = (const struct section *)(segs[s] + 1);
        uint32_t k;
        for (k = 0; k < segs[s]->nsects; k++, sect++) {
            uint32_t type = sect->flags & SECTION_TYPE;
            void **ptrs;
            uint32_t j, count;
            if (type != S_LAZY_SYMBOL_POINTERS && type != S_NON_LAZY_SYMBOL_POINTERS) continue;
            ptrs = (void **)(slide + sect->addr);
            count = sect->size / sizeof(void *);
            for (j = 0; j < count; j++) {
                uint32_t index = indirect[sect->reserved1 + j];
                const char *name;
                uint32_t b;
                if (index & (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) continue;
                name = strs + syms[index].n_un.n_strx;
                for (b = 0; b < NBINDINGS; b++) {
                    if (strcmp(name, bindings[b].name) == 0 && ptrs[j] != bindings[b].replacement) {
                        make_writable(&ptrs[j]);
                        ptrs[j] = bindings[b].replacement;
                        bindings[b].hits++;
                    }
                }
            }
        }
    }
}

static int compare_u64(const void *a, const void *b)
{
    uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b;
    return x < y ? -1 : x > y;
}

static uint64_t percentile(uint64_t *v, int n, int pct)
{
    qsort(v, n, sizeof *v, compare_u64);
    return v[(n - 1) * pct / 100];
}

static uint64_t *series(int n)
{
    return calloc(n, sizeof(uint64_t));
}

static void report(const char *label, uint64_t *v, int n)
{
    printf("%-34s p10 %10.0f  median %10.0f  p90 %10.0f ns\n", label, ns(percentile(v, n, 10)), ns(percentile(v, n, 50)), ns(percentile(v, n, 90)));
}

static GLuint program, vbo, ibo, fbo, texture;
static GLint colour_location;

static GLuint compile_shader(GLenum type, const char *source)
{
    GLuint shader = glCreateShader(type);
    GLint ok = 0;
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        printf("shader compile failed\n");
        exit(2);
    }
    return shader;
}

static void setup_gl(void)
{
    static const char *vertex = "attribute vec4 p; void main(void) { gl_Position = p; }";
    static const char *fragment = "precision mediump float; uniform vec4 c; void main(void) { gl_FragColor = c; }";
    static const GLfloat corners[8] = {-0.05f, -0.05f, 0.05f, -0.05f, -0.05f, 0.05f, 0.05f, 0.05f};
    static const GLushort order[4] = {0, 1, 2, 3};
    GLint linked = 0, position;

    program = glCreateProgram();
    glAttachShader(program, compile_shader(GL_VERTEX_SHADER, vertex));
    glAttachShader(program, compile_shader(GL_FRAGMENT_SHADER, fragment));
    glBindAttribLocation(program, 0, "p");
    glLinkProgram(program);
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {
        printf("program link failed\n");
        exit(2);
    }
    glUseProgram(program);
    position = glGetAttribLocation(program, "p");
    colour_location = glGetUniformLocation(program, "c");
    glUniform4f(colour_location, 0.25f, 0.5f, 0.75f, 1.0f);

    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof corners, corners, GL_STATIC_DRAW);
    glEnableVertexAttribArray(position);
    glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glGenBuffers(1, &ibo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof order, order, GL_STATIC_DRAW);

    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        printf("framebuffer incomplete\n");
        exit(2);
    }
    glViewport(0, 0, 256, 256);
}

static void draw_once(void)
{
    glDrawElements(GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_SHORT, 0);
}

// run_single: one draw, then one glFinish, per frame.
static void run_single(void)
{
    int n = SINGLE_FRAMES, i;
    uint64_t *draw = series(n), *draw_cpu = series(n), *draw_io = series(n), *draw_io_cpu = series(n);
    uint64_t *finish = series(n), *finish_cpu = series(n), *finish_io = series(n), *finish_io_cpu = series(n);
    uint64_t calls_draw = 0, calls_finish = 0, calls_before = io_calls;

    for (i = 0; i < n; i++) {
        uint64_t k0 = thread_cpu_ns(), t0 = mach_absolute_time(), i0 = io_ticks, q0 = io_cpu_ns, c0 = io_calls;
        uint64_t t1, k1, i1, q1, c1, t2, k2, i2, q2;
        draw_once();
        t1 = mach_absolute_time();
        k1 = thread_cpu_ns();
        i1 = io_ticks;
        q1 = io_cpu_ns;
        c1 = io_calls;
        glFinish();
        t2 = mach_absolute_time();
        k2 = thread_cpu_ns();
        i2 = io_ticks;
        q2 = io_cpu_ns;
        draw[i] = t1 - t0;
        draw_cpu[i] = k1 - k0;
        draw_io[i] = i1 - i0;
        draw_io_cpu[i] = q1 - q0;
        finish[i] = t2 - t1;
        finish_cpu[i] = k2 - k1;
        finish_io[i] = i2 - i1;
        finish_io_cpu[i] = q2 - q1;
        calls_draw += c1 - c0;
        calls_finish += io_calls - c1;
    }
    printf("\nscenario 1: one trivial draw per frame, %d frames\n", n);
    report("draw call, wall", draw, n);
    report("  draw call, thread CPU", draw_cpu, n);
    report("  IOConnect* in the draw, wall", draw_io, n);
    report("  IOConnect* in the draw, CPU", draw_io_cpu, n);
    report("glFinish, wall", finish, n);
    report("  glFinish, thread CPU", finish_cpu, n);
    report("  IOConnect* in glFinish, wall", finish_io, n);
    report("  IOConnect* in glFinish, CPU", finish_io_cpu, n);
    printf("IOConnect calls per draw %.3f, per glFinish %.3f (total %llu)\n",
           (double)calls_draw / n, (double)calls_finish / n, (unsigned long long)(io_calls - calls_before));
    free(draw); free(draw_cpu); free(draw_io); free(draw_io_cpu);
    free(finish); free(finish_cpu); free(finish_io); free(finish_io_cpu);
}

// run_frames: 100 draws, then one glFinish, per frame. Each draw is timed on its own; CPU is read per frame,
// because a thread_info call per draw would cost as much as the draw.
static void run_frames(void)
{
    int frames = FRAMES_100, f, d, draws = frames * DRAWS_PER_FRAME, k, s, slot;
    uint64_t *per_draw = series(draws);
    uint64_t *frame = series(frames), *draws_wall = series(frames), *draws_cpu = series(frames);
    uint64_t *draws_io = series(frames), *draws_io_cpu = series(frames);
    uint64_t *fin = series(frames), *fin_cpu = series(frames), *fin_io = series(frames), *fin_io_cpu = series(frames);
    uint64_t calls_total = 0;

    memset(sel_calls, 0, sizeof sel_calls);
    memset(sel_ticks, 0, sizeof sel_ticks);
    memset(sel_cpu_ns, 0, sizeof sel_cpu_ns);
    memset(caller_calls, 0, sizeof caller_calls);
    memset(caller_ticks, 0, sizeof caller_ticks);
    memset(caller_cpu_ns, 0, sizeof caller_cpu_ns);

    for (f = 0; f < frames; f++) {
        uint64_t t0 = mach_absolute_time(), k0 = thread_cpu_ns(), i0 = io_ticks, q0 = io_cpu_ns, c0 = io_calls;
        uint64_t t1, k1, i1, q1, t2, k2, i2, q2;
        for (d = 0; d < DRAWS_PER_FRAME; d++) {
            uint64_t a = mach_absolute_time();
            draw_once();
            per_draw[f * DRAWS_PER_FRAME + d] = mach_absolute_time() - a;
        }
        t1 = mach_absolute_time();
        k1 = thread_cpu_ns();
        i1 = io_ticks;
        q1 = io_cpu_ns;
        glFinish();
        t2 = mach_absolute_time();
        k2 = thread_cpu_ns();
        i2 = io_ticks;
        q2 = io_cpu_ns;
        frame[f] = t2 - t0;
        draws_wall[f] = t1 - t0;
        draws_cpu[f] = k1 - k0;
        draws_io[f] = i1 - i0;
        draws_io_cpu[f] = q1 - q0;
        fin[f] = t2 - t1;
        fin_cpu[f] = k2 - k1;
        fin_io[f] = i2 - i1;
        fin_io_cpu[f] = q2 - q1;
        calls_total += io_calls - c0;
    }

    printf("\nscenario 2: one frame of %d draws, %d frames\n", DRAWS_PER_FRAME, frames);
    report("one draw, wall (each)", per_draw, draws);
    report("frame, wall (draws + glFinish)", frame, frames);
    report("  draws, wall", draws_wall, frames);
    report("    draws, thread CPU", draws_cpu, frames);
    report("    IOConnect* in the draws, wall", draws_io, frames);
    report("    IOConnect* in the draws, CPU", draws_io_cpu, frames);
    report("  glFinish, wall", fin, frames);
    report("    glFinish, thread CPU", fin_cpu, frames);
    report("    IOConnect* in glFinish, wall", fin_io, frames);
    report("    IOConnect* in glFinish, CPU", fin_io_cpu, frames);
    printf("IOConnect calls per draw %.3f, per frame %.2f\n",
           (double)calls_total / draws, (double)calls_total / frames);

    printf("per caller image (calls per draw; ns per draw inside IOConnect*, wall; CPU):\n");
    for (slot = 0; slot < callers; slot++) {
        printf("  %-28s %8.3f  %12.0f  %12.0f\n", caller_name[slot], (double)caller_calls[slot] / draws,
               ns(caller_ticks[slot]) / draws, (double)caller_cpu_ns[slot] / draws);
    }
    printf("per selector (calls per draw; ns per call, wall; CPU):\n");
    for (k = 0; k < KINDS; k++) {
        for (s = 0; s < SEL_MAX; s++) {
            if (sel_calls[k][s] == 0) continue;
            printf("  %-12s sel %2d  %8.3f  %12.0f  %12.0f\n", kind_name[k], s, (double)sel_calls[k][s] / draws,
                   ns(sel_ticks[k][s]) / sel_calls[k][s], (double)sel_cpu_ns[k][s] / sel_calls[k][s]);
        }
    }
    free(per_draw); free(frame); free(draws_wall); free(draws_cpu); free(draws_io); free(draws_io_cpu);
    free(fin); free(fin_cpu); free(fin_io); free(fin_io_cpu);
}

// run_sync splits a glFinish into submission and wait. Each round times (a) a glFinish with nothing queued, then
// (b) one draw, a glFlush (submission without waiting), and a glFinish (the wait for the GPU to finish).
static void run_sync(void)
{
    int n = SINGLE_FRAMES, i;
    uint64_t *empty = series(n), *empty_io = series(n), *flush = series(n), *flush_io = series(n);
    uint64_t *wait = series(n), *wait_io = series(n);
    uint64_t calls_empty = 0, calls_flush = 0, calls_wait = 0;

    for (i = 0; i < n; i++) {
        uint64_t t0 = mach_absolute_time(), i0 = io_ticks, c0 = io_calls;
        uint64_t t1, i1, c1, t2, i2, c2, t3, i3, c3, t4, i4;
        glFinish();
        t1 = mach_absolute_time();
        i1 = io_ticks;
        c1 = io_calls;
        empty[i] = t1 - t0;
        empty_io[i] = i1 - i0;
        calls_empty += c1 - c0;

        draw_once();
        t2 = mach_absolute_time();
        i2 = io_ticks;
        c2 = io_calls;
        glFlush();
        t3 = mach_absolute_time();
        i3 = io_ticks;
        c3 = io_calls;
        glFinish();
        t4 = mach_absolute_time();
        i4 = io_ticks;
        flush[i] = t3 - t2;
        flush_io[i] = i3 - i2;
        calls_flush += c3 - c2;
        wait[i] = t4 - t3;
        wait_io[i] = i4 - i3;
        calls_wait += io_calls - c3;
    }
    printf("\nscenario 3: submission against wait, %d rounds\n", n);
    report("glFinish, nothing queued, wall", empty, n);
    report("  inside IOConnect*", empty_io, n);
    report("glFlush after one draw, wall", flush, n);
    report("  inside IOConnect*", flush_io, n);
    report("glFinish after the flush, wall", wait, n);
    report("  inside IOConnect*", wait_io, n);
    printf("IOConnect calls per glFinish (empty) %.3f, per glFlush %.3f, per glFinish (wait) %.3f\n",
           (double)calls_empty / n, (double)calls_flush / n, (double)calls_wait / n);
    free(empty); free(empty_io); free(flush); free(flush_io); free(wait); free(wait_io);
}

int main(int argc, char *argv[])
{
    EAGLContext *context;
    uint8_t pixel[4] = {0, 0, 0, 0};
    unsigned b;

    mach_timebase_info(&timebase);
    real_call_method = (call_method_fn)dlsym(RTLD_DEFAULT, "IOConnectCallMethod");
    real_call_scalar = (call_scalar_fn)dlsym(RTLD_DEFAULT, "IOConnectCallScalarMethod");
    real_call_struct = (call_struct_fn)dlsym(RTLD_DEFAULT, "IOConnectCallStructMethod");
    if (!real_call_method || !real_call_scalar || !real_call_struct) {
        printf("IOConnect functions not found: %p %p %p\n", real_call_method, real_call_scalar, real_call_struct);
        return 2;
    }
    _dyld_register_func_for_add_image(rebind_image);
    for (b = 0; b < NBINDINGS; b++) {
        printf("rebound %-28s in %d pointers\n", bindings[b].name, bindings[b].hits);
    }

    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!context || ![EAGLContext setCurrentContext:context]) {
        printf("no OpenGLES 2 context\n");
        return 2;
    }
    printf("GL_VERSION %s\nGL_RENDERER %s\n", (const char *)glGetString(GL_VERSION), (const char *)glGetString(GL_RENDERER));
    setup_gl();
    draw_once();
    glReadPixels(128, 128, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
    printf("pixel check: %u %u %u %u (want 64 128 191 255), GL error 0x%x\n", pixel[0], pixel[1], pixel[2], pixel[3], glGetError());

    run_sync();
    run_single();
    run_frames();
    printf("\nIOConnect calls seen in total: %llu\n", (unsigned long long)io_calls);
    fflush(stdout);
    return 0;
}
