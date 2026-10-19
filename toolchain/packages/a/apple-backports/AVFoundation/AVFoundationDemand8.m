#import "CharonAVCapture.h"
#import <objc/runtime.h>

@interface AVCaptureDevice (CharonPrivateExposure8)
- (float)autoExposureBias;
- (void)setAutoExposureBias:(float)bias;
@end

@interface AVCaptureDevice (CharonReleaseLock8)
- (BOOL)isLockedForConfiguration;
@end

@implementation AVCaptureDevice (CharonExposureTargetBias8)

- (void)setExposureTargetBias:(float)bias completionHandler:(void (^)(CMTime syncTime))handler
{
    if (![self isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"You must call lockForConfiguration: before calling setExposureTargetBias:completionHandler:"
                                     userInfo:nil];
    [self setAutoExposureBias:bias];
    if (handler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(CMClockGetTime(CMClockGetHostTimeClock()));
        });
    }
}

@end

@implementation AVCaptureVideoPreviewLayer (CharonSessionWithNoConnection8)

- (void)setSessionWithNoConnection:(AVCaptureSession *)session
{
    self.session = session;
}

@end
