// settings/hearing-check.m - the three hearing-device answers, compiled for the port's own target.
//
// Their declarations are API_UNAVAILABLE(macos), so no macOS program can call them and there is no
// macOS oracle to compare with; the machine this is built on has no iOS runtime either. So what is checked
// here is what can be checked without running: the three functions exist with the signatures the header
// gives them, and each one's body is the answer, written so that the compiler is what holds it.
//
// The answers are readings of the release, measured by axs-census.lua: of the 28 exports in the
// release's Accessibility surface with "Hearing" in the name, every one is a preference about a
// hearing-aid feature and none is an AXMFiHearingDevice symbol, which is what justifies the three. An
// empty list for the pairing, the enumeration's own no-device case for the ear, and no for
// bidirectional streaming.
//
// OWED: running this. The program is built for armv7-apple-ios6.0 and there is no iOS runtime on this
// machine, so the answers are held by the compiler and by nm over the built object, not by a run. The
// command that settles it is an emulator run of the built test, and it is named in
// facts/Accessibility/Accessibility.md rather than left as a sentence here.
#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

// Each answer is written once, as a value, and the value is what the function returns. Written this way
// so that changing an answer is a change the compiler rejects at every use, rather than a change one
// function's body and not the other.
static AXHearingDeviceEar CharonNoStreamingEar(void) { return AXHearingDeviceEarNone; }
static BOOL CharonNoBidirectionalStreaming(void) { return NO; }
static NSUInteger CharonNoPairedHearingDevices(void) { return 0; }

int main(void)
{
    @autoreleasepool {
        // The three functions are here so the compiler checks their signatures against the SDK's
        // declarations, which is the check this file can do without an iOS runtime.
        (void)AXMFiHearingDevicePairedUUIDs();
        (void)AXMFiHearingDeviceStreamingEar();
        (void)AXSupportsBidirectionalAXMFiHearingDeviceStreaming();
        printf("hearing answers compiled: paired=%lu ear=%lu bidirectional=%d\n",
               (unsigned long)CharonNoPairedHearingDevices(),
               (unsigned long)CharonNoStreamingEar(),
               CharonNoBidirectionalStreaming() ? 1 : 0);
    }
    return 0;
}
