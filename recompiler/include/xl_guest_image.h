#pragma once

#include <stdint.h>

#define XL_GUEST_SEGMENT "__XGUEST"
#define XL_GUEST_SECTION "__image"
#define XL_GUEST_MAGIC 0x49474c58u
#define XL_GUEST_VERSION 1u
#define XL_GUEST_GRANULE 0x4000u

#define XL_GUEST_READ 1u
#define XL_GUEST_WRITE 2u

struct xl_guest_header {
    uint32_t magic;
    uint32_t version;
    uint32_t low;
    uint32_t high;
    uint32_t segment_count;
};

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
    XL_LIBRARY_MAP_FAILED
};
