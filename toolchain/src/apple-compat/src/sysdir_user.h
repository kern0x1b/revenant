#ifndef REVENANT_SYSDIR_USER_H
#define REVENANT_SYSDIR_USER_H

#include <string.h>

static const char *const sysdir_user_paths[] = {
    [5] = "~/Library",
    [8] = "~/Library/Documentation",
    [9] = "~/Documents",
    [10] = "~/Library/CoreServices",
    [11] = "~/Library/Autosave Information",
    [12] = "~/Desktop",
    [13] = "~/Library/Caches",
    [14] = "~/Library/Application Support",
    [15] = "~/Downloads",
    [16] = "~/Library/Input Methods",
    [17] = "~/Movies",
    [18] = "~/Music",
    [19] = "~/Pictures",
    [20] = "~/Library/Printers/PPDs",
    [21] = "~/Public",
    [22] = "~/Library/PreferencePanes",
};

#define SYSDIR_USER_DOMAIN 1u
#define SYSDIR_USER_COUNT (sizeof sysdir_user_paths / sizeof sysdir_user_paths[0])

static inline unsigned int sysdir_user_start(unsigned int directory, unsigned int domains)
{
    if (!(domains & SYSDIR_USER_DOMAIN) || directory >= SYSDIR_USER_COUNT || sysdir_user_paths[directory] == NULL) {
        return 0;
    }
    return (directory << 1) | 1u;
}

static inline unsigned int sysdir_user_next(unsigned int state, char *path)
{
    if (!(state & 1u)) {
        return 0;
    }
    unsigned int directory = state >> 1;
    if (directory >= SYSDIR_USER_COUNT || sysdir_user_paths[directory] == NULL) {
        return 0;
    }
    memcpy(path, sysdir_user_paths[directory], strlen(sysdir_user_paths[directory]) + 1);
    return 0;
}

#endif
