//
//  hearing.m
//  Accessibility's three hearing-device functions, on a release.
//
//  The three answers AXMFiHearingDevicePairedUUIDs, AXMFiHearingDeviceStreamingEar and
//  AXSupportsBidirectionalAXMFiHearingDeviceStreaming are HELD NOT BY RUN everywhere else in this tree,
//  and this file is why that is a temporary state rather than a permanent one.
//
//  They cannot be run on a host. Their declarations are API_UNAVAILABLE(macos) - the header's own
//  statement that a Mac has no such device - so no macOS program can call them at all, and the answer a
//  host would give is the signed-in user's own accessory list, which is nobody's answer to what a phone
//  with no hearing hardware must say. On this machine there is no iOS runtime either:
//  `xcrun --show-sdk-path --sdk iphonesimulator` answers `SDK "iphonesimulator" cannot be located`. So
//  what the port's side holds them with, on every branch, is three things that are not a run:
//
//    * tests/backports/settings/hearing-check.m, compiled for armv7-apple-ios6.0 against the SDK's own
//      declarations, which holds the compiler to the three signatures;
//    * an assertion over `nm` of the built CharonHearing15.o, which the settings run makes and mutant
//      M9 turns red on - it is an assertion and not a print, so a port that stopped defining one of the
//      three fails the run;
//    * tests/backports/settings/axs-census.lua, the measurement the answers are readings of. It prints
//      28 hearing-named exports in the release's Accessibility surface and every one is a preference
//      about a hearing-aid feature - four of them about a paired-UUIDs preference - and none of the 28
//      is an AXMFiHearingDevice symbol. That is the whole justification: the three functions are about
//      hearing devices made as phone accessories, and the release carries no API for one.
//
//  This program is the one that can run them, and the gate is what runs it. It asks the port's three
//  functions what the census says they must answer, and it also asks the release's own - the functions
//  are exported by the system's Accessibility framework on every release that has hearing devices, so
//  where the release has them the two must agree, and where it does not, the release's own answer is
//  the interesting one and is printed rather than asserted.
//
//  Every expectation here is a reading of the census, and the census is the measurement; a check that
//  disagreed with the system would be a finding about the census, not a failure of the port, so the two
//  are printed side by side and only the port's three answers are asserted.
//

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
        charon_log_to(argc > 1 ? @(argv[1]) : nil);

        // The release's own answers, where it has the functions at all. Printed and not asserted: a
        // release with hearing devices would answer something else, and that is a fact about the
        // release rather than a disagreement with the port.
        void *system = dlopen("/System/Library/Frameworks/Accessibility.framework/Accessibility", RTLD_LAZY);
        check_system(system, "AXMFiHearingDevicePairedUUIDs");
        check_system(system, "AXMFiHearingDeviceStreamingEar");
        check_system(system, "AXSupportsBidirectionalAXMFiHearingDeviceStreaming");

        // The port's three, against the census: no hearing hardware, so no paired device, the
        // enumeration's own no-device case for the ear, and no bidirectional streaming because there is
        // no hearing device to stream in either direction.
        NSArray<NSUUID *> *paired = AXMFiHearingDevicePairedUUIDs();
        CHECK(paired != nil, "the paired-device list is not nil, so a caller can iterate it");
        CHECK_EQUAL(@(paired.count), @(0),
                    "the paired-device list is empty, because the release holds no hearing hardware");

        AXHearingDeviceEar ear = AXMFiHearingDeviceStreamingEar();
        CHECK_EQUAL(@(ear), @(AXHearingDeviceEarNone),
                    "the streaming ear is the enumeration's own no-device case");

        CHECK_EQUAL(@(AXSupportsBidirectionalAXMFiHearingDeviceStreaming()), @(0),
                    "bidirectional streaming is not supported, because there is no hearing device");

        printf("hearing\tchecks run: %d, failed: %d\n", charon_checks, charon_failures);
    }
    return charon_failures == 0 ? 0 : 1;
}
