#include "xl_loader.h"

#include "xl_guest_image.h"
#include "xl_vm_map.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct xl_image {
    uintptr_t guest_low;
    uintptr_t guest_high;
    uintptr_t host_size;
};

static pthread_mutex_t xl_loader_lock = PTHREAD_MUTEX_INITIALIZER;
static char xl_loader_message[512];
static char xl_loader_path[PATH_MAX];
static struct xl_image xl_reserved_image;
static uintptr_t xl_guest_low;
static uintptr_t xl_guest_high;
static uintptr_t xl_host_low;
static void *xl_loaded_handle;
static xl_load_status xl_loader_final;

static xl_load_status xl_fail(xl_load_status status, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    vsnprintf(xl_loader_message, sizeof xl_loader_message, format, arguments);
    va_end(arguments);
    return status;
}

static uintptr_t xl_round_up(uintptr_t value, uintptr_t granule)
{
    return (value + granule - 1) & ~(granule - 1);
}

static xl_load_status xl_read_image(const char *path, struct xl_image *image)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return xl_fail(XL_LOAD_BAD_IMAGE, "cannot open %s", path);
    struct mach_header header;
    if (pread(fd, &header, sizeof header, 0) != (ssize_t)sizeof header || header.magic != MH_MAGIC || header.filetype != MH_DYLIB ||
        header.cputype != CPU_TYPE_ARM) {
        close(fd);
        return xl_fail(XL_LOAD_BAD_IMAGE, "%s is not a 32-bit ARM dynamic library", path);
    }
    uint8_t *commands = malloc(header.sizeofcmds);
    if (!commands || pread(fd, commands, header.sizeofcmds, sizeof header) != (ssize_t)header.sizeofcmds) {
        free(commands);
        close(fd);
        return xl_fail(XL_LOAD_BAD_IMAGE, "cannot read the load commands of %s", path);
    }
    uintptr_t first = UINTPTR_MAX, last = 0;
    uint32_t section_offset = 0, section_size = 0;
    const uint8_t *cursor = commands;
    for (uint32_t index = 0; index < header.ncmds; index++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmd == LC_SEGMENT) {
            const struct segment_command *segment = (const struct segment_command *)cursor;
            if (segment->vmsize && strcmp(segment->segname, "__PAGEZERO") != 0) {
                if (segment->vmaddr < first)
                    first = segment->vmaddr;
                if (segment->vmaddr + segment->vmsize > last)
                    last = segment->vmaddr + segment->vmsize;
            }
            const struct section *sections = (const struct section *)(segment + 1);
            for (uint32_t section = 0; section < segment->nsects; section++) {
                if (strncmp(sections[section].segname, XL_GUEST_SEGMENT, sizeof sections[section].segname) == 0 &&
                    strncmp(sections[section].sectname, XL_GUEST_SECTION, sizeof sections[section].sectname) == 0) {
                    section_offset = sections[section].offset;
                    section_size = sections[section].size;
                }
            }
        }
        cursor += command->cmdsize;
    }
    free(commands);
    struct xl_guest_header guest;
    if (first >= last || !section_offset || section_size < sizeof guest || pread(fd, &guest, sizeof guest, section_offset) != (ssize_t)sizeof guest) {
        close(fd);
        return xl_fail(XL_LOAD_BAD_IMAGE, "%s has no guest image (section %s,%s)", path, XL_GUEST_SEGMENT, XL_GUEST_SECTION);
    }
    close(fd);
    if (guest.magic != XL_GUEST_MAGIC)
        return xl_fail(XL_LOAD_BAD_IMAGE, "the guest image of %s does not start with the format magic", path);
    if (guest.version != XL_GUEST_VERSION)
        return xl_fail(XL_LOAD_BAD_IMAGE, "the guest image of %s is format version %u, this loader reads version %u", path, guest.version,
                       XL_GUEST_VERSION);
    if (guest.low >= guest.high || guest.low % XL_GUEST_GRANULE || guest.high % XL_GUEST_GRANULE)
        return xl_fail(XL_LOAD_BAD_IMAGE, "the guest image of %s has the range 0x%x-0x%x, not a range of whole %u byte granules", path, guest.low, guest.high,
                       XL_GUEST_GRANULE);
    char registry[PATH_MAX];
    if (!xl_registry_path(path, registry, sizeof registry) || access(registry, R_OK) != 0)
        return xl_fail(XL_LOAD_BAD_IMAGE, "the registry of the Objective-C classes of %s is missing: it is the file %s%s next to it", path,
                       strrchr(path, '/') ? strrchr(path, '/') + 1 : path, XL_REGISTRY_SUFFIX);
    image->guest_low = guest.low;
    image->guest_high = guest.high;
    image->host_size = xl_round_up(last - first, vm_page_size);
    return XL_LOAD_OK;
}

