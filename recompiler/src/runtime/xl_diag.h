#pragma once

#include <ctype.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define XL_DIAG_DIR "/private/var/revenant/"

struct xl_diag_flag {
    const char *name;
    int state;
};

static inline int xl_diag_on(struct xl_diag_flag *flag)
{
    int state = __atomic_load_n(&flag->state, __ATOMIC_ACQUIRE);
    if (state)
        return state > 0;
    char variable[48];
    size_t length = 0;
    for (const char *c = flag->name; *c && length + 1 < sizeof variable; c++)
        variable[length++] = *c == '-' ? '_' : (char)toupper((unsigned char)*c);
    variable[length] = 0;
    int on = getenv(variable) != NULL;
    if (!on) {
        char path[96];
        snprintf(path, sizeof path, XL_DIAG_DIR "%s", flag->name);
        on = access(path, F_OK) == 0;
    }
    __atomic_store_n(&flag->state, on ? 1 : -1, __ATOMIC_RELEASE);
    return on;
}

static inline int xl_diag_open(const char *file, int flags)
{
    char path[96];
    snprintf(path, sizeof path, XL_DIAG_DIR "%s", file);
    return open(path, O_WRONLY | O_CREAT | flags, 0666);
}
