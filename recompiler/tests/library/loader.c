#include <dlfcn.h>
#include <fcntl.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <mach/vm_param.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "xl_guest_image.h"

#define SPACE_LOW 0x1000ul
#define SPACE_HIGH 0x30000000ul
#define SPACE_PAGE 0x1000ul
#define MEGABYTE 0x100000ul

#define IMAGES_END 0x10000000ul
#define HEAP_LOW 0x1c500000ul
#define HEAP_HIGH 0x1da00000ul
#define STACK_LOW 0x2fc02000ul
#define STACK_HIGH 0x2fe00000ul

#define GUEST_SIZE 0x162c000ul
#define HOST_SIZE 0x3ef4000ul
#define BASE_UNDER_STACK 0x2e000000ul
#define BASE_AMONG_FIRST_FIT 0x18000000ul

struct region {
    uintptr_t start;
    uintptr_t end;
    vm_prot_t protection;
    unsigned int tag;
};

static struct region regions[8192];
static int region_count;
static unsigned int model_tag;
static int model_dlopen_fails;
static int model_init_missing;
static int model_init_result;
static int model_dlopen_calls;
static uintptr_t model_guest_low;
static uintptr_t model_guest_high;
static uintptr_t model_image_low;
static char model_class;
static int failures;

static void model_insert(uintptr_t start, uintptr_t end, vm_prot_t protection, unsigned int tag)
{
    int at = 0;
    while (at < region_count && regions[at].start < start)
        at++;
    if (region_count == (int)(sizeof regions / sizeof regions[0])) {
        fprintf(stderr, "the model of the address space holds no more regions\n");
        exit(2);
    }
    memmove(&regions[at + 1], &regions[at], (size_t)(region_count - at) * sizeof regions[0]);
    regions[at] = (struct region){start, end, protection, tag};
    region_count++;
}

static void model_split(uintptr_t address)
{
    for (int index = 0; index < region_count; index++) {
        if (regions[index].start < address && address < regions[index].end) {
            uintptr_t end = regions[index].end;
            regions[index].end = address;
            model_insert(address, end, regions[index].protection, regions[index].tag);
            return;
        }
    }
}

static uintptr_t model_covered(uintptr_t low, uintptr_t high, int inaccessible_only)
{
    uintptr_t covered = 0;
    for (int index = 0; index < region_count; index++) {
        uintptr_t first = regions[index].start > low ? regions[index].start : low;
        uintptr_t last = regions[index].end < high ? regions[index].end : high;
        if (last > first && (!inaccessible_only || regions[index].protection == VM_PROT_NONE))
            covered += last - first;
    }
    return covered;
}

static uintptr_t model_free(void)
{
    return SPACE_HIGH - SPACE_LOW - model_covered(SPACE_LOW, SPACE_HIGH, 0);
}

static kern_return_t model_allocate(vm_map_t task, vm_address_t *address, vm_size_t size, int flags)
{
    (void)task;
    uintptr_t length = (size + SPACE_PAGE - 1) & ~(SPACE_PAGE - 1);
    uintptr_t start = *address;
    if (flags & VM_FLAGS_ANYWHERE) {
        start = SPACE_LOW;
        for (int index = 0; index < region_count && regions[index].start - start < length; index++)
            start = regions[index].end;
    }
    if (start < SPACE_LOW || start > SPACE_HIGH || length > SPACE_HIGH - start || model_covered(start, start + length, 0))
        return KERN_NO_SPACE;
    model_insert(start, start + length, VM_PROT_READ | VM_PROT_WRITE, model_tag);
    *address = start;
    return KERN_SUCCESS;
}

static kern_return_t model_deallocate(vm_map_t task, vm_address_t address, vm_size_t size)
{
    (void)task;
    model_split(address);
    model_split(address + size);
    int kept = 0;
    for (int index = 0; index < region_count; index++) {
        if (regions[index].start < address || regions[index].end > address + size)
            regions[kept++] = regions[index];
    }
    region_count = kept;
    return KERN_SUCCESS;
}

static kern_return_t model_protect(vm_map_t task, vm_address_t address, vm_size_t size, boolean_t set_maximum, vm_prot_t protection)
{
    (void)task;
    (void)set_maximum;
    model_split(address);
    model_split(address + size);
    for (int index = 0; index < region_count; index++) {
        if (regions[index].start >= address && regions[index].end <= address + size)
            regions[index].protection = protection;
    }
    return KERN_SUCCESS;
}

