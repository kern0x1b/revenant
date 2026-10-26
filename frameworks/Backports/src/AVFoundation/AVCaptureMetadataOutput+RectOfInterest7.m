#import <AVFoundation/AVFoundation.h>

static const CGRect revenant_whole_frame = {{0, 0}, {1, 1}};

@implementation AVCaptureMetadataOutput (RevenantRectOfInterest)

- (CGRect)rectOfInterest
{
    return revenant_whole_frame;
}

- (void)setRectOfInterest:(CGRect)rectOfInterest
{
    if (CGRectEqualToRect(rectOfInterest, revenant_whole_frame))
        return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"AVCaptureMetadataOutput.rectOfInterest is not applied on iOS 6: the release has no rectOfInterest and analyses the whole frame");
    });
}

@end
