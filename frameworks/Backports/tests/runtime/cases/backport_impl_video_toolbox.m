#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>
#import <dlfcn.h>

static const uint8_t hevc_vps[24] = {
    0x40, 0x01, 0x0c, 0x01, 0xff, 0xff, 0x01, 0x60, 0x00, 0x00, 0x03, 0x00,
    0x90, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x1e, 0x95, 0x98, 0x09
};
static const uint8_t hevc_sps[44] = {
    0x42, 0x01, 0x01, 0x01, 0x60, 0x00, 0x00, 0x03, 0x00, 0x90, 0x00, 0x00,
    0x03, 0x00, 0x00, 0x03, 0x00, 0x1e, 0xa0, 0x10, 0x20, 0x61, 0x65, 0x95,
    0x9a, 0x49, 0x32, 0xbc, 0x05, 0xb8, 0x08, 0x08, 0x0d, 0xb0, 0x80, 0x00,
    0x00, 0x03, 0x00, 0x80, 0x00, 0x00, 0x0c, 0x84
};
static const uint8_t hevc_pps[7] = {0x44, 0x01, 0xc1, 0x72, 0xb4, 0x22, 0x40};

typedef OSStatus (*VTCreateFunction)(CFAllocatorRef, CMVideoFormatDescriptionRef, CFDictionaryRef, CFDictionaryRef, const VTDecompressionOutputCallbackRecord *, VTDecompressionSessionRef *);

static void ignore_output(void *refcon, void *frame, OSStatus status, VTDecodeInfoFlags flags, CVImageBufferRef image, CMTime pts, CMTime duration)
{
}

static NSString *image_of(const char *symbol)
{
    Dl_info where;
    memset(&where, 0, sizeof where);
    dladdr(dlsym(RTLD_DEFAULT, symbol), &where);
    return where.dli_fname ? [[NSString stringWithUTF8String:where.dli_fname] lastPathComponent] : @"none";
}

REVENANT_CASE(backport_impl_video_toolbox)
{
    BOOL flip = (BOOL)negative;
    const char *names[] = {
        "VTDecompressionSessionCreate", "VTDecompressionSessionDecodeFrame", "VTDecompressionSessionInvalidate",
        "VTDecompressionSessionCanAcceptFormatDescription", "VTSessionSetProperty", "VTSessionCopyProperty",
    };
    for (size_t index = 0; index < sizeof names / sizeof names[0]; index++)
        printf("video toolbox fact: %s image %s\n", names[index], [image_of(names[index]) UTF8String]);

    const uint8_t *sets[3] = {hevc_vps, hevc_sps, hevc_pps};
    size_t sizes[3] = {sizeof hevc_vps, sizeof hevc_sps, sizeof hevc_pps};
    CMVideoFormatDescriptionRef format = NULL;
    OSStatus described = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault, 3, sets, sizes, 4, NULL, &format);
    printf("video toolbox fact: HEVC format description status %d\n", (int)described);

    void *videoToolbox = dlopen("/System/Library/PrivateFrameworks/VideoToolbox.framework/VideoToolbox", RTLD_NOW);
    if (!videoToolbox)
        videoToolbox = dlopen("/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox", RTLD_NOW);
    VTCreateFunction systemCreate = (VTCreateFunction)dlsym(videoToolbox, "VTDecompressionSessionCreate");
    VTDecompressionOutputCallbackRecord record = {ignore_output, NULL};
    if (format && systemCreate) {
        VTDecompressionSessionRef systemSession = NULL;
        OSStatus status = systemCreate(kCFAllocatorDefault, format, NULL, NULL, &record, &systemSession);
        printf("video toolbox fact: system VTDecompressionSessionCreate for HEVC status %d session %d\n", (int)status, systemSession != NULL);
    } else {
        printf("video toolbox fact: the system has no VTDecompressionSessionCreate\n");
    }
    VTDecompressionSessionRef session = NULL;
    OSStatus created = format ? VTDecompressionSessionCreate(kCFAllocatorDefault, format, NULL, NULL, &record, &session) : -1;
    printf("video toolbox fact: app VTDecompressionSessionCreate for HEVC status %d session %d\n", (int)created, session != NULL);
    Boolean accepts = session && format ? VTDecompressionSessionCanAcceptFormatDescription(session, format) : false;
    revenant_expect_true(@"an HEVC format description is made", (described == noErr && format != NULL) != flip,
                         [NSString stringWithFormat:@"status %d", (int)described]);
    revenant_expect_true(@"VTDecompressionSessionCreate makes a session for HEVC",
                         (created == noErr && session != NULL) != flip, [NSString stringWithFormat:@"status %d", (int)created]);
    revenant_expect_true(@"the HEVC session accepts its own format description", accepts != flip, @"it did not");
    if (session) {
        VTDecompressionSessionInvalidate(session);
        CFRelease(session);
    }
    if (format)
        CFRelease(format);
    fflush(stdout);
}