static void xl_describe_occupant(uintptr_t low, uintptr_t high, char *text, size_t capacity)
{
    vm_address_t address = low;
    vm_size_t size = 0;
    natural_t depth = 0;
    struct vm_region_submap_info_64 info;
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    if (vm_region_recurse_64(mach_task_self(), &address, &size, &depth, (vm_region_recurse_info_t)&info, &count) != KERN_SUCCESS || address >= high) {
        snprintf(text, capacity, "a mapping that the kernel does not list");
        return;
    }
    const char *image = xl_region_image(address, address + size);
    const char *name = xl_region_name(info.user_tag);
    if (image)
        snprintf(text, capacity, "0x%lx-0x%lx, %s", (unsigned long)address, (unsigned long)(address + size), image);
    else if (name)
        snprintf(text, capacity, "0x%lx-0x%lx, %s, %lu MB", (unsigned long)address, (unsigned long)(address + size), name, (unsigned long)(size >> 20));
    else
        snprintf(text, capacity, "0x%lx-0x%lx, memory tag %u, %lu MB", (unsigned long)address, (unsigned long)(address + size), info.user_tag,
                 (unsigned long)(size >> 20));
}

static xl_load_status xl_reserve_guest(const struct xl_image *image, const char *path)
{
    vm_address_t address = image->guest_low;
    size_t size = image->guest_high - image->guest_low;
    if (vm_allocate(mach_task_self(), &address, size, VM_FLAGS_FIXED) != KERN_SUCCESS) {
        char occupant[160];
        xl_describe_occupant(image->guest_low, image->guest_high, occupant, sizeof occupant);
        return xl_fail(XL_LOAD_RANGE_BUSY, "another mapping holds %s, inside 0x%lx-0x%lx where the guest image of %s must be loaded", occupant,
                       (unsigned long)image->guest_low, (unsigned long)image->guest_high, path);
    }
    vm_protect(mach_task_self(), address, size, FALSE, VM_PROT_NONE);
    xl_guest_low = image->guest_low;
    xl_guest_high = image->guest_high;
    return XL_LOAD_OK;
}

static xl_load_status xl_reserve_host(const struct xl_image *image, const char *path)
{
    vm_address_t address = 0;
    if (vm_allocate(mach_task_self(), &address, image->host_size, VM_FLAGS_ANYWHERE) != KERN_SUCCESS)
        return xl_fail(XL_LOAD_RANGE_BUSY, "no free range of %lu MB for the host part of %s", (unsigned long)(image->host_size >> 20), path);
    vm_protect(mach_task_self(), address, image->host_size, FALSE, VM_PROT_NONE);
    xl_host_low = address;
    return XL_LOAD_OK;
}

static void xl_release_guest(void)
{
    if (xl_guest_high)
        vm_deallocate(mach_task_self(), xl_guest_low, xl_guest_high - xl_guest_low);
    xl_guest_low = xl_guest_high = 0;
}

static void xl_release_host(void)
{
    if (xl_host_low)
        vm_deallocate(mach_task_self(), xl_host_low, xl_reserved_image.host_size);
    xl_host_low = 0;
}

