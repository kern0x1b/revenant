#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>
#import <dlfcn.h>
#import <objc/runtime.h>

static const uint8_t h264_sps[11] = {0x27, 0x42, 0x00, 0x1e, 0xab, 0x41, 0x86, 0xf0, 0x20, 0xc2, 0x28};
static const uint8_t h264_pps[4] = {0x28, 0xce, 0x3c, 0x80};

typedef OSStatus (*VTCreateFunction)(CFAllocatorRef, CMVideoFormatDescriptionRef, CFDictionaryRef, CFDictionaryRef, const VTDecompressionOutputCallbackRecord *, VTDecompressionSessionRef *);
typedef void (*VTInvalidateFunction)(VTDecompressionSessionRef);

static void ignore_output(void *refcon, void *frame, OSStatus status, VTDecodeInfoFlags flags, CVImageBufferRef image, CMTime pts, CMTime duration)
{
}

static CMVideoFormatDescriptionRef h264_format(void)
{
    NSMutableData *avcc = [NSMutableData data];
    const uint8_t head[6] = {1, h264_sps[1], h264_sps[2], h264_sps[3], 0xff, 0xe1};
    [avcc appendBytes:head length:sizeof head];
    const uint8_t sps_size[2] = {0, sizeof h264_sps};
    [avcc appendBytes:sps_size length:2];
    [avcc appendBytes:h264_sps length:sizeof h264_sps];
    const uint8_t pps_head[3] = {1, 0, sizeof h264_pps};
    [avcc appendBytes:pps_head length:3];
    [avcc appendBytes:h264_pps length:sizeof h264_pps];
    NSDictionary *extensions = @{(__bridge id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: @{@"avcC": avcc}};
    CMVideoFormatDescriptionRef format = NULL;
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264, 64, 64, (__bridge CFDictionaryRef)extensions, &format);
    return format;
}

static NSString *class_of(VTDecompressionSessionRef session)
{
    return session ? NSStringFromClass(object_getClass((__bridge id)session)) : @"none";
}

REVENANT_CASE(backport_impl_video_toolbox_h264)
{
    BOOL flip = (BOOL)negative;
    CMVideoFormatDescriptionRef format = h264_format();
    printf("h264 fact: format %s\n", format ? "made" : "not made");

    void *videoToolbox = dlopen("/System/Library/PrivateFrameworks/VideoToolbox.framework/VideoToolbox", RTLD_NOW);
    if (!videoToolbox)
        videoToolbox = dlopen("/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox", RTLD_NOW);
    VTCreateFunction systemCreate = (VTCreateFunction)dlsym(videoToolbox, "VTDecompressionSessionCreate");
    VTInvalidateFunction systemInvalidate = (VTInvalidateFunction)dlsym(videoToolbox, "VTDecompressionSessionInvalidate");
    VTDecompressionOutputCallbackRecord record = {ignore_output, NULL};

    VTDecompressionSessionRef systemSession = NULL;
    OSStatus systemStatus = format && systemCreate ? systemCreate(kCFAllocatorDefault, format, NULL, NULL, &record, &systemSession) : -1;
    printf("h264 fact: system create status %d session %d class %s\n", (int)systemStatus, systemSession != NULL, [class_of(systemSession) UTF8String]);
    VTDecompressionSessionRef session = NULL;
    OSStatus appStatus = format ? VTDecompressionSessionCreate(kCFAllocatorDefault, format, NULL, NULL, &record, &session) : -1;
    NSString *appClass = class_of(session);
    printf("h264 fact: app create status %d session %d class %s\n", (int)appStatus, session != NULL, [appClass UTF8String]);

    revenant_expect_true(@"an H.264 format description is made", (format != NULL) != flip, @"none");
    revenant_expect_true(@"the app's VTDecompressionSessionCreate answers for H.264 what the system answers",
                         (appStatus == systemStatus) != flip,
                         [NSString stringWithFormat:@"app %d, system %d", (int)appStatus, (int)systemStatus]);
    revenant_expect_true(@"an H.264 session is never the software decoder's",
                         ![appClass hasPrefix:@"Revenant"] != flip, appClass);
    revenant_expect_true(@"an H.264 session exists when the system made one",
                         (systemSession == NULL || session != NULL) != flip, @"the system made a session and the app did not");

    if (session && systemInvalidate)
        systemInvalidate(session);
    if (session)
        CFRelease(session);
    if (systemSession && systemInvalidate)
        systemInvalidate(systemSession);
    if (systemSession)
        CFRelease(systemSession);
    if (format)
        CFRelease(format);
    fflush(stdout);
}
