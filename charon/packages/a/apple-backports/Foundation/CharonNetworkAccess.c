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
