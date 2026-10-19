#import <AVFoundation/AVFoundation.h>

@interface AVCaptureDeviceFormat (RevenantBinnedDictionary)
- (BOOL)isBinned;
@end

@implementation AVCaptureDeviceFormat (RevenantBinnedVideo)

- (BOOL)isVideoBinned
{
    return [self isBinned];
}

@end