static xl_load_status xl_reserve_locked(const char *path)
{
    char resolved[PATH_MAX];
    if (!realpath(path, resolved))
        return xl_fail(XL_LOAD_BAD_IMAGE, "cannot open %s", path);
    if (xl_guest_high || xl_host_low) {
        if (strcmp(resolved, xl_loader_path) != 0)
            return xl_fail(XL_LOAD_BAD_IMAGE, "%s is reserved, a process holds one translated library", xl_loader_path);
        if (xl_guest_high && xl_host_low)
            return XL_LOAD_OK;
    }
    struct xl_image image;
    xl_load_status status = xl_read_image(resolved, &image);
    if (status != XL_LOAD_OK)
        return status;
    xl_reserved_image = image;
    strcpy(xl_loader_path, resolved);
    if (!xl_guest_high && (status = xl_reserve_guest(&image, resolved)) != XL_LOAD_OK)
        return status;
    if (!xl_host_low && (status = xl_reserve_host(&image, resolved)) != XL_LOAD_OK) {
        xl_release_guest();
        return status;
    }
    return XL_LOAD_OK;
}

static void xl_map_phase(const char *phase, xl_load_status status)
{
    if (!xl_vm_map_enabled())
        return;
    char name[48];
    snprintf(name, sizeof name, status == XL_LOAD_OK ? "%s" : "%s-failed", phase);
    xl_vm_map_dump(STDERR_FILENO, name);
}

xl_load_status xl_reserve(const char *path)
{
    pthread_mutex_lock(&xl_loader_lock);
    if (!xl_guest_high && !xl_host_low && !xl_loaded_handle)
        xl_map_phase("before-reserve", XL_LOAD_OK);
    xl_load_status status = xl_loader_final != XL_LOAD_OK ? xl_loader_final : xl_loaded_handle ? XL_LOAD_OK : xl_reserve_locked(path);
    xl_map_phase("reserve", status);
    pthread_mutex_unlock(&xl_loader_lock);
    return status;
}

static xl_load_status xl_attach_failed(int failure)
{
    xl_release_guest();
    switch (failure) {
    case XL_LIBRARY_BAD_FORMAT:
        return xl_fail(XL_LOAD_BAD_IMAGE, "the guest image of %s is not in the format this library reads", xl_loader_path);
    case XL_LIBRARY_NOT_RESERVED:
        return xl_fail(XL_LOAD_RANGE_BUSY, "the reservation of the guest image of %s was not an untouched, inaccessible range when the library attached it",
                       xl_loader_path);
    case XL_LIBRARY_NO_REGISTRY:
        return xl_fail(XL_LOAD_BAD_IMAGE, "the registry of the Objective-C classes of %s is missing: it is the file %s%s next to it", xl_loader_path,
                       strrchr(xl_loader_path, '/') ? strrchr(xl_loader_path, '/') + 1 : xl_loader_path, XL_REGISTRY_SUFFIX);
    case XL_LIBRARY_REGISTRY_FAILED:
        return xl_fail(XL_LOAD_DLOPEN_FAILED, "dlopen of the registry of %s: %s", xl_loader_path, dlerror());
    default:
        return xl_fail(XL_LOAD_MAP_FAILED, "mapping the guest image of %s failed", xl_loader_path);
    }
}

static xl_load_status xl_load_locked(const char *path)
{
    if (xl_loader_final != XL_LOAD_OK)
        return xl_loader_final;
    if (xl_loaded_handle)
        return XL_LOAD_OK;
    xl_load_status status = xl_reserve_locked(path);
    if (status != XL_LOAD_OK)
        return status;
    xl_release_host();
    void *handle = dlopen(xl_loader_path, RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        xl_reserve_host(&xl_reserved_image, xl_loader_path);
        return xl_fail(XL_LOAD_DLOPEN_FAILED, "dlopen: %s", dlerror());
    }
    int (*initialize)(void) = (int (*)(void))dlsym(handle, "xl_library_init");
    if (!initialize)
        return xl_fail(XL_LOAD_BAD_IMAGE, "%s has no xl_library_init", xl_loader_path);
    int failure = initialize();
    if (failure != XL_LIBRARY_OK)
        return xl_loader_final = xl_attach_failed(failure);
    xl_guest_low = xl_guest_high = 0;
    xl_loaded_handle = handle;
    return XL_LOAD_OK;
}

xl_load_status xl_load(const char *path)
{
    pthread_mutex_lock(&xl_loader_lock);
    xl_load_status status = xl_load_locked(path);
    xl_map_phase("load", status);
    pthread_mutex_unlock(&xl_loader_lock);
    return status;
}

const char *xl_load_error(void)
{
    return xl_loader_message;
}
