#include <CoreFoundation/CoreFoundation.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <mach/mach.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

#include "xl_bridge.h"
#include "xl_host.h"

enum {
    XL_CONSTANT_RANGES = 128,
    XL_ALIAS_ARENA = 4 << 20,
    XL_ALIAS_BLOCK_OFFSET = 12,
    XL_ALIAS_OBJECT_OFFSET = 16,
    XL_CF_ALLOCATOR_PREFIX = 4,
    XL_CONSTANT_STRIDE = 16
};

#define XL_ALIAS_MAGIC 0x584c4153u

struct xl_constant_range {
    uintptr_t low;
    uintptr_t size;
};

uintptr_t xl_alias_low;
uintptr_t xl_alias_span;

static struct xl_constant_range xl_constant_ranges[XL_CONSTANT_RANGES];
static volatile unsigned xl_constant_count;
static pthread_once_t xl_alias_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t xl_alias_lock = PTHREAD_MUTEX_INITIALIZER;
static uintptr_t xl_alias_cursor;
static uintptr_t xl_alias_first_block;
static uintptr_t xl_alias_original;
static CFAllocatorRef xl_alias_allocator;
static CFMutableDictionaryRef xl_alias_strings;
static CFMutableDictionaryRef xl_alias_protocols;
static Class xl_protocol_class;

static uintptr_t xl_alias_reserve(uintptr_t original, size_t size)
{
    uintptr_t slot = xl_alias_cursor;
    uintptr_t block = slot + XL_ALIAS_BLOCK_OFFSET;
    uintptr_t next = (block + size + 7) & ~(uintptr_t)7;
    if (next > xl_alias_low + XL_ALIAS_ARENA)
        xl_unsupported("xlate: the arena of 8-aligned copies of host constants is full");
    xl_alias_cursor = next;
    ((uint32_t *)slot)[0] = (uint32_t)original;
    ((uint32_t *)slot)[1] = (uint32_t)(slot + XL_ALIAS_OBJECT_OFFSET) ^ XL_ALIAS_MAGIC;
    return block;
}

static void *xl_alias_allocate(CFIndex size, CFOptionFlags hint, void *info)
{
    (void)hint;
    (void)info;
    uintptr_t block = xl_alias_reserve(xl_alias_original, (size_t)size);
    if (!xl_alias_first_block)
        xl_alias_first_block = block;
    return (void *)block;
}

static void *xl_alias_reallocate(void *pointer, CFIndex size, CFOptionFlags hint, void *info)
{
    (void)pointer;
    (void)size;
    (void)hint;
    (void)info;
    return NULL;
}

static void xl_alias_deallocate(void *pointer, void *info)
{
    (void)pointer;
    (void)info;
}

static void xl_alias_image(const struct mach_header *header, intptr_t slide)
{
    const struct section *section = getsectbynamefromheader(header, "__DATA", "__cfstring");
    if (!section || !section->size)
        return;
    uintptr_t start = (uintptr_t)section->addr + (uintptr_t)slide;
    if ((start & 7) == 0)
        return;
    unsigned index = xl_constant_count;
    if (index == XL_CONSTANT_RANGES) {
        fprintf(stderr, "xlate: more than %d images with 4-aligned constant strings\n", XL_CONSTANT_RANGES);
        abort();
    }
    xl_constant_ranges[index].low = start;
    xl_constant_ranges[index].size = section->size;
    __sync_synchronize();
    xl_constant_count = index + 1;
}

static void xl_alias_setup(void)
{
    void *arena = mmap(NULL, XL_ALIAS_ARENA, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (arena == MAP_FAILED)
        xl_unsupported("xlate: cannot map the arena of 8-aligned copies of host constants");
    xl_alias_cursor = (uintptr_t)arena;
    CFAllocatorContext context = {0, NULL, NULL, NULL, NULL, xl_alias_allocate, xl_alias_reallocate, xl_alias_deallocate, NULL};
    xl_alias_allocator = CFAllocatorCreate(NULL, &context);
    xl_alias_strings = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_alias_protocols = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    xl_protocol_class = objc_getClass("Protocol");
    _dyld_register_func_for_add_image(xl_alias_image);
    __sync_synchronize();
    xl_alias_low = (uintptr_t)arena;
    xl_alias_span = XL_ALIAS_ARENA;
}

static int xl_constant_string(uintptr_t pointer)
{
    unsigned count = xl_constant_count;
    for (unsigned i = 0; i < count; i++) {
        uintptr_t offset = pointer - xl_constant_ranges[i].low;
        if (offset < xl_constant_ranges[i].size && offset % XL_CONSTANT_STRIDE == 0)
            return 1;
    }
    return 0;
}

static int xl_read_word(uintptr_t address, uint32_t *word)
{
    vm_size_t size = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)address, sizeof *word, (vm_address_t)word, &size) == KERN_SUCCESS &&
           size == sizeof *word;
}

