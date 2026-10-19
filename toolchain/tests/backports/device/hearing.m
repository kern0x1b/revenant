#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <dlfcn.h>

#import "check.h"

static void check_system(void *handle, const char *symbol)
{
    Dl_info info;
    if (!handle || !dlsym(handle, symbol) || !dladdr(dlsym(handle, symbol), &info) || !info.dli_fname)
        return;
    printf("hearing\tsystem has %s\tin %s\n", symbol, info.dli_fname);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_log_to(argc > 1 ? @(argv[1]) : nil);

        void *system = dlopen("/System/Library/Frameworks/Accessibility.framework/Accessibility", RTLD_LAZY);
        check_system(system, "AXMFiHearingDevicePairedUUIDs");
        check_system(system, "AXMFiHearingDeviceStreamingEar");
        check_system(system, "AXSupportsBidirectionalAXMFiHearingDeviceStreaming");

        NSArray<NSUUID *> *paired = AXMFiHearingDevicePairedUUIDs();
        CHECK(paired != nil, "the paired-device list is not nil, so a caller can iterate it");
        CHECK_EQUAL(@(paired.count), @(0),
                    "the paired-device list is empty, because the release holds no hearing hardware");

        AXHearingDeviceEar ear = AXMFiHearingDeviceStreamingEar();
        CHECK_EQUAL(@(ear), @(AXHearingDeviceEarNone),
                    "the streaming ear is the enumeration's own no-device case");

        CHECK_EQUAL(@(AXSupportsBidirectionalAXMFiHearingDeviceStreaming()), @(0),
                    "bidirectional streaming is not supported, because there is no hearing device");

        printf("hearing\tchecks run: %d, failed: %d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures == 0 ? 0 : 1;
}
