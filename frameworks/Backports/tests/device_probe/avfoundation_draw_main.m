#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

static const size_t kSide = 80;

typedef struct {
    OSType format;
    const char *name;
    uint8_t first;
    uint8_t second;
    uint8_t third;
    CGFloat x;
    CGFloat top;
    BOOL timed;
    BOOL h264;
} Block;

#include "avfoundation_draw_h264.inc"

static const Block kBlocks[] = {
    {kCVPixelFormatType_32BGRA, "32BGRA red", 0, 0, 255, 20, 80, NO},
    {kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, "420v green", 145, 54, 34, 120, 80, NO},
    {kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, "420f blue", 29, 255, 107, 220, 80, NO},
    {kCVPixelFormatType_32BGRA, "32BGRA red with a control timebase", 0, 0, 255, 120, 190, YES, NO},
    {0, "H.264 green (compressed control)", 0, 0, 0, 20, 190, NO, YES},
};

static CMSampleBufferRef h264_sample(void)
{
    NSData *avcc = [NSData dataWithBytes:kH264Avcc length:sizeof kH264Avcc];
    NSDictionary *extensions = @{(__bridge id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: @{@"avcC": avcc}};
    CMVideoFormatDescriptionRef description = NULL;
    if (CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264, kSide, kSide, (__bridge CFDictionaryRef)extensions, &description) != noErr)
        return NULL;
    CMBlockBufferRef block = NULL;
    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, sizeof kH264Frame, kCFAllocatorDefault, NULL, 0, sizeof kH264Frame, kCMBlockBufferAssureMemoryNowFlag, &block);
    CMBlockBufferReplaceDataBytes(kH264Frame, block, 0, sizeof kH264Frame);
    CMSampleBufferRef sample = NULL;
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeZero, kCMTimeInvalid};
    size_t size = sizeof kH264Frame;
    OSStatus status = CMSampleBufferCreate(kCFAllocatorDefault, block, true, NULL, NULL, description, 1, 1, &timing, 1, &size, &sample);
    printf("draw probe: H.264 sample status %d\n", (int)status);
    CFRelease(description);
    CFRelease(block);
    if (sample) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, true);
        if (attachments && CFArrayGetCount(attachments) > 0)
            CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0), kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    }
    return sample;
}

static CMSampleBufferRef sample_of(const Block *block)
{
    CVPixelBufferRef pixel = NULL;
    NSDictionary *attributes = @{(__bridge id)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    if (CVPixelBufferCreate(kCFAllocatorDefault, kSide, kSide, block->format, (__bridge CFDictionaryRef)attributes, &pixel) != kCVReturnSuccess)
        return NULL;
    CVPixelBufferLockBaseAddress(pixel, 0);
    if (CVPixelBufferIsPlanar(pixel)) {
        CVBufferSetAttachment(pixel, CFSTR("YCbCrMatrix"), CFSTR("ITU_R_601_4"), kCVAttachmentMode_ShouldPropagate);
        uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(pixel, 0);
        size_t lumaStride = CVPixelBufferGetBytesPerRowOfPlane(pixel, 0);
        for (size_t row = 0; row < CVPixelBufferGetHeightOfPlane(pixel, 0); row++)
            memset(luma + row * lumaStride, block->first, kSide);
        uint8_t *chroma = CVPixelBufferGetBaseAddressOfPlane(pixel, 1);
        size_t chromaStride = CVPixelBufferGetBytesPerRowOfPlane(pixel, 1);
        for (size_t row = 0; row < CVPixelBufferGetHeightOfPlane(pixel, 1); row++) {
            for (size_t column = 0; column < kSide / 2; column++) {
                chroma[row * chromaStride + column * 2] = block->second;
                chroma[row * chromaStride + column * 2 + 1] = block->third;
            }
        }
    } else {
        uint8_t *base = CVPixelBufferGetBaseAddress(pixel);
        size_t stride = CVPixelBufferGetBytesPerRow(pixel);
        for (size_t row = 0; row < kSide; row++) {
            for (size_t column = 0; column < kSide; column++) {
                uint8_t *at = base + row * stride + column * 4;
                at[0] = block->first;
                at[1] = block->second;
                at[2] = block->third;
                at[3] = 255;
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixel, 0);
    CMSampleBufferRef sample = NULL;
    CMVideoFormatDescriptionRef description = NULL;
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixel, &description) == noErr) {
        CMSampleTimingInfo timing = {kCMTimeInvalid, block->timed ? CMClockGetTime(CMClockGetHostTimeClock()) : kCMTimeZero, kCMTimeInvalid};
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel, true, NULL, NULL, description, &timing, &sample);
        CFRelease(description);
    }
    CVPixelBufferRelease(pixel);
    if (sample && !block->timed) {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, true);
        if (attachments && CFArrayGetCount(attachments) > 0)
            CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0), kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    }
    return sample;
}

@interface RevenantDrawProbe : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray *layers;
@end

@implementation RevenantDrawProbe

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor blackColor];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view.backgroundColor = [UIColor blackColor];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    UIView *control = [[UIView alloc] initWithFrame:CGRectMake(20, 300, kSide, kSide)];
    control.backgroundColor = [UIColor colorWithRed:1 green:0 blue:1 alpha:1];
    [controller.view addSubview:control];
    self.layers = [NSMutableArray array];
    for (size_t index = 0; index < sizeof kBlocks / sizeof kBlocks[0]; index++) {
        AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
        layer.frame = CGRectMake(kBlocks[index].x, kBlocks[index].top, kSide, kSide);
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        if (kBlocks[index].timed) {
            CMTimebaseRef timebase = NULL;
            CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &timebase);
            CMTimebaseSetTime(timebase, CMClockGetTime(CMClockGetHostTimeClock()));
            CMTimebaseSetRate(timebase, 1.0);
            layer.controlTimebase = timebase;
            CFRelease(timebase);
        }
        [controller.view.layer addSublayer:layer];
        [self.layers addObject:layer];
    }
    [self performSelector:@selector(enqueue) withObject:nil afterDelay:1.0];
    [self performSelector:@selector(enqueue) withObject:nil afterDelay:3.0];
    [self performSelector:@selector(finish) withObject:nil afterDelay:90.0];
    return YES;
}

- (void)enqueue
{
    for (size_t index = 0; index < sizeof kBlocks / sizeof kBlocks[0]; index++) {
        AVSampleBufferDisplayLayer *layer = self.layers[index];
        CMSampleBufferRef sample = kBlocks[index].h264 ? h264_sample() : sample_of(&kBlocks[index]);
        BOOL ready = layer.isReadyForMoreMediaData;
        if (sample) {
            [layer enqueueSampleBuffer:sample];
            CFRelease(sample);
        }
        printf("draw probe: %s sample %d ready before %d after %d\n", kBlocks[index].name, sample != NULL, ready, layer.isReadyForMoreMediaData);
    }
    fflush(stdout);
}

- (void)finish
{
    printf("draw probe: finished\n");
    fflush(stdout);
    exit(0);
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantDrawProbe class]));
    }
}
