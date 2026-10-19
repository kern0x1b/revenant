#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

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
