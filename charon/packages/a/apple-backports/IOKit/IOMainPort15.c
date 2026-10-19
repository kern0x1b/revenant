#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

// The default main port of iOS 15, and the call that asks the system for one. iOS 6.1.3 has no
// separate IOKit main port: the release reaches IOKit through the task's own port, and
// MACH_PORT_NULL is what every IOKit function of the release already reads as "the default", so that
// is what the call hands back and kIOMainPortDefault is (facts/IOKit/IORegistryPaths.md).
//
// A .c file of this package is compiled hidden, so what it must export says so itself, the way
// Foundation's CFBoolean constants do. A NULL out-parameter is answered rather than read through: the
// host reads through it and crashes.

#define CHARON_IOKIT_EXPORT __attribute__((visibility("default")))

CHARON_IOKIT_EXPORT const mach_port_t kIOMainPortDefault = MACH_PORT_NULL;

CHARON_IOKIT_EXPORT kern_return_t IOMainPort(mach_port_t bootstrapPort, mach_port_t *mainPort)
{
    if (mainPort == 0) {
        return KERN_INVALID_ARGUMENT;
    }
    *mainPort = kIOMainPortDefault;
    return KERN_SUCCESS;
}
