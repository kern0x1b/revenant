#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

#define CHARON_IOKIT_EXPORT __attribute__((visibility("default")))

CHARON_IOKIT_EXPORT CFStringRef IORegistryEntryCopyPath(io_registry_entry_t entry, const io_name_t plane)
{
    io_string_t path;

    if (entry == 0 || IORegistryEntryGetPath(entry, plane, path) != KERN_SUCCESS) {
        return 0;
    }
    return CFStringCreateWithCString(0, path, kCFStringEncodingUTF8);
}

CHARON_IOKIT_EXPORT io_registry_entry_t IORegistryEntryCopyFromPath(mach_port_t mainPort, CFStringRef path)
{
    io_string_t buffer;

    if (path == 0 || !CFStringGetCString(path, buffer, sizeof(buffer), kCFStringEncodingUTF8)) {
        return MACH_PORT_NULL;
    }
    return IORegistryEntryFromPath(mainPort, buffer);
}
