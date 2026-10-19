#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>

static void *lookup(const char *name)
{
    void *address = dlsym(RTLD_DEFAULT, name);
    if (address == NULL) {
        char underscored[512];
        snprintf(underscored, sizeof underscored, "_%s", name);
        address = dlsym(RTLD_DEFAULT, underscored);
    }
    return address;
}

int main(void)
{
    @autoreleasepool {
        if (dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
                   RTLD_LAZY | RTLD_GLOBAL) == NULL) {
            fprintf(stderr, "FAIL: AVFoundation did not load\n");
            return 1;
        }
        printf("CONTROL\tAVCaptionNoSuchConstructor\t%s\n",
               lookup("AVCaptionNoSuchConstructor") ? "HAS" : "LACKS");
        Class caption = objc_getClass("AVCaption");
        if (caption == nil) {
            fprintf(stderr, "FAIL: AVCaption does not resolve, so AVFoundation was not really loaded\n");
            return 1;
        }
        printf("CONTROL\tAVCaption\tHAS %p\n", (__bridge void *)caption);

        void *hostMake = lookup("AVCaptionDimensionMake");
        void *portMake = lookup("charon_host_AVCaptionDimensionMake");
        void *hostPoint = lookup("AVCaptionPointMake");
        void *portPoint = lookup("charon_host_AVCaptionPointMake");
        void *hostSize = lookup("AVCaptionSizeMake");
        void *portSize = lookup("charon_host_AVCaptionSizeMake");
        void *hostImage = lookup("AVCaptureReactionSystemImageNameForType");
        void *portImage = lookup("charon_host_AVCaptureReactionSystemImageNameForType");

        AVCaptionDimension (*make)(CGFloat, AVCaptionUnitsType) =
            (AVCaptionDimension (*)(CGFloat, AVCaptionUnitsType))hostMake;
        AVCaptionDimension (*portDimension)(CGFloat, AVCaptionUnitsType) =
            (AVCaptionDimension (*)(CGFloat, AVCaptionUnitsType))portMake;
        double values[] = {0.0, 1.0, 42.5, 100.0, -3.25};
        for (long u = 0; u < 3; u++) {
            for (size_t v = 0; v < sizeof values / sizeof values[0]; v++) {
                if (v == 0 && u == 2) {
                    printf("CONTROL\tAVCaptionDimensionMake(0,Percent)\t%g/%ld %g/%ld\n",
                           portDimension(0.0, u).value, portDimension(0.0, u).units,
                           make(0.0, u).value, make(0.0, u).units);
                }
                AVCaptionDimension h = make((CGFloat)values[v], (AVCaptionUnitsType)u);
                AVCaptionDimension p = portDimension((CGFloat)values[v], (AVCaptionUnitsType)u);
                printf("AVCaptionDimensionMake(%g,%ld)\thost=%g/%ld\tport=%g/%ld\t%s\n",
                       values[v], u, h.value, h.units, p.value, p.units,
                       (h.value == p.value && h.units == p.units) ? "same" : "DIFFERENT");
            }
        }
        AVCaptionPoint (*point)(AVCaptionDimension, AVCaptionDimension) =
            (AVCaptionPoint (*)(AVCaptionDimension, AVCaptionDimension))hostPoint;
        AVCaptionPoint (*portMakePoint)(AVCaptionDimension, AVCaptionDimension) =
            (AVCaptionPoint (*)(AVCaptionDimension, AVCaptionDimension))portPoint;
        AVCaptionSize (*size)(AVCaptionDimension, AVCaptionDimension) =
            (AVCaptionSize (*)(AVCaptionDimension, AVCaptionDimension))hostSize;
        AVCaptionSize (*portMakeSize)(AVCaptionDimension, AVCaptionDimension) =
            (AVCaptionSize (*)(AVCaptionDimension, AVCaptionDimension))portSize;
        for (long u = 0; u < 3; u++) {
            AVCaptionDimension a = {1.5, (AVCaptionUnitsType)u};
            AVCaptionDimension b = {2.25, (AVCaptionUnitsType)(u == 0 ? 2 : 0)};
            AVCaptionPoint hp = point(a, b), pp = portMakePoint(a, b);
            printf("AVCaptionPointMake(%g,%ld,%g,%ld)\thost=%g/%ld,%g/%ld\tport=%g/%ld,%g/%ld\t%s\n",
                   a.value, a.units, b.value, b.units,
                   hp.x.value, hp.x.units, hp.y.value, hp.y.units,
                   pp.x.value, pp.x.units, pp.y.value, pp.y.units,
                   (hp.x.value == pp.x.value && hp.x.units == pp.x.units &&
                    hp.y.value == pp.y.value && hp.y.units == pp.y.units) ? "same" : "DIFFERENT");
            AVCaptionSize hs = size(a, b), ps = portMakeSize(a, b);
            printf("AVCaptionSizeMake(%g,%ld,%g,%ld)\thost=%g/%ld,%g/%ld\tport=%g/%ld,%g/%ld\t%s\n",
                   a.value, a.units, b.value, b.units,
                   hs.width.value, hs.width.units, hs.height.value, hs.height.units,
                   ps.width.value, ps.width.units, ps.height.value, ps.height.units,
                   (hs.width.value == ps.width.value && hs.width.units == ps.width.units &&
                    hs.height.value == ps.height.value && hs.height.units == ps.height.units)
                   ? "same" : "DIFFERENT");
        }

        NSString *(*image)(NSString *) = (NSString *(*)(NSString *))hostImage;
        NSString *(*portLookup)(NSString *) = (NSString *(*)(NSString *))portImage;
        const char *reactions[] = {"AVCaptureReactionTypeBalloons", "AVCaptureReactionTypeConfetti",
                                   "AVCaptureReactionTypeFireworks", "AVCaptureReactionTypeHeart",
                                   "AVCaptureReactionTypeLasers", "AVCaptureReactionTypeRain",
                                   "AVCaptureReactionTypeThumbsUp", "AVCaptureReactionTypeThumbsDown"};
        for (size_t i = 0; i < sizeof reactions / sizeof reactions[0]; i++) {
            void *type = lookup(reactions[i]);
            if (type == NULL) {
                printf("%s\tABSENT on the host\n", reactions[i]);
                continue;
            }
            NSString *kind = (__bridge NSString *)(*(void **)type);
            printf("%s\thost=[%s]\tport=[%s]\n", reactions[i], [image(kind) UTF8String],
                   [portLookup(kind) UTF8String]);
        }
        printf("PLANTED-TYPE\timage host=[%s] port=[%s]\n",
               [image(@"ReactionNoSuchType") UTF8String],
               [portLookup(@"ReactionNoSuchType") UTF8String]);
    }
    return 0;
}