static kern_return_t model_region(vm_map_read_t task, vm_address_t *address, vm_size_t *size, natural_t *depth, vm_region_recurse_info_t info,
                                  mach_msg_type_number_t *count)
{
    (void)task;
    (void)depth;
    (void)count;
    struct vm_region_submap_info_64 *answer = (struct vm_region_submap_info_64 *)info;
    for (int index = 0; index < region_count; index++) {
        if (regions[index].end > *address) {
            memset(answer, 0, sizeof *answer);
            answer->protection = regions[index].protection;
            answer->max_protection = VM_PROT_ALL;
            answer->user_tag = regions[index].tag;
            *address = regions[index].start;
            *size = regions[index].end - regions[index].start;
            return KERN_SUCCESS;
        }
    }
    return KERN_INVALID_ADDRESS;
}

static int model_library_init(void)
{
    if (model_init_result != XL_LIBRARY_OK)
        return model_init_result;
    for (int index = 0; index < region_count; index++) {
        if (regions[index].start == model_guest_low && regions[index].end == model_guest_high && regions[index].protection == VM_PROT_NONE) {
            regions[index].protection = VM_PROT_READ;
            return XL_LIBRARY_OK;
        }
    }
    return XL_LIBRARY_NOT_RESERVED;
}

static void *model_library_class(const char *name)
{
    return strcmp(name, "RCFClient") == 0 ? &model_class : NULL;
}

static void *model_dlopen(const char *path, int mode)
{
    (void)path;
    (void)mode;
    model_dlopen_calls++;
    vm_address_t address = 0;
    if (model_dlopen_fails || model_allocate(mach_task_self(), &address, HOST_SIZE, VM_FLAGS_ANYWHERE) != KERN_SUCCESS)
        return NULL;
    model_image_low = address;
    return &model_image_low;
}

static void *model_dlsym(void *handle, const char *name)
{
    (void)handle;
    if (strcmp(name, "xl_library_init") == 0)
        return model_init_missing ? NULL : (void *)model_library_init;
    if (strcmp(name, "xl_library_class") == 0)
        return (void *)model_library_class;
    return NULL;
}

static char *model_dlerror(void)
{
    return "the model's dyld found no room for the image";
}

#define vm_allocate model_allocate
#define vm_deallocate model_deallocate
#define vm_protect model_protect
#define vm_region_recurse_64 model_region
#define dlopen model_dlopen
#define dlsym model_dlsym
#define dlerror model_dlerror
#include "../../src/loader/xl_loader.c"
#undef vm_allocate
#undef vm_deallocate
#undef vm_protect
#undef vm_region_recurse_64
#undef dlopen
#undef dlsym
#undef dlerror

static void expect(int passed, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    printf("%s ", passed ? "ok" : "FAIL");
    vprintf(format, arguments);
    printf("\n");
    va_end(arguments);
    if (!passed)
        failures++;
}

static uint32_t model_budget_skew;

