#import <AVFoundation/AVFoundation.h>

@interface AVCaptureDeviceFormat (CharonBinnedDictionary)
- (BOOL)isBinned;
@end

@implementation AVCaptureDeviceFormat (CharonBinnedVideo)

- (BOOL)isVideoBinned
{
    return [self isBinned];
}

@end
