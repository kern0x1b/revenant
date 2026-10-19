/* The port's own answer to "is the link under us a cellular one".

   Two backport files ask: the network gate, which stops a request when a cellular link may not carry
   it, and the session's own metrics, which is where an application reads isCellular. A C function
   shared between backport files belongs in a file that exports no API symbol of its own -- defining
   it beside an @implementation is the trap charon/AGENTS.md names -- so it is here, in plain C with
   no Objective-C in it at all, and the two callers include CharonNetworkAccess.h.

   The answer is the port's own rather than the release's because iOS 6.1.3 has no API that reports
   it: the flags come from SystemConfiguration, reached by name, and the reference is the zero
   address, which is what "the default route" means and is what a device with no cellular radio
   answers. `charon_network_cellular_override` is the test seam the gate sets to pin the answer. */

#include <dlfcn.h>
#include <netinet/in.h>
#include <stdbool.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>

int charon_network_cellular_override = -1;

bool charon_network_cellular(void)
{
    if (charon_network_cellular_override >= 0)
        return charon_network_cellular_override != 0;
    static void *(*create)(void *, const struct sockaddr *);
    static bool (*flags)(void *, uint32_t *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_LAZY);
        if (!handle)
            return;
        create = dlsym(handle, "SCNetworkReachabilityCreateWithAddress");
        flags = dlsym(handle, "SCNetworkReachabilityGetFlags");
    });
    if (!create || !flags)
        return false;
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    void *reference = create(NULL, (const struct sockaddr *)&address);
    if (!reference)
        return false;
    uint32_t bits = 0;
    bool known = flags(reference, &bits);
    CFRelease(reference);
    return known && (bits & 0x00040000) != 0;
}