static uint64_t xl_alias_string(uintptr_t original)
{
    pthread_mutex_lock(&xl_alias_lock);
    uintptr_t alias = (uintptr_t)CFDictionaryGetValue(xl_alias_strings, (const void *)original);
    if (!alias) {
        CFIndex length = CFStringGetLength((CFStringRef)original);
        UniChar stack[256];
        UniChar *characters = length <= 256 ? stack : malloc((size_t)length * sizeof(UniChar));
        CFStringGetCharacters((CFStringRef)original, CFRangeMake(0, length), characters);
        xl_alias_original = original;
        xl_alias_first_block = 0;
        alias = (uintptr_t)CFStringCreateWithCharacters(xl_alias_allocator, characters, length);
        if (characters != stack)
            free(characters);
        if (!alias || (alias & 7) || alias != xl_alias_first_block + XL_CF_ALLOCATOR_PREFIX)
            xl_unsupported("xlate: CoreFoundation did not place a copy of a constant string at the start of its block, 8-aligned");
        CFDictionarySetValue(xl_alias_strings, (const void *)original, (const void *)alias);
    }
    pthread_mutex_unlock(&xl_alias_lock);
    return (uint64_t)alias;
}

static uint64_t xl_alias_protocol_shell(uintptr_t original)
{
    pthread_mutex_lock(&xl_alias_lock);
    uintptr_t alias = (uintptr_t)CFDictionaryGetValue(xl_alias_protocols, (const void *)original);
    if (!alias) {
        uint32_t *shell = (uint32_t *)(xl_alias_reserve(original, XL_CF_ALLOCATOR_PREFIX + 16) + XL_CF_ALLOCATOR_PREFIX);
        shell[0] = *(const uint32_t *)original;
        shell[1] = (uint32_t)(uintptr_t)protocol_getName((Protocol *)original);
        shell[2] = 0;
        shell[3] = 0;
        alias = (uintptr_t)shell;
        CFDictionarySetValue(xl_alias_protocols, (const void *)original, (const void *)alias);
    }
    pthread_mutex_unlock(&xl_alias_lock);
    return (uint64_t)alias;
}

uint64_t xl_alias_pointer(uintptr_t host)
{
    pthread_once(&xl_alias_once, xl_alias_setup);
    if (xl_constant_string(host))
        return xl_alias_string(host);
    return xl_widen_plain(host);
}

uint64_t xl_protocol_out(uintptr_t host)
{
    if (!host || (host & 7) == 0)
        return xl_widen_plain(host);
    pthread_once(&xl_alias_once, xl_alias_setup);
    return xl_alias_protocol_shell(host);
}

uint64_t xl_alias_object(uintptr_t host)
{
    pthread_once(&xl_alias_once, xl_alias_setup);
    if (xl_constant_string(host))
        return xl_alias_string(host);
    if (host < 0x1000 || host >= 0xFFFFF000u)
        return 0;
    uint32_t isa;
    if (!xl_read_word(host, &isa) || !isa)
        return 0;
    if ((Class)(uintptr_t)isa == xl_protocol_class)
        return xl_alias_protocol_shell(host);
    if (xl_class_out(host) != host || class_isMetaClass((Class)(uintptr_t)isa))
        return 0;
    char message[256];
    snprintf(message, sizeof message,
             "xlate: the host object %p (class %s) is not 8-aligned and is neither a constant string nor a protocol, "
             "and the guest Swift runtime clears the low 3 bits of object pointers",
             (void *)host, class_getName((Class)(uintptr_t)isa));
    xl_unsupported(message);
}

uintptr_t xl_alias_resolve(uintptr_t pointer)
{
    if ((pointer & 7) || pointer - xl_alias_low < XL_ALIAS_OBJECT_OFFSET)
        return pointer;
    const uint32_t *slot = (const uint32_t *)(pointer - XL_ALIAS_OBJECT_OFFSET);
    if (slot[1] != ((uint32_t)pointer ^ XL_ALIAS_MAGIC))
        return pointer;
    return slot[0];
}
