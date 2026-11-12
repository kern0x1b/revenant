#pragma once

typedef enum {
    XL_LOAD_OK = 0,
    XL_LOAD_BAD_IMAGE,
    XL_LOAD_RANGE_BUSY,
    XL_LOAD_DLOPEN_FAILED,
    XL_LOAD_RELOCATED
} xl_load_status;

xl_load_status xl_reserve(const char *path);
xl_load_status xl_load(const char *path);
const char *xl_load_error(void);
