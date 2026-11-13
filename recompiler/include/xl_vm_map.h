#pragma once

#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <mach/vm_param.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define XL_VM_MAP_MIN_HOLE 0x100000ul
#define XL_VM_MAP_LOW_LIMIT 0x30000000ul

__attribute__((unused)) static int xl_vm_map_enabled(void)
{
    const char *value = getenv("XL_LOADER_MAP");
    return value && *value && strcmp(value, "0") != 0;
}

__attribute__((unused)) static const char *xl_region_image(uintptr_t start, uintptr_t end)
{
    uint32_t count = _dyld_image_count();
    for (uint32_t image = 0; image < count; image++) {
        const struct mach_header *header = _dyld_get_image_header(image);
        if (!header || header->magic != MH_MAGIC)
            continue;
        intptr_t slide = _dyld_get_image_vmaddr_slide(image);
        const uint8_t *cursor = (const uint8_t *)(header + 1);
        for (uint32_t index = 0; index < header->ncmds; index++) {
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmd == LC_SEGMENT) {
                const struct segment_command *segment = (const struct segment_command *)cursor;
                uintptr_t low = segment->vmaddr + slide, high = low + segment->vmsize;
                if (segment->vmsize && low < end && high > start)
                    return _dyld_get_image_name(image);
            }
            cursor += command->cmdsize;
        }
    }
    return NULL;
}

__attribute__((unused)) static const char *xl_region_name(unsigned int tag)
{
    switch (tag) {
    case VM_MEMORY_MALLOC:
        return "malloc";
    case VM_MEMORY_MALLOC_SMALL:
        return "malloc small";
    case VM_MEMORY_MALLOC_LARGE:
        return "malloc large";
    case VM_MEMORY_MALLOC_TINY:
        return "malloc tiny";
    case VM_MEMORY_STACK:
        return "stack";
    default:
        return NULL;
    }
}

static const char *xl_share_name(unsigned char mode)
{
    switch (mode) {
    case SM_COW:
        return "cow";
    case SM_PRIVATE:
        return "private";
    case SM_EMPTY:
        return "empty";
    case SM_SHARED:
        return "shared";
    case SM_TRUESHARED:
        return "true_shared";
    case SM_PRIVATE_ALIASED:
        return "private_aliased";
    case SM_SHARED_ALIASED:
        return "shared_aliased";
    default:
        return "other";
    }
}

static void xl_vm_hole(int fd, const char *phase, uintptr_t start, uintptr_t end, uintptr_t *largest_start, uintptr_t *largest_size,
                       uintptr_t *free_total, uintptr_t *free_low)
{
    if (end <= start)
        return;
    uintptr_t size = end - start;
    *free_total += size;
    if (start < XL_VM_MAP_LOW_LIMIT)
        *free_low += (end < XL_VM_MAP_LOW_LIMIT ? end : XL_VM_MAP_LOW_LIMIT) - start;
    if (size > *largest_size) {
        *largest_size = size;
        *largest_start = start;
    }
    if (size >= XL_VM_MAP_MIN_HOLE)
        dprintf(fd, "xl-map %s hole 0x%08lx 0x%08lx 0x%lx\n", phase, (unsigned long)start, (unsigned long)end, (unsigned long)size);
}

__attribute__((unused)) static void xl_vm_map_dump(int fd, const char *phase)
{
    vm_address_t address = 0;
    vm_size_t size = 0;
    natural_t depth = 0;
    uintptr_t cursor = 0, mapped = 0, largest_start = 0, largest_size = 0, free_total = 0, free_low = 0;
    dprintf(fd, "xl-map %s begin\n", phase);
    for (;;) {
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        if (vm_region_recurse_64(mach_task_self(), &address, &size, &depth, (vm_region_recurse_info_t)&info, &count) != KERN_SUCCESS)
            break;
        if (info.is_submap) {
            depth++;
            continue;
        }
        uintptr_t start = address, end = address + size;
        xl_vm_hole(fd, phase, cursor, start, &largest_start, &largest_size, &free_total, &free_low);
        const char *image = xl_region_image(start, end);
        const char *tag = xl_region_name(info.user_tag);
        dprintf(fd, "xl-map %s region 0x%08lx 0x%08lx 0x%lx %c%c%c/%c%c%c %s %u %s\n", phase, (unsigned long)start, (unsigned long)end,
                (unsigned long)size, info.protection & VM_PROT_READ ? 'r' : '-', info.protection & VM_PROT_WRITE ? 'w' : '-',
                info.protection & VM_PROT_EXECUTE ? 'x' : '-', info.max_protection & VM_PROT_READ ? 'r' : '-',
                info.max_protection & VM_PROT_WRITE ? 'w' : '-', info.max_protection & VM_PROT_EXECUTE ? 'x' : '-',
                xl_share_name(info.share_mode), info.user_tag, image ? image : tag ? tag : "-");
        mapped += size;
        cursor = end;
        address = end;
    }
    xl_vm_hole(fd, phase, cursor, (uintptr_t)VM_MAX_ADDRESS, &largest_start, &largest_size, &free_total, &free_low);
    dprintf(fd, "xl-map %s summary mapped=0x%lx free=0x%lx largest_start=0x%08lx largest_size=0x%lx free_below_0x30000000=0x%lx\n", phase,
            (unsigned long)mapped, (unsigned long)free_total, (unsigned long)largest_start, (unsigned long)largest_size, (unsigned long)free_low);
    dprintf(fd, "xl-map %s end\n", phase);
}
