#include "xl_loader.h"

#include <dlfcn.h>
#include <fcntl.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static pthread_mutex_t xl_loader_lock = PTHREAD_MUTEX_INITIALIZER;
static char xl_loader_message[512];
static uintptr_t xl_reserved_low;
static uintptr_t xl_reserved_high;
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

static xl_load_status xl_image_range(const char *path, uintptr_t *low, uintptr_t *high)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return xl_fail(XL_LOAD_BAD_IMAGE, "cannot open %s", path);
    struct mach_header header;
    if (pread(fd, &header, sizeof header, 0) != (ssize_t)sizeof header || header.magic != MH_MAGIC ||
        header.filetype != MH_DYLIB || header.cputype != CPU_TYPE_ARM) {
        close(fd);
        return xl_fail(XL_LOAD_BAD_IMAGE, "%s is not a 32-bit ARM dynamic library", path);
    }
    uint8_t *commands = malloc(header.sizeofcmds);
    if (!commands || pread(fd, commands, header.sizeofcmds, sizeof header) != (ssize_t)header.sizeofcmds) {
        free(commands);
        close(fd);
        return xl_fail(XL_LOAD_BAD_IMAGE, "cannot read the load commands of %s", path);
    }
    close(fd);
    uintptr_t first = UINTPTR_MAX, last = 0;
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
        }
        cursor += command->cmdsize;
    }
    free(commands);
    if (first >= last)
        return xl_fail(XL_LOAD_BAD_IMAGE, "%s has no segments", path);
    *low = first;
    *high = (last + vm_page_size - 1) & ~((uintptr_t)vm_page_size - 1);
    return XL_LOAD_OK;
}

static xl_load_status xl_reserve_locked(const char *path)
{
    if (xl_reserved_high)
        return XL_LOAD_OK;
    uintptr_t low, high;
    xl_load_status status = xl_image_range(path, &low, &high);
    if (status != XL_LOAD_OK)
        return status;
    vm_address_t address = low;
    if (vm_allocate(mach_task_self(), &address, high - low, VM_FLAGS_FIXED) != KERN_SUCCESS)
        return xl_fail(XL_LOAD_RANGE_BUSY, "another mapping holds 0x%lx-0x%lx, where %s must be loaded", (unsigned long)low,
                       (unsigned long)high, path);
    vm_protect(mach_task_self(), low, high - low, FALSE, VM_PROT_NONE);
    xl_reserved_low = low;
    xl_reserved_high = high;
    return XL_LOAD_OK;
}

static void xl_release_locked(void)
{
    vm_deallocate(mach_task_self(), xl_reserved_low, xl_reserved_high - xl_reserved_low);
    xl_reserved_low = xl_reserved_high = 0;
}

xl_load_status xl_reserve(const char *path)
{
    pthread_mutex_lock(&xl_loader_lock);
    xl_load_status status = xl_loader_final != XL_LOAD_OK ? xl_loader_final : xl_loaded_handle ? XL_LOAD_OK : xl_reserve_locked(path);
    pthread_mutex_unlock(&xl_loader_lock);
    return status;
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
    xl_release_locked();
    void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        xl_reserve_locked(path);
        return xl_fail(XL_LOAD_DLOPEN_FAILED, "dlopen: %s", dlerror());
    }
    int (*initialize)(void) = (int (*)(void))dlsym(handle, "xl_library_init");
    if (!initialize)
        return xl_fail(XL_LOAD_BAD_IMAGE, "%s has no xl_library_init", path);
    if (initialize() != 0) {
        xl_loader_final = XL_LOAD_RELOCATED;
        return xl_fail(XL_LOAD_RELOCATED, "dyld loaded %s away from its link address, so its guest addresses are wrong", path);
    }
    xl_loaded_handle = handle;
    return XL_LOAD_OK;
}

xl_load_status xl_load(const char *path)
{
    pthread_mutex_lock(&xl_loader_lock);
    xl_load_status status = xl_load_locked(path);
    pthread_mutex_unlock(&xl_loader_lock);
    return status;
}

const char *xl_load_error(void)
{
    return xl_loader_message;
}
