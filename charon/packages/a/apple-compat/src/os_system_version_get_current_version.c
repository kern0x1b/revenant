#include <CoreFoundation/CoreFoundation.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "system_function.h"

struct os_system_version_s {
    unsigned int major;
    unsigned int minor;
    unsigned int patch;
};

static _Atomic(uintptr_t) charon_system_version;

__attribute__((constructor))
static void charon_resolve_system_version(void)
{
    charon_system_function(&charon_system_version, CHARON_LIBSYSTEM, "os_system_version_get_current_version");
}

/* The release's own record of its version: the ProductVersion of SystemVersion.plist, which Swift's runtime read below iOS 8
   (stdlib/public/stubs/Availability.mm up to swift-5.0) and compiler-rt's check for #available reads where the release has
   no _availability_version_check (lib/builtins/os_version_check.c). */
static int charon_version_from_plist(struct os_system_version_s *version)
{
    FILE *file = fopen("/System/Library/CoreServices/SystemVersion.plist", "rb");
    if (!file)
        return errno;
    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);
    UInt8 chunk[1024];
    size_t read;
    while ((read = fread(chunk, 1, sizeof chunk, file)) > 0)
        CFDataAppendBytes(data, chunk, (CFIndex)read);
    int failed = ferror(file);
    fclose(file);
    if (failed) {
        CFRelease(data);
        return EIO;
    }
    CFPropertyListRef list = CFPropertyListCreateWithData(kCFAllocatorDefault, data, kCFPropertyListImmutable, NULL, NULL);
    CFRelease(data);
    int answered = EINVAL;
    if (list && CFGetTypeID(list) == CFDictionaryGetTypeID()) {
        CFStringRef product = CFDictionaryGetValue((CFDictionaryRef)list, CFSTR("ProductVersion"));
        char text[32];
        unsigned int parts[3] = {0, 0, 0};
        if (product && CFGetTypeID(product) == CFStringGetTypeID() &&
            CFStringGetCString(product, text, sizeof text, kCFStringEncodingASCII) &&
            sscanf(text, "%u.%u.%u", &parts[0], &parts[1], &parts[2]) >= 1) {
            version->major = parts[0];
            version->minor = parts[1];
            version->patch = parts[2];
            answered = 0;
        }
    }
    if (list)
        CFRelease(list);
    return answered;
}

/* os_system_version_get_current_version arrived in iOS 10, where the system's answers; before it the version is read from the
   file the system's own answer comes from. */
__attribute__((visibility("hidden")))
int charon_os_system_version_get_current_version(struct os_system_version_s *version)
{
    int (*system)(struct os_system_version_s *) =
        charon_system_function(&charon_system_version, CHARON_LIBSYSTEM, "os_system_version_get_current_version");
    return system ? system(version) : charon_version_from_plist(version);
}
