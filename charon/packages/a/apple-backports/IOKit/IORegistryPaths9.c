#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

// The two registry lookups of iOS 9, written over the two the release already has.
// IORegistryEntryCopyFromPath is the release's own IORegistryEntryFromPath with the path a caller has
// as a CFString, and IORegistryEntryCopyPath is the release's own IORegistryEntryGetPath with the path
// it fills a buffer with given back as a CFString; both are +1 as their names promise
// (facts/IOKit/IORegistryPaths.md).
//
// A .c file of this package is compiled hidden, so what it must export says so itself, the way
// Foundation's CFBoolean constants do. An entry of 0 and a path that is nil are answered rather than
// dereferenced: the host reads through both and crashes, and an API of this port never crashes the
// caller.

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
