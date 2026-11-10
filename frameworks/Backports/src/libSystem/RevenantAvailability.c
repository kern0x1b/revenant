#include "../revenant_impl.h"
#include <TargetConditionals.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define REVENANT_LIBSYSTEM_EXPORT __attribute__((visibility("default")))

#define REVENANT_SYSTEM_VERSION_PLIST "/System/Library/CoreServices/SystemVersion.plist"

#if TARGET_OS_OSX
#define REVENANT_AVAILABILITY_PLATFORM 1
#elif TARGET_OS_IOS
#define REVENANT_AVAILABILITY_PLATFORM 2
#elif TARGET_OS_TV
#define REVENANT_AVAILABILITY_PLATFORM 3
#elif TARGET_OS_WATCH
#define REVENANT_AVAILABILITY_PLATFORM 4
#elif defined(TARGET_OS_VISION) && TARGET_OS_VISION
#define REVENANT_AVAILABILITY_PLATFORM 11
#else
#define REVENANT_AVAILABILITY_PLATFORM 0
#endif

struct revenant_build_version {
    uint32_t platform;
    uint32_t version;
};

static uint32_t release_version;
static pthread_once_t release_once = PTHREAD_ONCE_INIT;

static unsigned parse_component(const char **cursor)
{
    unsigned value = 0;
    while (**cursor >= '0' && **cursor <= '9') {
        value = value * 10 + (unsigned)(**cursor - '0');
        (*cursor)++;
    }
    return value;
}

static uint32_t encode_version(unsigned major, unsigned minor, unsigned patch)
{
    return ((major & 0xffff) << 16) | ((minor & 0xff) << 8) | (patch & 0xff);
}

static void read_release_version(void)
{
    FILE *file = fopen(REVENANT_SYSTEM_VERSION_PLIST, "r");
    if (file == NULL) {
        return;
    }
    char text[4096];
    size_t length = fread(text, 1, sizeof text - 1, file);
    fclose(file);
    text[length] = '\0';
    const char *key = strstr(text, "<key>ProductVersion</key>");
    if (key == NULL) {
        return;
    }
    const char *value = strstr(key, "<string>");
    if (value == NULL) {
        return;
    }
    const char *cursor = value + strlen("<string>");
    unsigned major = parse_component(&cursor);
    unsigned minor = 0;
    unsigned patch = 0;
    if (*cursor == '.') {
        cursor++;
        minor = parse_component(&cursor);
        if (*cursor == '.') {
            cursor++;
            patch = parse_component(&cursor);
        }
    }
    release_version = encode_version(major, minor, patch);
}

REVENANT_LIBSYSTEM_EXPORT int BACKPORT_IMPL(_availability_version_check)(unsigned count, const struct revenant_build_version versions[])
{
    if (count == 0) {
        return 1;
    }
    pthread_once(&release_once, read_release_version);
    for (unsigned index = 0; index < count; index++) {
        if (versions[index].platform != REVENANT_AVAILABILITY_PLATFORM) {
            continue;
        }
        return release_version >= versions[index].version;
    }
    return 1;
}
