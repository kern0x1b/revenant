#include "../revenant_impl.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

#define REVENANT_IOKIT_EXPORT __attribute__((visibility("default")))

REVENANT_IOKIT_EXPORT const mach_port_t BACKPORT_IMPL(kIOMainPortDefault) = MACH_PORT_NULL;

REVENANT_IOKIT_EXPORT kern_return_t BACKPORT_IMPL(IOMainPort)(mach_port_t bootstrapPort, mach_port_t *mainPort)
{
    if (mainPort == 0) {
        return KERN_INVALID_ARGUMENT;
    }
    *mainPort = BACKPORT_IMPL(kIOMainPortDefault);
    return KERN_SUCCESS;
}
