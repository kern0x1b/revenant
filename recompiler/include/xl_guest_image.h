#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define XL_GUEST_SEGMENT "__XGUEST"
#define XL_GUEST_SECTION "__image"
#define XL_GUEST_MAGIC 0x49474c58u
#define XL_GUEST_VERSION 2u
#define XL_GUEST_GRANULE 0x4000u
#define XL_GUEST_CEILING 0x2fc00000u
#define XL_GUEST_WORD_STRIDE 16u
#define XL_GUEST_WORD_BYTES (XL_GUEST_WORD_STRIDE + 8u + 2u * 4u)
#define XL_GUEST_WORD_SLOTS_LEAST (XL_GUEST_GRANULE / 8u)
#define XL_GUEST_WORD_SLOTS 262144u
#define XL_GUEST_ALIASES (4u << 20)

#define XL_GUEST_READ 1u
#define XL_GUEST_WRITE 2u

#define XL_REGISTRY_SUFFIX "-classes.dylib"

struct xl_guest_header {
    uint32_t magic;
    uint32_t version;
    uint32_t low;
    uint32_t high;
    uint32_t segment_count;
    uint32_t images_high;
    uint32_t arena;
    uint32_t word_slots;
    uint32_t aliases;
};

static inline int xl_guest_budget_fits(const struct xl_guest_header *header)
{
    uint32_t slots = header->word_slots;
    if (header->images_high <= header->low || header->images_high > header->high || header->images_high % XL_GUEST_GRANULE)
        return 0;
    if (header->arena % XL_GUEST_GRANULE || header->aliases % XL_GUEST_GRANULE || !header->aliases)
        return 0;
    if (slots < XL_GUEST_WORD_SLOTS_LEAST || (slots & (slots - 1)) || slots > (UINT32_MAX / XL_GUEST_WORD_BYTES))
        return 0;
    uint64_t end = (uint64_t)header->images_high + header->arena + (uint64_t)slots * XL_GUEST_WORD_BYTES + header->aliases;
    return end == header->high;
}

struct xl_guest_segment {
    uint32_t address;
    uint32_t size;
    uint32_t offset;
    uint32_t length;
    uint32_t protection;
};

struct xl_guest_slot {
    uint32_t address;
    uint32_t value;
};

enum {
    XL_LIBRARY_OK = 0,
    XL_LIBRARY_BAD_FORMAT,
    XL_LIBRARY_NOT_RESERVED,
    XL_LIBRARY_MAP_FAILED,
    XL_LIBRARY_NO_REGISTRY,
    XL_LIBRARY_REGISTRY_FAILED
};

static inline int xl_registry_path(const char *library, char *path, size_t capacity)
{
    size_t length = strlen(library);
    if (length > 6 && strcmp(library + length - 6, ".dylib") == 0)
        length -= 6;
    if (length + sizeof XL_REGISTRY_SUFFIX > capacity)
        return 0;
    memcpy(path, library, length);
    memcpy(path + length, XL_REGISTRY_SUFFIX, sizeof XL_REGISTRY_SUFFIX);
    return 1;
}
