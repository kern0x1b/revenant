#import "../app/revenant_check.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const kSystemImage = @"/System/Library/Frameworks/AVFoundation.framework/AVFoundation";
static NSString *const kBackportImage = @"/usr/lib/revenant/org.revenant.backports/libAVFoundationBackports.dylib";

static BOOL image_defines(NSString *image, const char *name)
{
    unsigned int count = 0;
    const char **names = objc_copyClassNamesForImage([image UTF8String], &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index++)
        found = found || strcmp(names[index], name) == 0;
    free(names);
    return found;
}

static NSString *join_sorted(NSMutableArray<NSString *> *items)
{
    [items sortUsingSelector:@selector(compare:)];
    return [items componentsJoinedByString:@" "];
}

static NSString *instance_methods(Class cls)
{
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned int index = 0; index < count; index++)
        [names addObject:NSStringFromSelector(method_getName(methods[index]))];
    free(methods);
    return join_sorted(names);
}

static NSString *instance_variables(Class cls)
{
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned int index = 0; index < count; index++)
        [names addObject:[NSString stringWithFormat:@"%s@%td", ivar_getName(ivars[index]), ivar_getOffset(ivars[index])]];
    free(ivars);
    return join_sorted(names);
}

static void describe(const char *label, Class cls)
{
    if (!cls) {
        printf("display layer fact: %s class none\n", label);
        return;
    }
    printf("display layer fact: %s class image %s superclass %s instance size %zu\n", label, class_getImageName(cls) ?: "none",
           class_getName(class_getSuperclass(cls)), class_getInstanceSize(cls));
    printf("display layer fact: %s ivars %s\n", label, [instance_variables(cls) UTF8String]);
    printf("display layer fact: %s methods %s\n", label, [instance_methods(cls) UTF8String]);
}

static CMSampleBufferRef sample_of(OSType format)
{
    CVPixelBufferRef pixel = NULL;
    NSDictionary *attributes = @{@"IOSurfaceProperties": @{}};
    if (CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, format, (__bridge CFDictionaryRef)attributes, &pixel) != kCVReturnSuccess || !pixel)
        return NULL;
    CVPixelBufferLockBaseAddress(pixel, 0);
    if (CVPixelBufferIsPlanar(pixel)) {
        for (size_t plane = 0; plane < CVPixelBufferGetPlaneCount(pixel); plane++)
            memset(CVPixelBufferGetBaseAddressOfPlane(pixel, plane), 0x80, CVPixelBufferGetBytesPerRowOfPlane(pixel, plane) * CVPixelBufferGetHeightOfPlane(pixel, plane));
    } else {
        memset(CVPixelBufferGetBaseAddress(pixel), 0x80, CVPixelBufferGetDataSize(pixel));
    }
    CVPixelBufferUnlockBaseAddress(pixel, 0);
    CMSampleBufferRef sample = NULL;
    CMVideoFormatDescriptionRef description = NULL;
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixel, &description) == noErr) {
        CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeZero, kCMTimeInvalid};
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel, true, NULL, NULL, description, &timing, &sample);
        CFRelease(description);
    }
    CVPixelBufferRelease(pixel);
    if (sample) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, true);
        if (attachments && CFArrayGetCount(attachments) > 0)
            CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0), kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    }
    return sample;
}

static NSUInteger layers_with_contents(CALayer *layer)
{
    NSUInteger found = layer.contents ? 1 : 0;
    for (CALayer *child in layer.sublayers)
        found += layers_with_contents(child);
    return found;
}

static void spin(void)
{
    for (int index = 0; index < 60; index++) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }
}

static void render(const char *label, Class cls, OSType format, const char *formatName)
{
    @autoreleasepool {
        CALayer *layer = cls ? [[cls alloc] init] : nil;
        if (!layer) {
            printf("display layer fact: %s %s no instance\n", label, formatName);
            return;
        }
        layer.frame = CGRectMake(0, 0, 64, 64);
        CMSampleBufferRef sample = sample_of(format);
        if (!sample) {
            printf("display layer fact: %s %s no sample buffer\n", label, formatName);
            return;
        }
        BOOL readyBefore = [(AVSampleBufferDisplayLayer *)layer isReadyForMoreMediaData];
        [(AVSampleBufferDisplayLayer *)layer enqueueSampleBuffer:sample];
        CFRelease(sample);
        spin();
        id status = [layer respondsToSelector:@selector(status)] ? @((long long)[(AVSampleBufferDisplayLayer *)layer status]) : @"unanswered";
        printf("display layer fact: %s %s ready before %d after %d, layers with contents %lu, status %s\n", label, formatName,
               readyBefore, [(AVSampleBufferDisplayLayer *)layer isReadyForMoreMediaData], (unsigned long)layers_with_contents(layer),
               [[status description] UTF8String]);
        [(AVSampleBufferDisplayLayer *)layer flushAndRemoveImage];
    }
}

REVENANT_CASE(avfoundation_system_display_layer)
{
    BOOL flip = (BOOL)negative;
    const char *name = "AVSampleBufferDisplayLayer";
    Class named = objc_getClass(name);
    Class system = revenant_backport_class("AVFoundation", name);
    BOOL backportDefines = image_defines(kBackportImage, name);
    BOOL systemDefines = image_defines(kSystemImage, name);
    printf("display layer fact: system image defines it %d, backport image defines it %d, registered by name %lu\n",
           systemDefines, backportDefines, (unsigned long)revenant_registered_count(name));
    describe("named", named);
    if (system != named)
        describe("exported by the backports", system);

    render("named", named, kCVPixelFormatType_32BGRA, "32BGRA");
    render("named", named, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, "420v");
    render("named", named, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, "420f");

    NSString *image = named ? [NSString stringWithUTF8String:class_getImageName(named) ?: ""] : @"";
    revenant_expect_true(@"the Backports image defines no class named AVSampleBufferDisplayLayer", !backportDefines != flip,
                         @"libAVFoundationBackports carries a second class with the system's name");
    revenant_expect_true(@"the class that objc_getClass names comes from the system's AVFoundation",
                         [image isEqualToString:kSystemImage] != flip, image);

    const char *members[] = {"status", "error", "isReadyForDisplay", "requiresFlushToResumeDecoding", "outputObscuredDueToInsufficientExternalProtection",
                             "preventsCapture", "setPreventsCapture:", "preventsDisplaySleepDuringVideoPlayback", "setPreventsDisplaySleepDuringVideoPlayback:",
                             "sampleBufferRenderer", "hasSufficientMediaDataForReliablePlaybackStart", "isReadyForMoreMediaData", "controlTimebase",
                             "setControlTimebase:", "videoGravity", "setVideoGravity:", "enqueueSampleBuffer:", "flush", "flushAndRemoveImage",
                             "requestMediaDataWhenReadyOnQueue:usingBlock:", "stopRequestingMediaData"};
    NSMutableArray *missing = [NSMutableArray array];
    for (size_t index = 0; index < sizeof members / sizeof members[0]; index++) {
        if (!class_getInstanceMethod(named, sel_registerName(members[index])))
            [missing addObject:[NSString stringWithUTF8String:members[index]]];
    }
    revenant_expect_true(@"the class that objc_getClass names answers every member of the SDK's AVSampleBufferDisplayLayer",
                         (missing.count == 0) != flip, [missing componentsJoinedByString:@" "]);
    fflush(stdout);
}