static void write_library(const char *file, uintptr_t guest_low, uintptr_t guest_high, uint32_t version, int registry)
{
    struct {
        struct mach_header header;
        struct segment_command text;
        struct segment_command guest;
        struct section image;
    } commands;
    memset(&commands, 0, sizeof commands);
    commands.header.magic = MH_MAGIC;
    commands.header.cputype = CPU_TYPE_ARM;
    commands.header.cpusubtype = CPU_SUBTYPE_ARM_V7;
    commands.header.filetype = MH_DYLIB;
    commands.header.ncmds = 2;
    commands.header.sizeofcmds = sizeof commands - sizeof commands.header;
    commands.text.cmd = LC_SEGMENT;
    commands.text.cmdsize = sizeof commands.text;
    strcpy(commands.text.segname, "__TEXT");
    commands.text.vmsize = HOST_SIZE - XL_GUEST_GRANULE;
    commands.guest.cmd = LC_SEGMENT;
    commands.guest.cmdsize = sizeof commands.guest + sizeof commands.image;
    strcpy(commands.guest.segname, XL_GUEST_SEGMENT);
    commands.guest.vmaddr = HOST_SIZE - XL_GUEST_GRANULE;
    commands.guest.vmsize = XL_GUEST_GRANULE;
    commands.guest.nsects = 1;
    strcpy(commands.image.segname, XL_GUEST_SEGMENT);
    strcpy(commands.image.sectname, XL_GUEST_SECTION);
    commands.image.offset = 0x1000;
    commands.image.size = sizeof(struct xl_guest_header);
    uint32_t arena = XL_GUEST_GRANULE, slots = XL_GUEST_WORD_SLOTS_LEAST, aliases = XL_GUEST_GRANULE;
    struct xl_guest_header guest = {XL_GUEST_MAGIC, version, (uint32_t)guest_low, (uint32_t)guest_high, 0,
                                    (uint32_t)guest_high - arena - slots * XL_GUEST_WORD_BYTES - aliases - model_budget_skew, arena, slots, aliases};
    int fd = open(file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0 || pwrite(fd, &commands, sizeof commands, 0) != (ssize_t)sizeof commands ||
        pwrite(fd, &guest, sizeof guest, commands.image.offset) != (ssize_t)sizeof guest) {
        perror(file);
        exit(2);
    }
    close(fd);
    char companion[PATH_MAX];
    xl_registry_path(file, companion, sizeof companion);
    unlink(companion);
    if (registry) {
        fd = open(companion, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        close(fd);
    }
}

static void phone(void)
{
    region_count = 0;
    model_insert(0x4000, IMAGES_END, VM_PROT_READ, 0);
    model_insert(HEAP_LOW, HEAP_HIGH, VM_PROT_READ | VM_PROT_WRITE, VM_MEMORY_MALLOC_SMALL);
    model_insert(STACK_LOW, STACK_HIGH, VM_PROT_READ | VM_PROT_WRITE, VM_MEMORY_STACK);
    model_insert(STACK_HIGH, SPACE_HIGH, VM_PROT_READ, 0);
}

static void app_grows(uintptr_t megabytes)
{
    model_tag = VM_MEMORY_MALLOC_LARGE;
    for (uintptr_t index = 0; index < megabytes; index++) {
        vm_address_t address = 0;
        if (model_allocate(mach_task_self(), &address, MEGABYTE, VM_FLAGS_ANYWHERE) != KERN_SUCCESS) {
            fprintf(stderr, "the model has no room for megabyte %lu of the app\n", (unsigned long)index);
            exit(2);
        }
    }
    model_tag = 0;
}

static struct region saved[sizeof regions / sizeof regions[0]];
static int saved_count;

static void remember(void)
{
    memcpy(saved, regions, sizeof regions);
    saved_count = region_count;
}

static int unchanged(void)
{
    return saved_count == region_count && memcmp(saved, regions, (size_t)region_count * sizeof regions[0]) == 0;
}

static int room_held(void)
{
    for (int index = 0; index < region_count; index++) {
        if (regions[index].protection == VM_PROT_NONE && regions[index].end - regions[index].start == HOST_SIZE &&
            (regions[index].end <= model_guest_low || regions[index].start >= model_guest_high))
            return 1;
    }
    return 0;
}

static const char *library(const char *folder, const char *name, uintptr_t base, uint32_t version, int registry)
{
    static char files[4][PATH_MAX];
    static int next;
    char *file = files[next++ % 4];
    snprintf(file, PATH_MAX, "%s/%s.dylib", folder, name);
    write_library(file, base, base + GUEST_SIZE, version, registry);
    model_guest_low = base;
    model_guest_high = base + GUEST_SIZE;
    return file;
}

static void scenario_kept(const char *folder)
{
    const char *file = library(folder, "kept", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    uintptr_t before = model_free();
    expect(xl_reserve(file) == XL_LOAD_OK, "xl_reserve takes the ranges of a library whose guest is under the main stack");
    expect(model_covered(model_guest_low, model_guest_high, 1) == GUEST_SIZE, "the whole guest range is held inaccessible");
    expect(room_held(), "room of the host part's size is held inaccessible outside the guest range");
    expect(before - model_free() == GUEST_SIZE + HOST_SIZE, "the reservation holds the guest range and the host room, %lu MB",
           (unsigned long)((before - model_free()) >> 20));
    expect(xl_find_class("RCFClient") == NULL, "no class is found before the library is loaded");
    app_grows(300);
    expect(xl_load(file) == XL_LOAD_OK, "xl_load loads into the reservation after the app grew by 300 MB");
    expect(!room_held() && model_image_low != 0, "the host room was given to dyld, which mapped the image");
    expect(model_covered(model_guest_low, model_guest_high, 1) == 0 && model_covered(model_guest_low, model_guest_high, 0) == GUEST_SIZE,
           "the library attached the guest range");
    expect(xl_find_class("RCFClient") == &model_class, "the class of a name is found after the load");
    remember();
    xl_release();
    expect(unchanged() && xl_find_class("RCFClient") == &model_class, "xl_release after the load gives nothing back and the library stays");
    expect(xl_reserve(file) == XL_LOAD_OK && xl_load(file) == XL_LOAD_OK && unchanged() && model_dlopen_calls == 1,
           "a second reserve and load of the loaded library change nothing");
}

static void scenario_release(const char *folder)
{
    const char *file = library(folder, "release", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    remember();
    xl_release();
    expect(unchanged(), "xl_release with nothing reserved changes nothing");
    expect(xl_reserve(file) == XL_LOAD_OK && !unchanged(), "xl_reserve holds the ranges");
    xl_release();
    expect(unchanged(), "xl_release gives back the guest range and the host room: the address space is as it was before xl_reserve");
    expect(xl_reserve(file) == XL_LOAD_OK && model_covered(model_guest_low, model_guest_high, 1) == GUEST_SIZE && room_held(),
           "the ranges are taken again by a second xl_reserve");
    xl_release();
    expect(unchanged(), "and given back again");
    app_grows(300);
    expect(xl_load(file) == XL_LOAD_OK && model_covered(model_guest_low, model_guest_high, 0) == GUEST_SIZE && xl_find_class("RCFClient") == &model_class,
           "xl_load after a release takes the guest range itself and loads");
}

static void scenario_lazy(const char *folder)
{
    const char *file = library(folder, "lazy", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    uintptr_t start = model_free();
    app_grows(380);
    expect(start - model_free() == 380 * MEGABYTE, "a host that never reserved holds nothing of the library while the app grows by 380 MB");
    expect(model_covered(model_guest_low, model_guest_high, 0) == 0, "first-fit growth of 380 MB has not reached the range under the main stack");
    uintptr_t before = model_free();
    expect(xl_load(file) == XL_LOAD_OK, "xl_load without a reservation takes the guest range at that moment and loads");
    expect(before - model_free() == GUEST_SIZE + HOST_SIZE && !room_held(), "the loaded library holds its guest range and its image, and no reservation beside them");
    expect(xl_find_class("RCFClient") == &model_class, "the class of a name is found");
}

static void scenario_lazy_busy(const char *folder)
{
    const char *file = library(folder, "busy", BASE_AMONG_FIRST_FIT, XL_GUEST_VERSION, 1);
    app_grows(380);
    remember();
    expect(xl_load(file) == XL_LOAD_RANGE_BUSY, "xl_load of a library whose guest range the app's first-fit mappings reached is refused");
    expect(strstr(xl_load_error(), "another mapping holds") && strstr(xl_load_error(), "malloc large"), "the message names the holder: %s", xl_load_error());
    expect(unchanged() && model_dlopen_calls == 0, "the refused load holds nothing and mapped nothing");
    expect(xl_find_class("RCFClient") == NULL, "no class is found");
    model_deallocate(mach_task_self(), model_guest_low, GUEST_SIZE);
    expect(xl_load(file) == XL_LOAD_OK, "the refusal is not final: once the range is free the load succeeds");
}

static void scenario_lazy_no_room(const char *folder)
{
    const char *file = library(folder, "noroom", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    app_grows(430);
    remember();
    expect(xl_load(file) == XL_LOAD_RANGE_BUSY && strstr(xl_load_error(), "no free range of"), "xl_load with no hole of the host part's size is refused: %s",
           xl_load_error());
    expect(unchanged() && model_dlopen_calls == 0, "the guest range it took is given back: the address space is as before");
}

static void scenario_lazy_dlopen(const char *folder)
{
    const char *file = library(folder, "dlopen", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    app_grows(300);
    remember();
    model_dlopen_fails = 1;
    expect(xl_load(file) == XL_LOAD_DLOPEN_FAILED && strstr(xl_load_error(), "dlopen: "), "a failed dlopen is reported: %s", xl_load_error());
    expect(unchanged(), "after a failed dlopen of a load without a reservation nothing is held");
    model_init_missing = 1;
    model_dlopen_fails = 0;
    expect(xl_load(file) == XL_LOAD_BAD_IMAGE && model_covered(model_guest_low, model_guest_high, 0) == 0 && !room_held(),
           "a library without xl_library_init is refused and no reservation is left");
    model_init_missing = 0;
    expect(xl_load(file) == XL_LOAD_OK && xl_find_class("RCFClient") == &model_class, "the failures are not final: the next load succeeds");
}

static void scenario_kept_dlopen(const char *folder)
{
    const char *file = library(folder, "keptdlopen", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    expect(xl_reserve(file) == XL_LOAD_OK, "xl_reserve");
    remember();
    model_dlopen_fails = 1;
    expect(xl_load(file) == XL_LOAD_DLOPEN_FAILED, "a failed dlopen is reported");
    expect(unchanged(), "a host that reserved keeps the guest range and the host room after a failed dlopen");
    model_dlopen_fails = 0;
    expect(xl_load(file) == XL_LOAD_OK, "the next load succeeds");
}

static void scenario_attach(const char *folder)
{
    const char *file = library(folder, "attach", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    model_init_result = XL_LIBRARY_MAP_FAILED;
    expect(xl_load(file) == XL_LOAD_MAP_FAILED, "a library that cannot map its guest image is reported");
    expect(model_covered(model_guest_low, model_guest_high, 0) == 0 && !room_held(), "the guest range is given back");
    model_init_result = XL_LIBRARY_OK;
    expect(xl_load(file) == XL_LOAD_MAP_FAILED && xl_reserve(file) == XL_LOAD_MAP_FAILED && model_dlopen_calls == 1,
           "a status after the library's initialization ran is final");
    xl_release();
    expect(model_covered(model_guest_low, model_guest_high, 0) == 0 && !room_held(), "and nothing is held after it");
}

static void scenario_refusals(const char *folder)
{
    const char *newer = library(folder, "newer", BASE_UNDER_STACK, XL_GUEST_VERSION + 1, 1);
    remember();
    expect(xl_load(newer) == XL_LOAD_BAD_IMAGE && strstr(xl_load_error(), "format version"), "a format this loader does not read is refused: %s", xl_load_error());
    const char *alone = library(folder, "alone", BASE_UNDER_STACK, XL_GUEST_VERSION, 0);
    expect(xl_load(alone) == XL_LOAD_BAD_IMAGE && strstr(xl_load_error(), "registry"), "a library without its registry is refused: %s", xl_load_error());
    model_budget_skew = XL_GUEST_GRANULE;
    const char *skewed = library(folder, "skewed", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    model_budget_skew = 0;
    expect(xl_load(skewed) == XL_LOAD_BAD_IMAGE && strstr(xl_load_error(), "do not end there"),
           "a library whose images, arena, words and aliases do not end where its range ends is refused: %s", xl_load_error());
    expect(unchanged(), "no refusal took any address space");
    const char *first = library(folder, "first", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    const char *second = library(folder, "second", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    expect(xl_reserve(first) == XL_LOAD_OK && xl_reserve(second) == XL_LOAD_BAD_IMAGE && strstr(xl_load_error(), "a process holds one translated library"),
           "a second library is refused while the first is reserved");
    xl_release();
    expect(xl_reserve(second) == XL_LOAD_OK, "after xl_release another library can be reserved");
    xl_release();
    expect(unchanged(), "and released");
}

static void scenario_guest_only(const char *folder)
{
    const char *file = library(folder, "guestonly", BASE_UNDER_STACK, XL_GUEST_VERSION, 1);
    setenv("XL_LOADER_HOST_RESERVE", "0", 1);
    uintptr_t before = model_free();
    remember();
    expect(xl_reserve(file) == XL_LOAD_OK && before - model_free() == GUEST_SIZE && !room_held(), "with XL_LOADER_HOST_RESERVE=0 only the guest range is held");
    xl_release();
    expect(unchanged(), "and xl_release gives it back");
    expect(xl_load(file) == XL_LOAD_OK, "the load succeeds");
}

static const struct {
    const char *name;
    void (*run)(const char *folder);
} scenarios[] = {
    {"a reservation kept until the load", scenario_kept},
    {"release and reserve again", scenario_release},
    {"load without a reservation", scenario_lazy},
    {"load without a reservation, guest range held", scenario_lazy_busy},
    {"load without a reservation, no room for the host part", scenario_lazy_no_room},
    {"load without a reservation, dlopen fails", scenario_lazy_dlopen},
    {"a kept reservation, dlopen fails", scenario_kept_dlopen},
    {"the library fails to attach", scenario_attach},
    {"refusals take nothing", scenario_refusals},
    {"guest range only", scenario_guest_only},
};

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: loader FOLDER\n");
        return 2;
    }
    int failed = 0;
    for (size_t index = 0; index < sizeof scenarios / sizeof scenarios[0]; index++) {
        printf("scenario: %s\n", scenarios[index].name);
        fflush(stdout);
        pid_t child = fork();
        if (child < 0) {
            perror("fork");
            return 2;
        }
        if (child == 0) {
            unsetenv("XL_LOADER_MAP");
            unsetenv("XL_LOADER_HOST_RESERVE");
            phone();
            scenarios[index].run(argv[1]);
            fflush(stdout);
            _exit(failures ? 1 : 0);
        }
        int status = 0;
        waitpid(child, &status, 0);
        if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
            failed++;
    }
    printf("%s: %d of %lu scenarios failed\n", failed ? "FAIL" : "ok", failed, (unsigned long)(sizeof scenarios / sizeof scenarios[0]));
    return failed ? 1 : 0;
}
