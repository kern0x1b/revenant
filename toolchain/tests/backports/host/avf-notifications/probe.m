#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <stdio.h>

struct row { const char *name; NSString *const *value; };
static const struct row table[] = {
#include "table.inc"
};

static const char *const unnameableLabels[] = {
    "AVCaptureDeviceTypeBuiltInDualWideCamera",
    "AVCaptureDeviceTypeBuiltInTripleCamera",
    "AVCaptureDeviceTypeBuiltInUltraWideCamera",
    "AVCaptureDeviceTypeBuiltInLiDARDepthCamera",
};

static const char *const unnameable[] = {
#ifdef REVENANT_PORT_BUILD
    "revenant_host_AVCaptureDeviceTypeBuiltInDualWideCamera",
    "revenant_host_AVCaptureDeviceTypeBuiltInTripleCamera",
    "revenant_host_AVCaptureDeviceTypeBuiltInUltraWideCamera",
    "revenant_host_AVCaptureDeviceTypeBuiltInLiDARDepthCamera",
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
        {
            const CMTime *duration = (const CMTime *)dlsym(RTLD_DEFAULT, "AVCaptureExposureDurationCurrent");
            const float *iso = (const float *)dlsym(RTLD_DEFAULT, "AVCaptureISOCurrent");
            const float *bias = (const float *)dlsym(RTLD_DEFAULT, "AVCaptureExposureTargetBiasCurrent");
            const float *lens = (const float *)dlsym(RTLD_DEFAULT, "AVCaptureLensPositionCurrent");
            struct revenant_wb_gains { float redGain; float blueGain; };
            const struct revenant_wb_gains *gains =
                (const struct revenant_wb_gains *)dlsym(RTLD_DEFAULT, "AVCaptureWhiteBalanceGainsCurrent");
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
