#import "RevenantAVCapture.h"

@implementation AVCaptureMultiCamSession

+ (BOOL)isMultiCamSupported
{
    return NO;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"AVCaptureMultiCamSession needs several cameras running at once, which iOS 6 and this device do not have; check +isMultiCamSupported first"];
    return nil;
}

@end
