// Counts the metadata the port emits for SRSensorReaderDelegate.
//
// It links the SAME translation unit the build generates from the registry row -
// SensorKitBackportsProtocols14.0.m, the file modules/apple/backports.lua writes from an implemented
// protocol row - and prints what that object put in the image. Nothing of Apple's is linked, so what is
// counted is the port's own metadata and not the host framework's, which matters because the host's
// SensorKit declares the same protocol with the same ten methods: linked here, it would answer 10/0 for
// the wrong reason.
//
// Two things this probe gets right that the first version of it did not, and both are recorded because
// either one makes the probe print a confident wrong answer:
//
//   1. the generated object is compiled as the build compiles it - armv7 or macOS, whatever the flags say -
//      rather than a hand-written stand-in, so a header that compiles here is the header that compiles
//      there;
//   2. the function that takes @protocol() is CALLED and its Protocol * is printed. A `static` function
//      main never calls is dead-stripped, and the probe then reports the protocol ABSENT for a port that
//      emits it perfectly well.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>

// What backports.lua writes for this library and this release.
void charon_SensorKitBackports_protocols(void);

static unsigned descriptions(Protocol *protocol, BOOL required)
{
    unsigned count = 0;
    protocol_copyMethodDescriptionList(protocol, required, YES, &count);
    return count;
}

int main(void)
{
    charon_SensorKitBackports_protocols();
    Protocol *protocol = objc_getProtocol("SRSensorReaderDelegate");
    printf("the PORT's emitted protocol: %s, %u optional, %u required\n",
           protocol ? "found" : "ABSENT",
           protocol ? descriptions(protocol, NO) : 0u,
           protocol ? descriptions(protocol, YES) : 0u);
    return 0;
}