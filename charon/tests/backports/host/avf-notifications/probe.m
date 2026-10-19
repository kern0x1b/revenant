//
//  probe.m
//  The notification names, user-info keys and option keys, read out of whichever build this is.
//
//  One program, linked twice by run.sh. Linked plain, every name is Apple's own exported symbol and
//  the table is the host's. Linked with the rename list and the port's four objects, the same names
//  are the port's definitions in the same binary, and the table is read out of them - so the harness
//  COMPILES the port's sources, LINKS them beside Apple's, and READS the port's object. That is the
//  point: a value that the port's object does not define cannot be read at all, which is a link
//  error and not a row that quietly reads as equal on both sides.
//
//  Two lines per name: the value as text, and the value as bytes. The bytes are not tidiness - a
//  value that is not valid UTF-8 answers NULL from -UTF8String and would print "(null)" on both sides
//  and pass, so the byte line is what makes "every one of these is printable ASCII and decodes byte
//  for byte to its printed text" a check rather than a claim.
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <stdio.h>

struct row { const char *name; NSString *const *value; };
static const struct row table[] = {
#include "table.inc"
};

// Four of the names are declared `AVCaptureDeviceType`, which the SDK marks
// API_UNAVAILABLE(macos) - so this host program cannot take their address at all, and a table built
// from `&name` does not compile here. They are reached by dlsym instead, and the PORT build must ask
// for the renamed symbol, because the port's object defines the real name and Apple's defines it
// too: two definitions of one name would collide at link time, which is what the rename list is for.
// CHARON_PORT_BUILD is defined only in the port's link, and the name is spelled as the concatenation
// the rename makes rather than through the macro, because -D does not reach inside a string literal.
// The label is the REAL name on both sides, so a row is comparable across the two builds: the
// symbol asked for carries this build's rename, and the name printed does not, or every one of these
// four rows would diff on the rename rather than on the value.
static const char *const unnameableLabels[] = {
    "AVCaptureDeviceTypeBuiltInDualWideCamera",
    "AVCaptureDeviceTypeBuiltInTripleCamera",
    "AVCaptureDeviceTypeBuiltInUltraWideCamera",
    "AVCaptureDeviceTypeBuiltInLiDARDepthCamera",
};

static const char *const unnameable[] = {
#ifdef CHARON_PORT_BUILD
    "charon_host_AVCaptureDeviceTypeBuiltInDualWideCamera",
    "charon_host_AVCaptureDeviceTypeBuiltInTripleCamera",
    "charon_host_AVCaptureDeviceTypeBuiltInUltraWideCamera",
    "charon_host_AVCaptureDeviceTypeBuiltInLiDARDepthCamera",
#else
    "AVCaptureDeviceTypeBuiltInDualWideCamera",
    "AVCaptureDeviceTypeBuiltInTripleCamera",
    "AVCaptureDeviceTypeBuiltInUltraWideCamera",
    "AVCaptureDeviceTypeBuiltInLiDARDepthCamera",
#endif
};

static void printOne(const char *name, NSString *value)
{
    const char *utf8 = value ? [value UTF8String] : NULL;
    printf("%-78s = %s\n", name, utf8 ? utf8 : "(null)");
    printf("%-78s   bytes:", name);
    if (!utf8) {
        printf(" (no UTF-8: the value is not valid UTF-8)");
    } else {
        for (const unsigned char *p = (const unsigned char *)utf8; *p; p++) {
            printf(" %02x", *p);
        }
    }
    printf("\n");
    fflush(stdout);
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        for (unsigned i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
            printOne(table[i].name, *table[i].value);
        }
        for (unsigned i = 0; i < sizeof(unnameable) / sizeof(unnameable[0]); i++) {
            void *sym = dlsym(RTLD_DEFAULT, unnameable[i]);
            printOne(unnameableLabels[i], sym ? *(NSString *const *)sym : nil);
        }
        printf("rows: %u\n", (unsigned)((sizeof(table) / sizeof(table[0]))
                                         + (sizeof(unnameable) / sizeof(unnameable[0]))));
        // The five "…Current" sentinels, read through a pointer typed for EACH one. They are the
        // corpus's `kind: constant` and they are not strings: four different types are declared for
        // them, and reading them as NSString *const segfaults - which is how they were found. The
        // white-balance gains is API_UNAVAILABLE(macos), so the host binary cannot name its type and
        // the two floats are read through a local struct of the same shape, which is what the port
        // defines with the SDK's own struct.
        {
            const CMTime *duration = (const CMTime *)dlsym(RTLD_DEFAULT, "AVCaptureExposureDurationCurrent");
            const float *iso = (const float *)dlsym(RTLD_DEFAULT, "AVCaptureISOCurrent");
            const float *bias = (const float *)dlsym(RTLD_DEFAULT, "AVCaptureExposureTargetBiasCurrent");
            const float *lens = (const float *)dlsym(RTLD_DEFAULT, "AVCaptureLensPositionCurrent");
            struct charon_wb_gains { float redGain; float blueGain; };
            const struct charon_wb_gains *gains =
                (const struct charon_wb_gains *)dlsym(RTLD_DEFAULT, "AVCaptureWhiteBalanceGainsCurrent");
            printf("%-78s = {value %lld, timescale %lld, flags %lld}\n", "AVCaptureExposureDurationCurrent",
                   duration ? (long long)duration->value : -999, duration ? (long long)duration->timescale : 0,
                   duration ? (long long)duration->flags : 0);
            printf("%-78s = %.9g\n", "AVCaptureISOCurrent", iso ? (double)*iso : -999.0);
            printf("%-78s = %.9g\n", "AVCaptureExposureTargetBiasCurrent", bias ? (double)*bias : -999.0);
            printf("%-78s = %.9g\n", "AVCaptureLensPositionCurrent", lens ? (double)*lens : -999.0);
            printf("%-78s = {redGain %.9g, blueGain %.9g}\n", "AVCaptureWhiteBalanceGainsCurrent",
                   gains ? (double)gains->redGain : -999.0, gains ? (double)gains->blueGain : -999.0);
        }
    }
    return 0;
}
